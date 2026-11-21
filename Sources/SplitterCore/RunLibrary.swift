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
    /// Final split time of the personal best (real time), if the run has one.
    public var personalBest: TimeInterval?
    /// Game icon image data, if the splits have one.
    public var icon: Data?

    public init(url: URL, game: String, category: String, segmentCount: Int, attempts: UInt32,
                modified: Date, personalBest: TimeInterval? = nil, icon: Data? = nil) {
        self.url = url
        self.game = game
        self.category = category
        self.segmentCount = segmentCount
        self.attempts = attempts
        self.modified = modified
        self.personalBest = personalBest
        self.icon = icon
    }

    public var id: URL { url }
    public var displayTitle: String { game.isEmpty ? url.deletingPathExtension().lastPathComponent : game }

    /// e.g. "Any% · 30 splits · 6 attempts".
    public var detailLine: String {
        var parts: [String] = []
        if !category.isEmpty { parts.append(category) }
        parts.append(segmentCount == 1 ? "1 split" : "\(segmentCount) splits")
        parts.append(attempts == 1 ? "1 attempt" : "\(attempts) attempts")
        return parts.joined(separator: " · ")
    }
}

public enum DurationFormat {
    /// "1:09:53", "11:44" or "42.31" (centiseconds only under a minute).
    public static func string(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let whole = Int(total)
        let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return String(format: "%d.%02d", s, Int((total - Double(whole)) * 100))
    }
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
                let count = run.len()
                let pb = count > 0 ? run.segment(count - 1).personalBestSplitTime().realTime()?.totalSeconds() : nil
                var icon: Data?
                if let ptr = run.gameIconPtr(), run.gameIconLen() > 0 { icon = Data(bytes: ptr, count: run.gameIconLen()) }
                return RunEntry(url: url, game: run.gameName(), category: run.categoryName(),
                                segmentCount: count, attempts: run.attemptCount(), modified: modified,
                                personalBest: pb, icon: icon)
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

    /// The splits file with this name in the library, if it still exists. Used to reopen the last
    /// splits on launch; only the name is stored because iOS may move the app's container on update.
    public func url(forFileNamed name: String) -> URL? {
        guard !name.isEmpty, !name.contains("/") else { return nil }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
