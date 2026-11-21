#if canImport(SwiftUI)
import SwiftUI
import UIKit
import SplitterCore

/// Searches speedrun.com for the game and uses its cover art as the game icon.
struct SpeedrunIconPicker: View {
    var initialQuery: String
    var onPick: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var results: [SpeedrunComGame] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var downloading: SpeedrunComGame?
    @State private var failed: (game: SpeedrunComGame, message: String)?

    var body: some View {
        List {
            if searching {
                HStack {
                    ProgressView()
                    Text("Searching speedrun.com…").foregroundStyle(.secondary)
                }
            } else if let searchError {
                ContentUnavailableView {
                    Label("Couldn't Search", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(searchError)
                } actions: {
                    Button("Try Again") { Task { await search() } }
                }
            } else if results.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(results) { game in
                Button { Task { await pick(game) } } label: {
                    GameRow(game: game, isDownloading: downloading == game)
                }
                .tint(.primary)
                .disabled(downloading != nil || game.coverURL == nil)
            }
        }
        .navigationTitle("speedrun.com")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Game name")
        .onSubmit(of: .search) { Task { await search() } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .task {
            guard query.isEmpty else { return }
            query = initialQuery
            if !query.trimmingCharacters(in: .whitespaces).isEmpty { await search() }
        }
        .alert("Couldn't Get Artwork",
               isPresented: .init(get: { failed != nil }, set: { if !$0 { failed = nil } }),
               presenting: failed) { failure in
            Button("Try Again") { Task { await pick(failure.game) } }
            if let web = failure.game.webURL {
                Button("Open on speedrun.com") { openURL(web) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }

    private func search() async {
        let name = query.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        searching = true
        searchError = nil
        defer { searching = false }
        do {
            results = try await SpeedrunCom.searchGames(named: name)
        } catch {
            results = []
            searchError = error.localizedDescription
        }
    }

    private func pick(_ game: SpeedrunComGame) async {
        downloading = game
        defer { downloading = nil }
        do {
            let data = try await SpeedrunCom.downloadCover(for: game)
            guard let icon = GameIconImage.prepare(data) else { throw SpeedrunComError.notAnImage }
            onPick(icon)
            dismiss()
        } catch {
            failed = (game, error.localizedDescription)
        }
    }
}

private struct GameRow: View {
    var game: SpeedrunComGame
    var isDownloading: Bool
    @ScaledMetric(relativeTo: .headline) private var thumbHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: 12) {
            // The thumbnail can be refused by speedrun.com's bot protection too; then it's a placeholder.
            AsyncImage(url: game.coverURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: thumbHeight * 0.75, height: thumbHeight)
            .clipShape(.rect(cornerRadius: 6))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name).font(.headline)
                if let year = game.released {
                    Text(String(year)).font(.subheadline).foregroundStyle(.secondary)
                }
                if game.coverURL == nil {
                    Text("No artwork").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isDownloading { ProgressView() }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint(game.coverURL == nil ? "" : "Uses this game's artwork as the icon")
    }
}
#endif
