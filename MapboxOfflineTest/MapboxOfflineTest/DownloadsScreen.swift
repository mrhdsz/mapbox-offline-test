import SwiftUI
import UIKit

struct DownloadsScreen: View {
    @Environment(OfflineRepository.self) private var repository

    var body: some View {
        NavigationStack {
            Group {
                if repository.regions.isEmpty {
                    ContentUnavailableView(
                        "No offline regions",
                        systemImage: "map",
                        description: Text("Download a square region to store its tile packs on this device.")
                    )
                } else {
                    List(repository.regions) { region in
                        HStack(spacing: 12) {
                            RegionThumbnail(url: region.thumbnailURL)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(region.name)
                                    .font(.headline)
                                Text("\(ByteText.string(for: region.byteSize)) · \(AreaText.string(for: region.areaSquareKilometers))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let minZoom = region.minZoom, let maxZoom = region.maxZoom {
                                    Text("Zoom \(minZoom)–\(maxZoom)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Offline Downloads")
            .refreshable { repository.refresh() }
            .safeAreaInset(edge: .bottom) {
                NavigationLink {
                    RegionPickerScreen()
                } label: {
                    Text("Download region")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
            .onAppear { repository.refresh() }
        }
    }
}

struct RegionThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, FileManager.default.fileExists(atPath: url.path), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
