import Foundation
import LiveSplitCore

/// Importer for the Splits.io Exchange Format (`.json`), which Splitter for Mac reads and writes.
/// livesplit-core no longer ships a parser for it, so it's decoded here.
/// Schema: https://github.com/glacials/splits-io/tree/master/public/schema
enum SplitsIO {
    struct Exchange: Decodable {
        struct Named: Decodable { var longname: String?; var shortname: String? }
        struct Times: Decodable { var realtimeMS: Double?; var gametimeMS: Double? }
        struct Attempts: Decodable { var total: Int? }
        struct Segment: Decodable {
            var name: String?
            var endedAt: Times?
            var bestDuration: Times?
        }
        var _schemaVersion: String?
        var game: Named?
        var category: Named?
        var attempts: Attempts?
        var segments: [Segment]?
    }

    static func looksLikeExchange(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(4096), encoding: .utf8) else { return false }
        return head.contains("\"_schemaVersion\"")
    }

    static func run(from data: Data) throws -> Run {
        let exchange: Exchange
        do { exchange = try JSONDecoder().decode(Exchange.self, from: data) } catch {
            throw RunFileError.unsupportedFormat
        }
        let segments = exchange.segments ?? []
        guard !segments.isEmpty else { throw RunFileError.noSegments }

        let run = Run()
        for (i, segment) in segments.enumerated() {
            run.pushSegment(Segment(segment.name ?? "Split \(i + 1)"))
        }
        return try RunFile.withEditor(run) { editor in
            editor.setGameName(exchange.game?.longname ?? exchange.game?.shortname ?? "")
            editor.setCategoryName(exchange.category?.longname ?? exchange.category?.shortname ?? "")
            if let total = exchange.attempts?.total {
                _ = editor.parseAndSetAttemptCount(String(total))
            }
            for method in [TimingMethod.realTime, .gameTime] {
                editor.selectTimingMethod(method.rawValue)
                for (i, segment) in segments.enumerated() {
                    editor.selectOnly(i)
                    if let ms = value(segment.endedAt, method) {
                        _ = editor.activeParseAndSetSplitTime(seconds(ms), LSLang.english)
                    }
                    if let ms = value(segment.bestDuration, method) {
                        _ = editor.activeParseAndSetBestSegmentTime(seconds(ms), LSLang.english)
                    }
                }
            }
            editor.selectTimingMethod(TimingMethod.realTime.rawValue)
        }
    }

    /// Splits.io uses 0 for "no time".
    static func value(_ times: Exchange.Times?, _ method: TimingMethod) -> Double? {
        let ms = method == .realTime ? times?.realtimeMS : times?.gametimeMS
        guard let ms, ms > 0 else { return nil }
        return ms
    }

    /// Formats milliseconds as `H:MM:SS.mmm`, which livesplit-core's time parser accepts.
    static func seconds(_ ms: Double) -> String {
        let total = Int((ms).rounded())
        let h = total / 3_600_000
        let m = (total / 60_000) % 60
        let s = (total / 1000) % 60
        let frac = total % 1000
        return String(format: "%d:%02d:%02d.%03d", h, m, s, frac)
    }
}
