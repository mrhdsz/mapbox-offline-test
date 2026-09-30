import Foundation
import MapboxMaps

/// Style pack URLs and tile source URLs used by offline downloads.
///
/// Style packs are downloaded with `OfflineManager.loadStylePack` for every
/// entry in `styleURIs`. Tile regions do not follow a style's sources. They
/// use only `tilesetURLs`.
enum OfflineConfig {
    struct Style {
        var name: String
        var uri: String
    }

    /// Style JSON, sprites, and fonts. One style pack is downloaded per URL.
    static let styles: [Style] = [
        Style(name: "Standard Day", uri: "mapbox://styles/polaris-riderx/cm7d8wx7h006d01ric5epaipl"),
        Style(name: "Satellite", uri: "mapbox://styles/polaris-riderx/cmhnyet9100cj01qf70uo7sn4"),
        Style(name: "Standard Night", uri: "mapbox://styles/polaris-riderx/cmhnyemy5004x01s5c0xu9jut"),
    ]

    static var styleURIs: [String] {
        styles.map(\.uri)
    }

    /// One `mapbox://` TileJSON URI per tileset. These are the only tile sources downloaded.
    /// A tileset id from Studio (`username.tileset`) becomes `mapbox://username.tileset`.
    static let tilesetURLs: [String] = [
        "mapbox://polaris-riderx.polaris-locations-dev",
        "mapbox://polaris-riderx.Dev-Sources-points-lines",
        "mapbox://polaris-riderx.Dev-Sources-polygons",
        "mapbox://polaris-riderx.Ride_Command_Trails_Enriched",
        "mapbox://polaris-riderx.Pois-foursquare",
        //"mapbox://polaris-riderx.rideConditions_dev",
        //"mapbox://polaris-riderx.5xv0az7r",
    ]

    static var primaryStyleURI: StyleURI {
        StyleURI(rawValue: styleURIs[0])!
    }

    static func styleURI(for raw: String) -> StyleURI? {
        StyleURI(rawValue: raw)
    }

    static func displayName(for styleURI: String) -> String {
        styles.first { $0.uri == styleURI }?.name ?? styleURI
    }
}
