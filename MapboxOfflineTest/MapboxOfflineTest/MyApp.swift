import MapboxMaps
import SwiftUI

@main struct MyApp: App {
    @State private var repository: OfflineRepository

    init() {
        MapboxMapsOptions.tileStoreUsageMode = .readOnly
        MapboxMapsOptions.tileStore = TileStore.default
        _repository = State(initialValue: OfflineRepository())
	  MapboxMapsOptions.tileStore?.setOptionForKey(
		"tile-region-max-tile-count",
		domain: TileDataDomain.maps,
		value: NSNumber(value: 4000)
	  )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
    }
}
