import Foundation
import LiveSplitCore

/// Importer for GreenSplit splits (`.gss`, JSON with `"format": "greensplit.splits"`).
///
/// GreenSplit's model mirrors LiveSplit's: times in nanoseconds, a "Personal Best" comparison of
/// cumulative split times, best segments, per-segment history keyed by attempt index, and an
/// attempt history. The file is converted to LiveSplit XML and parsed by livesplit-core, so all
/// of that (including history-based comparisons like Average Segments) carries over.
///
/// Subsplits: GreenSplit marks grouped segments with `depth: 1`. As in LiveSplit's subsplits, a
/// group is a run of `depth > 0` segments plus the `depth: 0` segment that closes it; the group
/// takes `sectionName` when set, otherwise the closing segment's name.
///
/// Not imported: alternative branches/routes (only the main route is), hotkeys, layout links.
enum GreenSplit {
    static let formatID = "greensplit.splits"

    // MARK: File model

    struct File: Decodable {
        var format: String?
        var version: Int?
        var run: RunData
    }

    struct Time: Decodable {
        var realTimeNs: String?
        var gameTimeNs: String?

        var real: Int64? { realTimeNs.flatMap(Int64.init) }
        var game: Int64? { gameTimeNs.flatMap(Int64.init) }
        var isEmpty: Bool { real == nil && game == nil }
    }

    struct Attempt: Decodable {
        var index: Int
        var startedAt: String?
        var endedAt: String?
        var startedSynced: Bool?
        var endedSynced: Bool?
        var time: Time?
        var pauseTimeNs: String?
    }

    struct HistoryEntry: Decodable {
        var attempt: Int
        var time: Time?
    }

    struct Segment: Decodable {
        var id: String?
        var name: String?
        var icon: String?
        var depth: Int?
        var sectionName: String?
        var forkedFrom: String?
        var bestSegmentTime: Time?
        var comparisons: [String: Time]?
        var history: [HistoryEntry]?
    }

    struct Metadata: Decodable {
        var platform: String?
        var region: String?
        var usesEmulator: Bool?
        var speedrunComRunId: String?
    }

    struct RunData: Decodable {
        var gameName: String?
        var categoryName: String?
        var gameIcon: String?
        var attemptCount: Int?
        var offsetNs: String?
        var customComparisons: [String]?
        var mainOrder: [String]?
        var metadata: Metadata?
        var attemptHistory: [Attempt]?
        var segments: [Segment]

        enum CodingKeys: String, CodingKey {
            case gameName, categoryName, gameIcon, attemptCount, offsetNs, customComparisons
            case mainOrder, metadata, attemptHistory, segments
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            gameName = try c.decodeIfPresent(String.self, forKey: .gameName)
            categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName)
            gameIcon = try? c.decodeIfPresent(String.self, forKey: .gameIcon)
            attemptCount = try c.decodeIfPresent(Int.self, forKey: .attemptCount)
            offsetNs = try? c.decodeIfPresent(String.self, forKey: .offsetNs)
            customComparisons = try? c.decodeIfPresent([String].self, forKey: .customComparisons)
            // Route ordering is optional and its exact shape may vary; ignore it if unexpected.
            mainOrder = try? c.decodeIfPresent([String].self, forKey: .mainOrder)
            metadata = try? c.decodeIfPresent(Metadata.self, forKey: .metadata)
            attemptHistory = try c.decodeIfPresent([Attempt].self, forKey: .attemptHistory)
            segments = try c.decode([Segment].self, forKey: .segments)
        }
    }

    // MARK: Detection & import

    static func looksLikeGreenSplit(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.contains("\"\(formatID)\"")
    }

    static func run(from data: Data) throws -> Run {
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: data) } catch {
            throw RunFileError.unreadable("not a valid GreenSplit file (\(error.localizedDescription))")
        }
        guard file.format == nil || file.format == formatID else { throw RunFileError.unsupportedFormat }
        var bytes = Data(try liveSplitXML(file.run).utf8)
        let parsed = bytes.withUnsafeMutableBytes { Run.parse($0.baseAddress, $0.count, "") }
        guard parsed.parsedSuccessfully() else { throw RunFileError.unsupportedFormat }
        return parsed.unwrap()
    }

    /// The segments of the main route, in order.
    static func mainRoute(_ run: RunData) -> [Segment] {
        if let order = run.mainOrder, !order.isEmpty {
            let byID = Dictionary(run.segments.compactMap { s in s.id.map { ($0, s) } },
                                  uniquingKeysWith: { first, _ in first })
            let ordered = order.compactMap { byID[$0] }
            if !ordered.isEmpty { return ordered }
        }
        // Segments forked off for another branch aren't part of the main route.
        return run.segments.filter { ($0.forkedFrom ?? "").isEmpty }
    }

    /// Segment groups as (start, endExclusive, name) from GreenSplit's depth/sectionName.
    static func groups(_ segments: [Segment]) -> [(start: Int, end: Int, name: String?)] {
        var result: [(Int, Int, String?)] = []
        var start: Int?
        for (i, segment) in segments.enumerated() {
            let isLast = i == segments.count - 1
            if (segment.depth ?? 0) > 0 && !isLast {
                if start == nil { start = i }
                continue
            }
            if let s = start {
                let section = (segment.sectionName ?? "").trimmingCharacters(in: .whitespaces)
                result.append((s, i + 1, section.isEmpty ? nil : section))
                start = nil
            }
        }
        return result
    }

    // MARK: LiveSplit XML generation

    static func liveSplitXML(_ run: RunData) throws -> String {
        let segments = mainRoute(run)
        guard !segments.isEmpty else { throw RunFileError.noSegments }

        var x = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        x += #"<Run version="1.8.1">"# + "\n"
        x += "  <GameIcon>\(icon(run.gameIcon))</GameIcon>\n"
        x += "  <GameName>\(esc(run.gameName ?? ""))</GameName>\n"
        x += "  <CategoryName>\(esc(run.categoryName ?? ""))</CategoryName>\n"
        let meta = run.metadata
        x += "  <Metadata>\n"
        x += "    <Run id=\"\(esc(meta?.speedrunComRunId ?? ""))\" />\n"
        x += "    <Platform usesEmulator=\"\((meta?.usesEmulator ?? false) ? "True" : "False")\">\(esc(meta?.platform ?? ""))</Platform>\n"
        x += "    <Region>\(esc(meta?.region ?? ""))</Region>\n"
        x += "    <Variables />\n"
        x += "  </Metadata>\n"
        x += "  <Offset>\(timeSpan(run.offsetNs.flatMap(Int64.init) ?? 0))</Offset>\n"
        x += "  <AttemptCount>\(max(run.attemptCount ?? 0, 0))</AttemptCount>\n"

        x += "  <AttemptHistory>\n"
        for attempt in run.attemptHistory ?? [] {
            var attrs = "id=\"\(attempt.index)\""
            if let s = liveSplitDate(attempt.startedAt) {
                attrs += " started=\"\(s)\" isStartedSynced=\"\((attempt.startedSynced ?? false) ? "True" : "False")\""
            }
            if let e = liveSplitDate(attempt.endedAt) {
                attrs += " ended=\"\(e)\" isEndedSynced=\"\((attempt.endedSynced ?? false) ? "True" : "False")\""
            }
            var body = times(attempt.time)
            if let pause = attempt.pauseTimeNs.flatMap(Int64.init), pause > 0 {
                body += "<PauseTime>\(timeSpan(pause))</PauseTime>"
            }
            x += "    <Attempt \(attrs)>\(body)</Attempt>\n"
        }
        x += "  </AttemptHistory>\n"

        x += "  <Segments>\n"
        for segment in segments {
            x += "    <Segment>\n"
            x += "      <Name>\(esc(segment.name ?? ""))</Name>\n"
            x += "      <Icon>\(icon(segment.icon))</Icon>\n"
            x += "      <SplitTimes>\n"
            // Keep the file's comparison order: declared custom comparisons first, then the rest.
            let comparisons = segment.comparisons ?? [:]
            let declared = (run.customComparisons ?? []).filter { comparisons[$0] != nil }
            let names = declared + comparisons.keys.filter { !declared.contains($0) }.sorted()
            for name in names {
                x += "        <SplitTime name=\"\(esc(name))\">\(times(comparisons[name]))</SplitTime>\n"
            }
            x += "      </SplitTimes>\n"
            x += "      <BestSegmentTime>\(times(segment.bestSegmentTime))</BestSegmentTime>\n"
            x += "      <SegmentHistory>\n"
            for entry in segment.history ?? [] {
                x += "        <Time id=\"\(entry.attempt)\">\(times(entry.time))</Time>\n"
            }
            x += "      </SegmentHistory>\n"
            x += "    </Segment>\n"
        }
        x += "  </Segments>\n"

        let groups = groups(segments)
        if !groups.isEmpty {
            x += "  <SegmentGroups>\n"
            for g in groups {
                let name = g.name.map { "<Name>\(esc($0))</Name>" } ?? ""
                x += "    <SegmentGroup start=\"\(g.start)\" end=\"\(g.end)\">\(name)</SegmentGroup>\n"
            }
            x += "  </SegmentGroups>\n"
        }
        x += "  <AutoSplitterSettings />\n"
        x += "</Run>\n"
        return x
    }

    /// Attempt dates as LiveSplit writes them (`MM/dd/yyyy HH:mm:ss`, UTC). GreenSplit keeps
    /// that format for attempts imported from LiveSplit but writes ISO 8601 (`…Z`) for its own.
    static func liveSplitDate(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        if v.range(of: #"^\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return v
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: v) ?? ISO8601DateFormatter().date(from: v) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%02d/%02d/%04d %02d:%02d:%02d",
                      c.month!, c.day!, c.year!, c.hour!, c.minute!, c.second!)
    }

    static func times(_ t: Time?) -> String {
        guard let t, !t.isEmpty else { return "" }
        var s = ""
        if let r = t.real { s += "<RealTime>\(timeSpan(r))</RealTime>" }
        if let g = t.game { s += "<GameTime>\(timeSpan(g))</GameTime>" }
        return s
    }

    /// Nanoseconds as a LiveSplit time span: `[-][D.]HH:MM:SS.fffffff` (100 ns ticks).
    static func timeSpan(_ ns: Int64) -> String {
        let negative = ns < 0
        let ticks = abs(ns) / 100
        let frac = ticks % 10_000_000
        let totalSeconds = ticks / 10_000_000
        let s = totalSeconds % 60, m = (totalSeconds / 60) % 60
        let h = (totalSeconds / 3600) % 24, d = totalSeconds / 86_400
        var out = negative ? "-" : ""
        if d > 0 { out += "\(d)." }
        out += String(format: "%02lld:%02lld:%02lld.%07lld", h, m, s, frac)
        return out
    }

    /// Icons as base64 image data in CDATA. Accepts plain base64 or a `data:` URL; anything
    /// else (e.g. a file path) is dropped rather than failing the import.
    static func icon(_ value: String?) -> String {
        guard var v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return "" }
        if v.hasPrefix("data:"), let comma = v.firstIndex(of: ",") { v = String(v[v.index(after: comma)...]) }
        guard Data(base64Encoded: v) != nil else { return "" }
        return "<![CDATA[\(v)]]>"
    }

    static func esc(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.unicodeScalars {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                // XML 1.0 can't carry most control characters; drop them.
                if ch.value < 0x20 && ch != "\t" && ch != "\n" && ch != "\r" { continue }
                out.unicodeScalars.append(ch)
            }
        }
        return out
    }
}
