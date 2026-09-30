import Foundation
import MapboxMaps

/// Style pack URLs and tile source URLs used by offline downloads.
///
/// Style packs are downloaded with `OfflineManager.loadStylePack` for every
/// entry in `styleURIs`. Tile regions do not follow a style's sources. They
/// use only `tilesetURLs`.
enum OfflineConfig {
    /// Style JSON, sprites, and fonts. One style pack is downloaded per URL.
    static let styleURIs: [String] = [
        "mapbox://styles/polaris-riderx/cm7d8wx7h006d01ric5epaipl", // Standard day
        "mapbox://styles/polaris-riderx/cmhnyet9100cj01qf70uo7sn4", // Satellite
		"mapbox://styles/polaris-riderx/cmhnyemy5004x01s5c0xu9jut" // Standard night
    ]

    /// Mapbox TileJSON sources. These are the only tilesets placed on the
    /// tileset descriptor, so tile packs are not derived from a style.
    static let tilesetURLs: [String] = [
        "mapbox://mapbox.mapbox-streets-v8",
        "mapbox://mapbox.mapbox-terrain-v2",
    ]

    static var primaryStyleURI: StyleURI {
        StyleURI(rawValue: styleURIs[0])!
    }

    static func styleURI(for raw: String) -> StyleURI? {
        StyleURI(rawValue: raw)
    }

    static func displayName(for styleURI: String) -> String {
        styleURI.split(separator: "/").last.map(String.init) ?? styleURI
    }
}
