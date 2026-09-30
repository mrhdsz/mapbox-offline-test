import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                MapScreen()
            }
            Tab("Offline Downloads", systemImage: "arrow.down.circle") {
                DownloadsScreen()
            }
            Tab("Tools", systemImage: "wrench.and.screwdriver") {
                ToolsScreen()
            }
        }
    }
}
