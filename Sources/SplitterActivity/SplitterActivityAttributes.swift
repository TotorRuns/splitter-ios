import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// What the Live Activity shows. Shared by the app (which starts and updates it) and the widget
/// extension (which draws it), so it must not depend on livesplit-core.
public struct SplitterActivityAttributes: Sendable {
    public enum Phase: String, Codable, Hashable, Sendable { case running, paused, ended }

    public struct ContentState: Codable, Hashable, Sendable {
        public var splitName: String
        /// 1-based number of the current split.
        public var splitNumber: Int
        public var splitCount: Int
        public var phase: Phase
        /// When the attempt would have started had it never paused (now minus elapsed time), so the
        /// system can count up from it while the app isn't running.
        public var timerStart: Date
        /// Elapsed seconds, shown as a fixed time while paused or finished.
        public var elapsed: Double

        public init(splitName: String, splitNumber: Int, splitCount: Int, phase: Phase, timerStart: Date, elapsed: Double) {
            self.splitName = splitName
            self.splitNumber = splitNumber
            self.splitCount = splitCount
            self.phase = phase
            self.timerStart = timerStart
            self.elapsed = elapsed
        }

        /// e.g. "Split 3 of 6".
        public var progress: String { "Split \(min(splitNumber, splitCount)) of \(splitCount)" }

        /// "1:09:53.4", "11:44.0" or "42.3".
        public var frozenTimeText: String {
            let total = max(0, elapsed)
            let whole = Int(total)
            let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
            let tenths = Int((total - Double(whole)) * 10)
            if h > 0 { return String(format: "%d:%02d:%02d.%d", h, m, s, tenths) }
            if m > 0 { return String(format: "%d:%02d.%d", m, s, tenths) }
            return String(format: "%d.%d", s, tenths)
        }
    }

    public var game: String
    public var category: String

    public init(game: String, category: String) {
        self.game = game
        self.category = category
    }
}

#if canImport(ActivityKit) && os(iOS)
extension SplitterActivityAttributes: ActivityAttributes {}
#endif
