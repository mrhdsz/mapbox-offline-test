import SwiftUI

struct DownloadProgressScreen: View {
    @Environment(OfflineRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    let regionID: String

    private var stylesFinished: Bool {
        OfflineConfig.styleURIs.allSatisfy { repository.styleProgress[$0]?.isFinished == true }
    }

    private var isSettled: Bool {
        stylesFinished && repository.tileProgress.isFinished
    }

    var body: some View {
        List {
            Section("Style packs") {
                if OfflineConfig.styleURIs.isEmpty {
                    Text("No style URLs are configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(OfflineConfig.styleURIs, id: \.self) { uri in
                        progressRow(
                            title: OfflineConfig.displayName(for: uri),
                            progress: repository.styleProgress[uri] ?? ResourceProgress()
                        )
                    }
                }
            }

            Section {
                progressRow(title: "Tile packs", progress: repository.tileProgress)
            } header: {
                Text("Tile packs")
            } footer: {
                Text("Tile packs come from the source URLs in OfflineConfig, not from every source in a style. This bar is the tile region that contains those packs.")
            }
        }
        .navigationTitle("Download")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSettled {
                    Button("Done") { dismiss() }
                } else {
                    Button("Cancel", role: .destructive) {
                        repository.cancelActiveDownload()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func progressRow(title: String, progress: ResourceProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(progress.isFinished && progress.errorMessage == nil ? "Done" : ByteText.string(for: progress.completedBytes))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            ProgressView(value: progress.fraction)
            if let errorMessage = progress.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if progress.requiredCount > 0 {
                Text("\(progress.completedCount) of \(progress.requiredCount) resources")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
