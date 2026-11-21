import Foundation
import Observation
import LiveSplitCore

public enum TimerPhase: UInt8, Sendable {
    case notRunning = 0, running = 1, ended = 2, paused = 3
}

public enum TimingMethod: UInt8, Sendable {
    case realTime = 0, gameTime = 1

    public var label: String { self == .realTime ? "Real Time" : "Game Time" }
}

/// One open splits file: a livesplit-core `Timer` plus the default LiveSplit layout,
/// re-rendered into a `LayoutState` whenever the UI asks.
@MainActor
@Observable
public final class TimerSession {
    public private(set) var state: LayoutState?
    public private(set) var phase: TimerPhase = .notRunning
    public private(set) var comparison: String = ""
    public private(set) var timingMethod: TimingMethod = .realTime
    public private(set) var hasUnsavedChanges = false
    public private(set) var lastError: String?

    /// Where the run is autosaved as `.lss`; `nil` for an unsaved run.
    public var fileURL: URL?

    @ObservationIgnored private let timer: LiveSplitCore.Timer
    @ObservationIgnored private let layout: Layout
    @ObservationIgnored private let imageCache = ImageCache()
    @ObservationIgnored private var iconCache: [String: Data] = [:]

    public init(run: Run, fileURL: URL? = nil, layout: Layout? = nil) throws {
        guard let timer = LiveSplitCore.Timer(run) else { throw RunFileError.noSegments }
        self.timer = timer
        self.layout = layout ?? Layout.defaultLayout(LSLang.english)
        self.fileURL = fileURL
        refresh()
    }

    public convenience init(contentsOf url: URL) throws {
        try self.init(run: RunFile.load(from: url), fileURL: url)
    }

    // MARK: Run info

    public var gameName: String { timer.getRun().gameName() }
    public var categoryName: String { timer.getRun().categoryName() }
    public var segmentCount: Int { timer.getRun().len() }
    public var currentSplitIndex: Int { timer.currentSplitIndex() }

    // MARK: Rendering

    /// Recomputes the layout state. Call this every frame while the timer runs.
    public func refresh() {
        let json = layout.stateAsJson(imageCache, timer, LSLang.english)
        do {
            state = try LayoutState.decode(json)
        } catch {
            lastError = "Layout decode failed: \(error)"
        }
        phase = TimerPhase(rawValue: timer.currentPhase()) ?? .notRunning
        comparison = timer.currentComparison()
        timingMethod = TimingMethod(rawValue: timer.currentTimingMethod()) ?? .realTime
    }

    /// Image bytes (PNG/JPEG/…) for an icon id from the layout state, or nil for "no icon".
    public func iconData(_ id: String) -> Data? {
        if id.isEmpty || id == Self.emptyImageID { return nil }
        if let cached = iconCache[id] { return cached }
        guard let ptr = imageCache.lookupDataPtr(id) else { return nil }
        let len = imageCache.lookupDataLen(id)
        guard len > 0 else { return nil }
        let data = Data(bytes: ptr, count: len)
        iconCache[id] = data
        return data
    }

    /// SHA-256 of zero bytes: livesplit-core's id for "no image".
    public static let emptyImageID = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    // MARK: Timer control (mirrors the buttons on Splitter for Mac)

    /// Starts the timer, or splits if it's already running. Resumes if paused.
    public func splitOrStart() {
        switch phase {
        case .paused: _ = timer.resume()
        case .ended: break
        default: _ = timer.splitOrStart()
        }
        changed()
    }

    public func undoSplit() { _ = timer.undoSplit(); changed() }
    public func skipSplit() { _ = timer.skipSplit(); changed() }

    public func togglePause() {
        switch phase {
        case .running: _ = timer.pause()
        case .paused: _ = timer.resume()
        default: break
        }
        changed()
    }

    /// Whether resetting now would add anything worth keeping (an attempt with at least one split).
    public var resetWouldUpdateSplits: Bool {
        phase != .notRunning && (phase == .ended || currentSplitIndex > 0)
    }

    /// Ends the attempt. `saveTimes` stores it in the run history (and golds/PB);
    /// otherwise it's discarded. Autosaves the file afterwards.
    public func reset(saveTimes: Bool) {
        _ = timer.reset(saveTimes)
        changed()
        if saveTimes { try? save() }
    }

    public func nextComparison() { timer.switchToNextComparison(); changed(dirty: false) }
    public func previousComparison() { timer.switchToPreviousComparison(); changed(dirty: false) }
    public func toggleTimingMethod() { timer.toggleTimingMethod(); changed(dirty: false) }

    public func scrollSplits(up: Bool) {
        if up { layout.scrollUp() } else { layout.scrollDown() }
        refresh()
    }

    private func changed(dirty: Bool = true) {
        if dirty { hasUnsavedChanges = true }
        refresh()
    }

    // MARK: Saving

    /// The run as LiveSplit XML, including the current attempt history.
    public func lssText() -> String { timer.saveAsLss() }

    public func save() throws {
        guard let url = fileURL else { return }
        try lssText().write(to: url, atomically: true, encoding: .utf8)
        timer.markAsUnmodified()
        hasUnsavedChanges = false
    }

    // MARK: Editing

    /// A run editor over a copy of the current run. Only valid while no attempt is in progress.
    public func makeEditor() -> RunEditorSession? {
        guard phase == .notRunning else { return nil }
        return RunEditorSession(run: timer.getRun().clone())
    }

    /// Replaces the run with an edited one and saves it.
    public func apply(_ editor: RunEditorSession) throws {
        guard phase == .notRunning else { return }
        let run = editor.finish()
        if let rejected = timer.setRun(run) {
            rejected.dispose()
            throw RunFileError.noSegments
        }
        iconCache.removeAll()
        changed()
        try save()
    }
}
