import Foundation
import LiveSplitCore

public enum RunFileError: LocalizedError, Equatable {
    case unreadable(String)
    case unsupportedFormat
    case noSegments
    case notAFile(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let reason): "The file couldn't be read: \(reason)"
        case .unsupportedFormat: "This file isn't a splits file Splitter understands."
        case .noSegments: "The splits file has no segments."
        case .notAFile(let url): "\(url) isn't a file."
        }
    }
}

/// Loads runs from every format Splitter on macOS opens:
/// - Splitter `.split` bundles (Splitter 4+: `splits.lss` inside; older: `runInfo.json`)
/// - LiveSplit `.lss`
/// - Splits.io `.json`
/// - GreenSplit `.gss`
/// plus anything else livesplit-core can parse (WSplit, Llanfair, Time Split Tracker, …).
public enum RunFile {
    public static let splitBundleLSS = "splits.lss"
    public static let splitBundleLegacyInfo = "runInfo.json"

    /// Parses a file or `.split` directory at `url`.
    /// Whether a URL the app was opened with is a splits file to import. Apps are also launched
    /// through custom-scheme URLs, e.g. AltStore's "Open" button uses `altstore-<bundle id>://`;
    /// those aren't files and must be ignored.
    public static func isImportable(_ url: URL) -> Bool {
        url.isFileURL
    }

    public static func load(from url: URL) throws -> Run {
        guard url.isFileURL else { throw RunFileError.notAFile(url.absoluteString) }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return try loadSplitBundle(url)
        }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw RunFileError.unreadable(error.localizedDescription) }
        return try parse(data, loadFilesPath: url.deletingLastPathComponent().path)
    }

    /// Parses raw splits data with livesplit-core's format-sniffing parser.
    public static func parse(_ data: Data, loadFilesPath: String = "") throws -> Run {
        if GreenSplit.looksLikeGreenSplit(data) { return try GreenSplit.run(from: data) }
        var bytes = data
        let result = bytes.withUnsafeMutableBytes { buf in
            Run.parse(buf.baseAddress, buf.count, loadFilesPath)
        }
        guard result.parsedSuccessfully() else {
            if SplitsIO.looksLikeExchange(data) { return try SplitsIO.run(from: data) }
            throw RunFileError.unsupportedFormat
        }
        let run = result.unwrap()
        guard run.len() > 0 else { throw RunFileError.noSegments }
        return run
    }

    static func loadSplitBundle(_ dir: URL) throws -> Run {
        let lss = dir.appendingPathComponent(splitBundleLSS)
        if let data = try? Data(contentsOf: lss) {
            return try parse(data, loadFilesPath: dir.path)
        }
        let info = dir.appendingPathComponent(splitBundleLegacyInfo)
        if let data = try? Data(contentsOf: info) {
            let run = try legacyRun(fromRunInfo: data)
            if let icon = try? Data(contentsOf: dir.appendingPathComponent("gameIcon.png")) {
                return try withEditor(run) { editor in
                    var icon = icon
                    icon.withUnsafeMutableBytes { editor.setGameIcon($0.baseAddress, $0.count) }
                }
            }
            return run
        }
        throw RunFileError.unsupportedFormat
    }

    // MARK: Legacy (pre-4.0) Splitter `runInfo.json`

    struct LegacyRunInfo: Decodable {
        struct Segment: Decodable {
            var name: String?
            var personalBestTime: String?
        }
        var title: String?
        var category: String?
        var attempts: Int?
        var platform: String?
        var gameRegion: String?
        var segments: [Segment]?
    }

    /// Converts the JSON format Splitter used before 4.0 into a livesplit-core run.
    /// Each segment's `personalBestTime` is a cumulative split time (`HH:MM:SS.ss`).
    public static func legacyRun(fromRunInfo data: Data) throws -> Run {
        let info: LegacyRunInfo
        do { info = try JSONDecoder().decode(LegacyRunInfo.self, from: data) } catch {
            throw RunFileError.unsupportedFormat
        }
        let segments = info.segments ?? []
        guard !segments.isEmpty else { throw RunFileError.noSegments }

        let run = Run()
        for (i, segment) in segments.enumerated() {
            run.pushSegment(Segment(segment.name ?? "Split \(i + 1)"))
        }
        return try withEditor(run) { editor in
            editor.setGameName(info.title ?? "")
            editor.setCategoryName(info.category ?? "")
            if let attempts = info.attempts { _ = editor.parseAndSetAttemptCount(String(attempts)) }
            if let platform = info.platform { editor.setPlatformName(platform) }
            if let region = info.gameRegion { editor.setRegionName(region) }
            for (i, segment) in segments.enumerated() {
                editor.selectOnly(i)
                // "00:00:00.00" means "no time" in old Splitter files.
                if let time = segment.personalBestTime, !isZero(time) {
                    _ = editor.activeParseAndSetSplitTime(time, LSLang.english)
                }
            }
        }
    }

    static func isZero(_ time: String) -> Bool {
        time.allSatisfy { "0:.".contains($0) }
    }

    /// Runs `body` with a `RunEditor` over `run` and returns the edited run.
    /// `run` is consumed either way (livesplit-core takes ownership), so it must have segments.
    public static func withEditor(_ run: Run, _ body: (RunEditor) -> Void) throws -> Run {
        guard let editor = RunEditor(run) else { throw RunFileError.noSegments }
        body(editor)
        return editor.close()
    }
}

public enum LSLang {
    /// livesplit-core `Lang` value for English (the first variant of the Rust enum).
    public static let english: UInt8 = 0
}
