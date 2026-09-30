import CoreLocation
import MapboxMaps
import SwiftUI

struct MapScreen: View {
    @State private var styleURI = OfflineConfig.styleURIs[0]

    var body: some View {
        Map(initialViewport: .camera(center: Self.defaultCenter, zoom: 2, bearing: 0, pitch: 0))
            .mapStyle(MapStyle(uri: OfflineConfig.styleURI(for: styleURI) ?? OfflineConfig.primaryStyleURI))
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .top) {
                Picker("Style", selection: $styleURI) {
                    ForEach(OfflineConfig.styleURIs, id: \.self) { uri in
                        Text(OfflineConfig.displayName(for: uri)).tag(uri)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Map")
    }

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
}
