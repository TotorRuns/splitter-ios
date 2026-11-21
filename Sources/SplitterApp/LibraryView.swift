#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import SplitterCore

extension UTType {
    /// Splitter for Mac's document bundle.
    static let splitterSplit = UTType(importedAs: "mibe.split", conformingTo: .package)
    /// LiveSplit splits.
    static let liveSplit = UTType(importedAs: "mibe.liveSplit", conformingTo: .xml)
    /// GreenSplit splits (JSON).
    static let greenSplit = UTType(importedAs: "com.totorruns.splitter.greensplit", conformingTo: .json)
}

/// List of saved splits, plus import / new / delete. Equivalent of Splitter's welcome window.
struct LibraryView: View {
    @Environment(RunLibrary.self) private var library

    @State private var path: [TimerRoute] = []
    @State private var importing = false
    @State private var newRunEditor: RunEditorSession?
    @State private var errorMessage: String?
    @State private var pendingDelete: RunEntry?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if library.entries.isEmpty {
                    emptyState
                } else {
                    ForEach(library.entries) { entry in
                        Button { open(entry.url) } label: { EntryRow(entry: entry) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = entry } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { try? library.duplicate(entry) } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(.gray)
                            }
                            .contextMenu {
                                ShareLink(item: entry.url) { Label("Share .lss", systemImage: "square.and.arrow.up") }
                                Button { try? library.duplicate(entry) } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) { pendingDelete = entry } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Splitter")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { importing = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newRunEditor = RunEditorSession.newRun() } label: { Label("New Splits", systemImage: "plus") }
                }
            }
            .refreshable { library.reload() }
            .navigationDestination(for: TimerRoute.self) { route in
                TimerView(session: route.session)
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.splitterSplit, .liveSplit, .greenSplit, .json, .xml, .folder, .data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onOpenURL { url in
            // AltStore launches apps via `altstore-<bundle id>://`; only import actual files.
            guard RunFile.isImportable(url) else { return }
            importFiles([url], openFirst: true)
        }
        .sheet(item: $newRunEditor) { editor in
            NavigationStack {
                RunEditorView(editor: editor, title: "New Splits") {
                    do {
                        let url = try library.add(editor.finish())
                        newRunEditor = nil
                        open(url)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } onCancel: {
                    newRunEditor = nil
                }
            }
        }
        .confirmationDialog("Delete \(pendingDelete?.displayTitle ?? "splits")?",
                            isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDelete { try? library.delete(entry) }
                pendingDelete = nil
            }
        } message: {
            Text("The splits file and its attempt history will be removed from this device.")
        }
        .alert("Couldn't open splits", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Splits Yet", systemImage: "stopwatch")
        } description: {
            Text("Import a .split, .lss, .gss or Splits.io .json file, or create new splits.")
        } actions: {
            Button("Import Splits") { importing = true }.buttonStyle(.borderedProminent)
            Button("New Splits") { newRunEditor = RunEditorSession.newRun() }
        }
        .listRowBackground(Color.clear)
    }

    private func open(_ url: URL) {
        do {
            path.append(TimerRoute(session: try TimerSession(contentsOf: url)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFiles(_ urls: [URL], openFirst: Bool = false) {
        var failures: [String] = []
        var imported: [URL] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                imported.append(try library.importFile(at: url))
            } catch {
                let name = url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
                failures.append("\(name): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
        if (openFirst || urls.count == 1), let first = imported.first { open(first) }
    }
}

/// Navigation value wrapping an open session (compared by identity).
struct TimerRoute: Hashable {
    let session: TimerSession
    static func == (a: TimerRoute, b: TimerRoute) -> Bool { a.session === b.session }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(session)) }
}

private struct EntryRow: View {
    var entry: RunEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 12) {
                if !entry.category.isEmpty { Text(entry.category) }
                Label("\(entry.segmentCount)", systemImage: "list.bullet")
                Label("\(entry.attempts)", systemImage: "arrow.counterclockwise")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
