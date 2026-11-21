import Foundation
import Observation
import LiveSplitCore

public struct RunEntry: Identifiable, Hashable, Sendable {
    public var url: URL
    public var game: String
    public var category: String
    public var segmentCount: Int
    public var attempts: UInt32
    public var modified: Date

    public var id: URL { url }
    public var displayTitle: String { game.isEmpty ? url.deletingPathExtension().lastPathComponent : game }
}

/// The app's splits folder. Every run is stored as a LiveSplit `.lss` file, so the
/// folder is readable by LiveSplit, LiveSplit One and Splitter for Mac.
@MainActor
@Observable
public final class RunLibrary {
    public private(set) var entries: [RunEntry] = []
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    /// `<Documents>/Splits` (visible in the Files app when file sharing is on).
    public static func defaultDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Splits", isDirectory: true)
    }

    public func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        entries = urls
            .filter { $0.pathExtension.lowercased() == "lss" }
            .compactMap { url in
                guard let run = try? RunFile.load(from: url) else { return nil }
                defer { run.dispose() }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return RunEntry(url: url, game: run.gameName(), category: run.categoryName(),
                                segmentCount: run.len(), attempts: run.attemptCount(), modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    /// Imports any supported splits file (or `.split` bundle), converting it to `.lss`.
    @discardableResult
    public func importFile(at source: URL) throws -> URL {
        let run = try RunFile.load(from: source)
        return try add(run, suggestedName: source.deletingPathExtension().lastPathComponent)
    }

    /// Saves a run into the library and returns its new file URL.
    @discardableResult
    public func add(_ run: Run, suggestedName: String? = nil) throws -> URL {
        let base = [run.gameName(), run.categoryName()].filter { !$0.isEmpty }.joined(separator: " - ")
        let name = base.isEmpty ? (suggestedName ?? "Splits") : base
        let url = uniqueURL(for: name)
        try run.saveAsLss().write(to: url, atomically: true, encoding: .utf8)
        run.dispose()
        reload()
        return url
    }

    public func delete(_ entry: RunEntry) throws {
        try FileManager.default.removeItem(at: entry.url)
        reload()
    }

    public func duplicate(_ entry: RunEntry) throws {
        let copy = uniqueURL(for: entry.url.deletingPathExtension().lastPathComponent + " copy")
        try FileManager.default.copyItem(at: entry.url, to: copy)
        reload()
    }

    func uniqueURL(for name: String) -> URL {
        let safe = Self.sanitize(name)
        var url = directory.appendingPathComponent(safe).appendingPathExtension("lss")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(safe) \(n)").appendingPathExtension("lss")
            n += 1
        }
        return url
    }

    static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
        let cleaned = name.unicodeScalars.map { bad.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Splits" : String(cleaned.prefix(120))
    }
}
