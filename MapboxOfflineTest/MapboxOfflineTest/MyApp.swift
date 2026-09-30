import MapboxMaps
import SwiftUI

@main struct MyApp: App {
    @State private var repository: OfflineRepository

    init() {
        MapboxMapsOptions.tileStoreUsageMode = .readOnly
        MapboxMapsOptions.tileStore = TileStore.default
        _repository = State(initialValue: OfflineRepository())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
    }
}
