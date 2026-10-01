import Foundation

struct ResourceProgress: Equatable {
    var completedCount: UInt64 = 0
    var requiredCount: UInt64 = 0
    var erroredCount: UInt64 = 0
    var completedBytes: UInt64 = 0
    var loadedBytes: UInt64 = 0
    var isFinished = false
    var errorMessage: String?

    /// Mapbox treats a pack or region as complete only when every required resource is stored.
    var isComplete: Bool {
        isFinished && errorMessage == nil && requiredCount > 0 && completedCount >= requiredCount
    }

    var fraction: Double {
        guard requiredCount > 0 else { return 0 }
        return min(1, Double(completedCount) / Double(requiredCount))
    }
}

struct RegionEstimate: Equatable {
    var transferBytes: UInt64
    var storageBytes: UInt64
    var errorMargin: Double
    var sampledCount: UInt64 = 0
    var requiredCount: UInt64 = 0
}

struct DownloadedRegion: Identifiable, Equatable {
    var id: String
    var name: String
    var byteSize: UInt64
    var areaSquareKilometers: Double?
    var minZoom: Int?
    var maxZoom: Int?
    var tilesetURLs: [String]
    var thumbnailURL: URL?
    var createdAt: String?
}

struct StoredStylePack: Identifiable, Equatable {
    var styleURI: String
    var byteSize: UInt64

    var id: String { styleURI }
}

enum ByteText {
    static func string(for bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .file)
    }
}

enum AreaText {
    static func string(for squareKilometers: Double?) -> String {
        guard let squareKilometers else { return "Area unavailable" }
        if squareKilometers >= 100 {
            return String(format: "%.0f km²", squareKilometers)
        }
        if squareKilometers >= 10 {
            return String(format: "%.1f km²", squareKilometers)
        }
        return String(format: "%.2f km²", squareKilometers)
    }
}
