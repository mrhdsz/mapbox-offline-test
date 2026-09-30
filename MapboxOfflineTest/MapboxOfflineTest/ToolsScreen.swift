import SwiftUI

struct ToolsScreen: View {
    @Environment(OfflineRepository.self) private var repository
    @State private var confirmClear = false
    @State private var confirmViewCache = false

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
                    LabeledContent("View cache") {
                        Text(ByteText.string(for: repository.viewCacheBytes))
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear map cache") {
                        repository.refreshViewCacheSize()
                        confirmViewCache = true
                    }
                    .disabled(repository.isClearingViewCache)

                    if repository.isClearingViewCache {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Clearing tiles saved while viewing the map…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let viewCacheMessage = repository.viewCacheMessage {
                        Text(viewCacheMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Removes the disk cache filled by panning and zooming. The size is the map cache on disk, not downloaded style packs or tile regions.")
                }

                Section {
                    NavigationLink("Offline data summary") {
                        OfflineSummaryScreen()
                    }
                }
            }
            .navigationTitle("Tools")
            .onAppear { repository.refreshViewCacheSize() }
            .alert("Clear offline data?", isPresented: $confirmClear) {
                Button("Clear", role: .destructive) {
                    repository.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all style packs, tile regions, and saved thumbnails from this device.")
            }
            .alert("Clear map cache?", isPresented: $confirmViewCache) {
                Button("Clear cache", role: .destructive) {
                    repository.clearViewCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes \(ByteText.string(for: repository.viewCacheBytes)) cached by viewing the map. Offline downloads stay on the device.")
            }
        }
    }
}
