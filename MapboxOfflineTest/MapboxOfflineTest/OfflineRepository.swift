import Foundation
import MapboxMaps
import os
import UIKit

@Observable
final class OfflineRepository {
    private let offlineManager = OfflineManager()
    private let tileStore = TileStore.default

    private(set) var regions: [DownloadedRegion] = []
    private(set) var stylePacks: [StoredStylePack] = []
    private(set) var estimate: RegionEstimate?
    private(set) var isEstimating = false
    private(set) var estimateError: String?
    private(set) var styleProgress: [String: ResourceProgress] = [:]
    private(set) var tileProgress = ResourceProgress()
    private(set) var activeDownloadID: String?
    private(set) var isClearing = false
    private(set) var isClearingViewCache = false
    private(set) var viewCacheBytes: UInt64 = 0
    private(set) var viewCacheMessage: String?
    private(set) var mapGeneration = 0
    private(set) var statusMessage: String?

    private var estimateCancelable: (any Cancelable)?
    private var downloadCancelables: [any Cancelable] = []
    private var snapshotter: Snapshotter?
    private var refreshGeneration = 0

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        tileStore.allTileRegions { [weak self] result in
            Task { @MainActor in
                guard let self, generation == self.refreshGeneration else { return }
                switch result {
                case let .success(tileRegions):
                    self.loadRegionDetails(tileRegions, generation: generation)
                case let .failure(error):
                    self.statusMessage = error.localizedDescription
                }
            }
        }
        offlineManager.allStylePacks { [weak self] result in
            Task { @MainActor in
                guard let self, generation == self.refreshGeneration else { return }
                switch result {
                case let .success(packs):
                    self.stylePacks = packs
                        .map { pack in
                            StoredStylePack(
                                styleURI: pack.styleURI,
                                byteSize: pack.completedResourceSize
                            )
                        }
                        .sorted { $0.styleURI < $1.styleURI }
                case let .failure(error):
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func updateEstimate(geometry: Geometry, zoomRange: ClosedRange<UInt8>) {
        estimateCancelable?.cancel()
        estimateError = nil
        isEstimating = true

        guard let loadOptions = makeLoadOptions(geometry: geometry, zoomRange: zoomRange, name: "estimate") else {
            isEstimating = false
            estimateError = "Could not build a tile region estimate."
            return
        }

        estimateCancelable = tileStore.estimateTileRegion(
            forId: "size-estimate",
            loadOptions: loadOptions,
            progress: { _ in },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    self.isEstimating = false
                    switch result {
                    case let .success(value):
                        self.estimate = RegionEstimate(
                            transferBytes: value.transferSize,
                            storageBytes: value.storageSize,
                            errorMargin: value.errorMargin
                        )
                        self.estimateError = nil
                    case let .failure(error):
                        if case TileRegionError.canceled = error { return }
                        self.estimate = nil
                        self.estimateError = error.localizedDescription
                    }
                }
            }
        )
    }

    func startDownload(
        name: String,
        polygon: Polygon,
        zoomRange: ClosedRange<UInt8>,
        mapStyleURI: StyleURI
    ) async -> String {
        cancelActiveDownload()
        let regionID = UUID().uuidString
        activeDownloadID = regionID
        styleProgress = Dictionary(uniqueKeysWithValues: OfflineConfig.styleURIs.map { ($0, ResourceProgress()) })
        tileProgress = ResourceProgress()
        statusMessage = nil

        await captureThumbnail(regionID: regionID, polygon: polygon, styleURI: mapStyleURI)

        let geometry = Geometry.polygon(polygon)
        downloadStylePacks()
        downloadTileRegion(id: regionID, name: name, geometry: geometry, zoomRange: zoomRange)
        return regionID
    }

    func cancelEstimate() {
        estimateCancelable?.cancel()
        estimateCancelable = nil
        isEstimating = false
    }

    func cancelActiveDownload() {
        estimateCancelable?.cancel()
        downloadCancelables.forEach { $0.cancel() }
        downloadCancelables.removeAll()
        snapshotter?.cancel()
        snapshotter = nil
    }

    /// Size of the disk cache filled by panning and zooming. Mapbox does not expose this
    /// as an API, so it is the on-disk size of the map data cache that `clearData` removes.
    func refreshViewCacheSize() {
        viewCacheBytes = Self.byteCount(of: Self.viewCacheDirectory())
    }

    /// Removes tiles stored while panning and zooming. Offline style packs and tile regions stay.
    func clearViewCache() {
        guard !isClearingViewCache else { return }
        refreshViewCacheSize()
        let clearedBytes = viewCacheBytes
        isClearingViewCache = true
        viewCacheMessage = nil
        MapboxMap.clearData { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isClearingViewCache = false
                self.refreshViewCacheSize()
                if let error {
                    self.viewCacheMessage = error.localizedDescription
                } else {
                    self.mapGeneration += 1
                    self.viewCacheMessage = "Cleared \(ByteText.string(for: clearedBytes)). Downloaded regions are unchanged."
                }
            }
        }
    }

    func clearAll() {
        guard !isClearing else { return }
        isClearing = true
        statusMessage = nil
        cancelActiveDownload()
        activeDownloadID = nil
        styleProgress = [:]
        tileProgress = ResourceProgress()

        tileStore.setOptionForKey(TileStoreOptions.diskQuota, value: 0)
        let store = tileStore
        let manager = offlineManager

        let group = DispatchGroup()
        group.enter()
        store.allTileRegions { result in
            let regions = (try? result.get()) ?? []
            if regions.isEmpty {
                group.leave()
                return
            }
            let pending = DispatchGroup()
            for region in regions {
                pending.enter()
                store.removeRegion(forId: region.id) { _ in
                    pending.leave()
                }
            }
            pending.notify(queue: .global()) {
                group.leave()
            }
        }

        group.enter()
        manager.allStylePacks { result in
            let packs = (try? result.get()) ?? []
            if packs.isEmpty {
                group.leave()
                return
            }
            let pending = DispatchGroup()
            for pack in packs {
                pending.enter()
                guard let styleURI = StyleURI(rawValue: pack.styleURI) else {
                    pending.leave()
                    continue
                }
                manager.removeStylePack(for: styleURI) { _ in
                    pending.leave()
                }
            }
            pending.notify(queue: .global()) {
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.tileStore.setOptionForKey(TileStoreOptions.diskQuota, value: NSNull())
            self.deleteThumbnails()
            self.regions = []
            self.stylePacks = []
            self.estimate = nil
            self.isClearing = false
            self.refresh()
        }
    }

    private func downloadStylePacks() {
        let options = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally,
            metadata: ["source": "OfflineConfig"],
            acceptExpired: false
        )
        guard let options else {
            for uri in OfflineConfig.styleURIs {
                styleProgress[uri] = ResourceProgress(isFinished: true, errorMessage: "Invalid style pack options.")
            }
            return
        }

        for rawURI in OfflineConfig.styleURIs {
            guard let styleURI = StyleURI(rawValue: rawURI) else {
                styleProgress[rawURI] = ResourceProgress(isFinished: true, errorMessage: "Invalid style URI.")
                continue
            }
            let cancelable = offlineManager.loadStylePack(for: styleURI, loadOptions: options) { [weak self] progress in
                Task { @MainActor in
                    self?.styleProgress[rawURI] = ResourceProgress(
                        completedCount: progress.completedResourceCount,
                        requiredCount: progress.requiredResourceCount,
                        erroredCount: progress.erroredResourceCount,
                        completedBytes: progress.completedResourceSize
                    )
                }
            } completion: { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case let .success(pack):
                        self.styleProgress[rawURI] = ResourceProgress(
                            completedCount: pack.completedResourceCount,
                            requiredCount: pack.requiredResourceCount,
                            completedBytes: pack.completedResourceSize,
                            isFinished: true,
                            errorMessage: Self.incompleteMessage(
                                completed: pack.completedResourceCount,
                                required: pack.requiredResourceCount
                            )
                        )
                    case let .failure(error):
                        var failed = self.styleProgress[rawURI] ?? ResourceProgress()
                        failed.isFinished = true
                        failed.errorMessage = error.localizedDescription
                        self.styleProgress[rawURI] = failed
                    }
                    self.refreshIfDownloadSettled()
                }
            }
            downloadCancelables.append(cancelable)
        }
    }

    private func downloadTileRegion(id: String, name: String, geometry: Geometry, zoomRange: ClosedRange<UInt8>) {
        guard let loadOptions = makeLoadOptions(geometry: geometry, zoomRange: zoomRange, name: name) else {
            tileProgress = ResourceProgress(isFinished: true, errorMessage: "Could not build tile region options.")
            return
        }

        let cancelable = tileStore.loadTileRegion(forId: id, loadOptions: loadOptions) { [weak self] progress in
            Task { @MainActor in
                self?.tileProgress = ResourceProgress(
                    completedCount: progress.completedResourceCount,
                    requiredCount: progress.requiredResourceCount,
                    erroredCount: progress.erroredResourceCount,
                    completedBytes: progress.completedResourceSize
                )
            }
        } completion: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(region):
                    self.tileProgress = ResourceProgress(
                        completedCount: region.completedResourceCount,
                        requiredCount: region.requiredResourceCount,
                        completedBytes: region.completedResourceSize,
                        isFinished: true,
                        errorMessage: Self.incompleteMessage(
                            completed: region.completedResourceCount,
                            required: region.requiredResourceCount
                        )
                    )
                case let .failure(error):
                    self.tileProgress.isFinished = true
                    self.tileProgress.errorMessage = error.localizedDescription
                }
                self.refreshIfDownloadSettled()
            }
        }
        downloadCancelables.append(cancelable)
    }

    private func refreshIfDownloadSettled() {
        let stylesDone = OfflineConfig.styleURIs.allSatisfy { styleProgress[$0]?.isFinished == true }
        guard stylesDone, tileProgress.isFinished else { return }
        downloadCancelables.removeAll()
        refresh()
    }

    private func makeLoadOptions(geometry: Geometry, zoomRange: ClosedRange<UInt8>, name: String) -> TileRegionLoadOptions? {
        // An empty style URL downloads only `tilesetURLs`. A real style URI would also
        // download every tiled source in that style.
        let descriptor = offlineManager.createTilesetDescriptor(
            for: TilesetDescriptorOptions(
                styleURI: "",
                minZoom: zoomRange.lowerBound,
                maxZoom: zoomRange.upperBound,
                pixelRatio: Float(UIScreen.main.scale),
                tilesets: OfflineConfig.tilesetURLs,
                stylePack: nil,
                extraOptions: nil
            )
        )
        let metadata: [String: Any] = [
            "name": name,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "minZoom": Int(zoomRange.lowerBound),
            "maxZoom": Int(zoomRange.upperBound),
            "tilesets": OfflineConfig.tilesetURLs,
        ]
        return TileRegionLoadOptions(
            geometry: geometry,
            descriptors: [descriptor],
            metadata: metadata,
            acceptExpired: false
        )
    }

    private func loadRegionDetails(_ tileRegions: [TileRegion], generation: Int) {
        if tileRegions.isEmpty {
            regions = []
            return
        }
        let store = tileStore
        let pending = DispatchGroup()
        let loaded = OSAllocatedUnfairLock(initialState: [DownloadedRegion]())

        for region in tileRegions where region.id != "size-estimate" {
            pending.enter()
            let regionID = region.id
            let byteSize = region.completedResourceSize
            store.tileRegionMetadata(forId: regionID) { metadataResult in
                store.tileRegionGeometry(forId: regionID) { geometryResult in
                    let metadata = (try? metadataResult.get()) as? [String: Any]
                    let geometry = try? geometryResult.get()
                    let item = DownloadedRegion(
                        id: regionID,
                        name: metadata?["name"] as? String ?? regionID,
                        byteSize: byteSize,
                        areaSquareKilometers: geometry.flatMap(GeoArea.squareKilometers(of:)),
                        minZoom: Self.intValue(metadata?["minZoom"]),
                        maxZoom: Self.intValue(metadata?["maxZoom"]),
                        tilesetURLs: Self.stringList(metadata?["tilesets"]),
                        thumbnailURL: Self.thumbnailURL(for: regionID),
                        createdAt: metadata?["createdAt"] as? String
                    )
                    loaded.withLock { $0.append(item) }
                    pending.leave()
                }
            }
        }

        pending.notify(queue: .main) { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let regions = loaded.withLock { $0 }
            self.regions = regions.sorted { ($0.createdAt ?? $0.name) > ($1.createdAt ?? $1.name) }
        }
    }

    private func captureThumbnail(regionID: String, polygon: Polygon, styleURI: StyleURI) async {
        let coordinates = polygon.coordinates.first ?? []
        guard coordinates.count >= 4 else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let options = MapSnapshotOptions(size: CGSize(width: 320, height: 320), pixelRatio: 2)
            let snapshotter = Snapshotter(options: options)
            self.snapshotter = snapshotter
            snapshotter.styleURI = styleURI
            let camera = snapshotter.camera(
                for: coordinates,
                padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
                bearing: 0,
                pitch: 0
            )
            snapshotter.setCamera(to: camera)
            snapshotter.start(overlayHandler: nil) { [weak self] result in
                Task { @MainActor in
                    defer {
                        self?.snapshotter = nil
                        continuation.resume()
                    }
                    guard case let .success(image) = result, let data = image.jpegData(compressionQuality: 0.8) else {
                        return
                    }
                    let url = Self.thumbnailURL(for: regionID)
                    try? FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? data.write(to: url)
                }
            }
        }
    }

    private func deleteThumbnails() {
        let directory = thumbnailDirectory()
        try? FileManager.default.removeItem(at: directory)
    }

    nonisolated private static func thumbnailURL(for regionID: String) -> URL {
        thumbnailDirectory().appendingPathComponent("\(regionID).jpg")
    }

    /// The view cache lives in `map_data`, next to but not inside the tile store.
    private static func viewCacheDirectory() -> URL {
        let dataPath = MapboxMapsOptions.dataPath
        if dataPath.lastPathComponent == "map_data" {
            return dataPath
        }
        return dataPath.appendingPathComponent("map_data", isDirectory: true)
    }

    private static func byteCount(of directory: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        var total: UInt64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += UInt64(values.fileSize ?? 0)
        }
        return total
    }

    nonisolated private static func thumbnailDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline-thumbnails", isDirectory: true)
    }

    private func thumbnailDirectory() -> URL {
        Self.thumbnailDirectory()
    }

    private static func incompleteMessage(completed: UInt64, required: UInt64) -> String? {
        guard required > 0, completed < required else { return nil }
        return "Incomplete: \(completed) of \(required) resources stored."
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    nonisolated private static func stringList(_ value: Any?) -> [String] {
        if let values = value as? [String] { return values }
        if let values = value as? [Any] { return values.compactMap { $0 as? String } }
        return []
    }
}
