import CoreLocation
import MapboxMaps
import SwiftUI

struct RegionPickerScreen: View {
    @Environment(OfflineRepository.self) private var repository

    @State private var mapSize: CGSize = .zero
    @State private var polygon: Polygon?
    @State private var minZoom = 11.0
    @State private var maxZoom = 14.0
    @State private var regionName = ""
    @State private var isPreparing = false
    @State private var startedDownloadID: String?
    @State private var estimateTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            map
            controls
        }
        .navigationTitle("Select region")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $startedDownloadID) { regionID in
            DownloadProgressScreen(regionID: regionID)
        }
        .onAppear {
            if regionName.isEmpty {
                regionName = "Region \(repository.regions.count + 1)"
            }
        }
        .onDisappear {
            estimateTask?.cancel()
            repository.cancelEstimate()
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(initialViewport: .camera(center: Self.defaultCenter, zoom: 12, bearing: 0, pitch: 0))
                .mapStyle(MapStyle(uri: OfflineConfig.primaryStyleURI))
                .onMapIdle { _ in
                    updatePolygon(using: proxy)
                }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { mapSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in
                        mapSize = newSize
                    }
            }
        }
        .overlay {
            squareMask
        }
    }

    private var squareMask: some View {
        Canvas { context, size in
            let rect = squareRect(in: size)
            var dimmed = Path(CGRect(origin: .zero, size: size))
            dimmed.addRect(rect)
            context.fill(dimmed, with: .color(.black.opacity(0.35)), style: FillStyle(eoFill: true))
            context.stroke(Path(rect), with: .color(.white), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pan and zoom the map under the square. Mapbox stores tiles in bands 0–5, 6–10, 11–14, and 15–16, so the download can include neighboring zoom levels.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Min zoom \(Int(minZoom.rounded()))") {
                Slider(value: $minZoom, in: 0...16, step: 1) { editing in
                    if !editing { clampZoom(); scheduleEstimate() }
                }
            }
            LabeledContent("Max zoom \(Int(maxZoom.rounded()))") {
                Slider(value: $maxZoom, in: 0...16, step: 1) { editing in
                    if !editing { clampZoom(); scheduleEstimate() }
                }
            }

            estimateLabel

            TextField("Region name", text: $regionName)
                .textFieldStyle(.roundedBorder)

            Button {
                startDownload()
            } label: {
                if isPreparing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Download")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(polygon == nil || regionName.trimmingCharacters(in: .whitespaces).isEmpty || isPreparing)
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private var estimateLabel: some View {
        if repository.isEstimating {
            HStack(spacing: 8) {
                ProgressView()
                Text("Estimating download size…")
                    .font(.subheadline)
            }
        } else if let estimate = repository.estimate {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer \(ByteText.string(for: estimate.transferBytes))")
                Text("Storage \(ByteText.string(for: estimate.storageBytes))")
                Text(String(format: "Estimate margin ±%.0f%%", estimate.errorMargin * 100))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        } else if let estimateError = repository.estimateError {
            Text(estimateError)
                .font(.subheadline)
                .foregroundStyle(.red)
        } else {
            Text("Move the map to estimate the tile download.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func squareRect(in size: CGSize) -> CGRect {
        let side = min(size.width, size.height) * 0.72
        return CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
    }

    private func updatePolygon(using proxy: MapProxy) {
        guard let map = proxy.map, mapSize.width > 0, mapSize.height > 0 else { return }
        let rect = squareRect(in: mapSize)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ].map { map.coordinate(for: $0) }
        var ring = corners
        ring.append(corners[0])
        polygon = Polygon([ring])
        scheduleEstimate()
    }

    private func clampZoom() {
        if minZoom > maxZoom {
            maxZoom = minZoom
        }
    }

    private var zoomRange: ClosedRange<UInt8> {
        let lower = UInt8(min(15, max(0, Int(minZoom.rounded()))))
        let upper = UInt8(min(16, max(Int(lower), Int(maxZoom.rounded()))))
        return lower...upper
    }

    private func scheduleEstimate() {
        estimateTask?.cancel()
        guard let polygon else { return }
        let geometry = Geometry.polygon(polygon)
        let range = zoomRange
        estimateTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            repository.updateEstimate(geometry: geometry, zoomRange: range)
        }
    }

    private func startDownload() {
        guard let polygon else { return }
        let name = regionName.trimmingCharacters(in: .whitespaces)
        let range = zoomRange
        isPreparing = true
        Task {
            let regionID = await repository.startDownload(
                name: name,
                polygon: polygon,
                zoomRange: range,
                mapStyleURI: OfflineConfig.primaryStyleURI
            )
            isPreparing = false
            startedDownloadID = regionID
        }
    }

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
}
