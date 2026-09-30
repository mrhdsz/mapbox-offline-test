import MapboxMaps

/// Geographic size of a downloaded tile region, using Turf's polygon area
/// (square meters) converted to square kilometers.
enum GeoArea {
    nonisolated static func squareKilometers(of geometry: Geometry) -> Double? {
        switch geometry {
        case .polygon(let polygon):
            return polygon.area / 1_000_000
        case .multiPolygon(let multiPolygon):
            let meters = multiPolygon.polygons.reduce(0) { $0 + $1.area }
            return meters / 1_000_000
        default:
            return nil
        }
    }
}
