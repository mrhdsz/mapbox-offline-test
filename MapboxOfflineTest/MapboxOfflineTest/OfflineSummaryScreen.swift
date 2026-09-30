import SwiftUI

struct OfflineSummaryScreen: View {
    @Environment(OfflineRepository.self) private var repository

    var body: some View {
        List {
            Section {
                if repository.stylePacks.isEmpty {
                    Text("No style packs downloaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repository.stylePacks) { pack in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(OfflineConfig.displayName(for: pack.styleURI))
                                .font(.headline)
                            Text(pack.styleURI)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ByteText.string(for: pack.byteSize))
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Style packs")
            } footer: {
                Text("Style packs store style JSON, sprites, and fonts. They are shared by every region.")
            }

            Section {
                if repository.regions.isEmpty {
                    Text("No tile regions downloaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repository.regions) { region in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(region.name)
                                .font(.headline)
                            Text("File size \(ByteText.string(for: region.byteSize))")
                            Text("Geographic size \(AreaText.string(for: region.areaSquareKilometers))")
                            if let minZoom = region.minZoom, let maxZoom = region.maxZoom {
                                Text("Zoom \(minZoom)–\(maxZoom)")
                            }
                            if !region.tilesetURLs.isEmpty {
                                Text(region.tilesetURLs.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Tile regions")
            } footer: {
                Text("Each region is the download that contains the tile packs for the selected source URLs. Mapbox does not list individual tile packs.")
            }
        }
        .navigationTitle("Offline data")
        .refreshable { repository.refresh() }
        .onAppear { repository.refresh() }
    }
}
