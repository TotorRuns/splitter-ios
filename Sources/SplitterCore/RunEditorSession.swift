import Foundation
import Observation
import LiveSplitCore

/// Decodable mirror of livesplit-core's run editor state JSON.
public struct RunEditorState: Decodable, Sendable {
    public struct Row: Decodable, Sendable, Identifiable {
        public var segmentIndex: Int?
        public var name: String?
        public var splitTime: String?
        public var segmentTime: String?
        public var bestSegmentTime: String?
        public var selected: String?
        public var kind: String

        public var id: Int { segmentIndex ?? -1 }
        public var isSegment: Bool { kind == "Segment" && segmentIndex != nil }
        public var isActive: Bool { selected == "Active" }

        enum CodingKeys: String, CodingKey {
            case name, selected, kind
            case segmentIndex = "segment_index"
            case splitTime = "split_time"
            case segmentTime = "segment_time"
            case bestSegmentTime = "best_segment_time"
        }
    }

    public struct Buttons: Decodable, Sendable {
        public var canRemove: Bool
        public var canMoveUp: Bool
        public var canMoveDown: Bool

        enum CodingKeys: String, CodingKey {
            case canRemove = "can_remove"
            case canMoveUp = "can_move_up"
            case canMoveDown = "can_move_down"
        }
    }

    public var game: String
    public var category: String
    public var offset: String
    public var attempts: UInt32
    public var timingMethod: String
    public var rows: [Row]
    public var comparisonNames: [String]
    public var buttons: Buttons

    public var segments: [Row] { rows.filter(\.isSegment) }

    enum CodingKeys: String, CodingKey {
        case game, category, offset, attempts, rows, buttons
        case timingMethod = "timing_method"
        case comparisonNames = "comparison_names"
    }
}

/// Edits a copy of a run: names, segments, times. Mirrors Splitter's "Edit Run" window.
@MainActor
@Observable
public final class RunEditorSession: Identifiable {
    nonisolated public var id: ObjectIdentifier { ObjectIdentifier(self) }

    public private(set) var state: RunEditorState?
    public private(set) var lastError: String?

    @ObservationIgnored private var editor: RunEditor?
    @ObservationIgnored private let imageCache = ImageCache()

    public init?(run: Run) {
        guard let editor = RunEditor(run) else { return nil }
        self.editor = editor
        refresh()
    }

    /// A brand-new run with one segment, ready to be edited.
    public static func newRun() -> RunEditorSession? {
        let run = Run()
        run.pushSegment(Segment("Split 1"))
        let session = RunEditorSession(run: run)
        session?.edit { $0.setGameName("New Game"); $0.setCategoryName("Any%") }
        return session
    }

    private func refresh() {
        guard let editor else { return }
        let json = editor.stateAsJson(imageCache, LSLang.english)
        do {
            state = try JSONDecoder().decode(RunEditorState.self, from: Data(json.utf8))
        } catch {
            lastError = "Editor decode failed: \(error)"
        }
    }

    private func edit(_ body: (RunEditor) -> Void) {
        guard let editor else { return }
        body(editor)
        refresh()
    }

    // MARK: Run metadata

    public func setGameName(_ name: String) { edit { $0.setGameName(name) } }
    public func setCategoryName(_ name: String) { edit { $0.setCategoryName(name) } }

    @discardableResult
    public func setAttemptCount(_ text: String) -> Bool {
        var ok = false
        edit { ok = $0.parseAndSetAttemptCount(text) }
        return ok
    }

    @discardableResult
    public func setOffset(_ text: String) -> Bool {
        var ok = false
        edit { ok = $0.parseAndSetOffset(text, LSLang.english) }
        return ok
    }

    public func setGameIcon(_ data: Data?) {
        edit { editor in
            if var data {
                data.withUnsafeMutableBytes { editor.setGameIcon($0.baseAddress, $0.count) }
            } else {
                editor.removeGameIcon()
            }
        }
    }

    // MARK: Segments

    public func select(_ index: Int) { edit { $0.selectOnly(index) } }

    public func renameSegment(_ index: Int, to name: String) {
        edit { $0.selectOnly(index); $0.activeSetName(name) }
    }

    @discardableResult
    public func setSplitTime(_ index: Int, _ text: String) -> Bool {
        var ok = false
        edit { $0.selectOnly(index); ok = $0.activeParseAndSetSplitTime(text, LSLang.english) }
        return ok
    }

    @discardableResult
    public func setBestSegmentTime(_ index: Int, _ text: String) -> Bool {
        var ok = false
        edit { $0.selectOnly(index); ok = $0.activeParseAndSetBestSegmentTime(text, LSLang.english) }
        return ok
    }

    public func insertSegment(below index: Int) {
        edit { $0.selectOnly(index); $0.insertSegmentBelow() }
    }

    public func removeSegment(_ index: Int) {
        edit { editor in
            editor.selectOnly(index)
            editor.removeSegments()
        }
    }

    public func moveSegment(_ index: Int, up: Bool) {
        edit { $0.selectOnly(index); up ? $0.moveSegmentsUp() : $0.moveSegmentsDown() }
    }

    public func clearHistory() { edit { $0.clearHistory() } }
    public func clearTimes() { edit { $0.clearTimes() } }

    /// Closes the editor and returns the edited run. The session can't be used afterwards.
    public func finish() -> Run {
        let run = editor!.close()
        editor = nil
        return run
    }
}
