import SwiftUI

struct ToolsScreen: View {
    @Environment(OfflineRepository.self) private var repository
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Clear offline data", role: .destructive) {
                        confirmClear = true
                    }
                    .disabled(repository.isClearing)

                    if repository.isClearing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Removing style packs and tile regions…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Deletes every downloaded style pack and tile region, then sets the tile store quota to zero so Mapbox evicts the files. Thumbnails are removed too.")
                }

                Section {
                    NavigationLink("Offline data summary") {
                        OfflineSummaryScreen()
                    }
                }
            }
            .navigationTitle("Tools")
            .alert("Clear offline data?", isPresented: $confirmClear) {
                Button("Clear", role: .destructive) {
                    repository.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all style packs, tile regions, and saved thumbnails from this device.")
            }
        }
    }
}
