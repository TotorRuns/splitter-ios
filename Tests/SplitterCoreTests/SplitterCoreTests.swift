import XCTest
@testable import SplitterCore

@MainActor
final class SplitterCoreTests: XCTestCase {
    var scratch: URL!

    override func setUp() async throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// A fresh copy of a fixture, so tests that autosave never touch the originals.
    func fixture(_ name: String) -> URL {
        let src = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent(name)
        let dst = scratch.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: dst.path) {
            try! FileManager.default.copyItem(at: src, to: dst)
        }
        return dst
    }

    func testParsesLSS() throws {
        let session = try TimerSession(contentsOf: fixture("sample.lss"))
        XCTAssertEqual(session.gameName, "NES Open Tournament Golf")
        XCTAssertEqual(session.categoryName, "US Course")
        XCTAssertEqual(session.segmentCount, 18)
        XCTAssertEqual(session.phase, .notRunning)
    }

    func testParsesSplitsIOJSON() throws {
        let session = try TimerSession(contentsOf: fixture("example-splitsio.json"))
        XCTAssertEqual(session.gameName, "Example Quest")
        XCTAssertEqual(session.categoryName, "Any%")
        XCTAssertEqual(session.segmentCount, 5)
    }

    func testParsesLegacySplitBundle() throws {
        let session = try TimerSession(contentsOf: fixture("legacy.split"))
        XCTAssertEqual(session.gameName, "Example Quest")
        XCTAssertEqual(session.categoryName, "Any %")
        XCTAssertNil(session.lastError)
        XCTAssertEqual(session.segmentCount, 6)
        let splits = try XCTUnwrap(session.state?.components.compactMap { c -> SplitsState? in
            if case .splits(let s) = c { s } else { nil }
        }.first)
        XCTAssertEqual(splits.splits.first?.name, "Intro")
        XCTAssertEqual(splits.splits.filter { !$0.isPlaceholder }.count, 6)
        // PB split times from runInfo.json ("00:00:00.70", "00:00:02.32") become the PB comparison.
        let rows = try XCTUnwrap(session.makeEditor()?.state?.segments)
        XCTAssertEqual(rows[0].splitTime, "0.70")
        XCTAssertEqual(rows[1].splitTime, "2.32")
        XCTAssertEqual(rows[5].splitTime, "")  // "00:00:00.00" means no time
        XCTAssertNotNil(session.state.flatMap { s -> String? in
            if case .title(let t) = s.components.first { t.icon } else { nil }
        }.flatMap(session.iconData))  // gameIcon.png is imported
    }

    func testModernSplitBundleUsesEmbeddedLSS() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".split")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.copyItem(at: fixture("sample.lss"), to: dir.appendingPathComponent("splits.lss"))
        let session = try TimerSession(contentsOf: dir)
        XCTAssertEqual(session.segmentCount, 18)
    }

    func testSplitsIOTimes() throws {
        let json = """
        {"_schemaVersion":"v1.0.1","game":{"longname":"G"},"category":{"longname":"C"},
         "attempts":{"total":7},
         "segments":[
           {"name":"A","endedAt":{"realtimeMS":61500,"gametimeMS":60000},"bestDuration":{"realtimeMS":59000,"gametimeMS":0}},
           {"name":"B","endedAt":{"realtimeMS":3723456,"gametimeMS":0},"bestDuration":{"realtimeMS":0,"gametimeMS":0}}]}
        """
        let run = try RunFile.parse(Data(json.utf8))
        XCTAssertEqual(run.gameName(), "G")
        XCTAssertEqual(run.attemptCount(), 7)
        let editor = try XCTUnwrap(RunEditorSession(run: run))
        let rows = try XCTUnwrap(editor.state?.segments)
        XCTAssertEqual(rows.map(\.name), ["A", "B"])
        XCTAssertEqual(rows[0].splitTime, "1:01.50")
        XCTAssertEqual(rows[0].bestSegmentTime, "59.00")
        XCTAssertEqual(rows[1].splitTime, "1:02:03.45")
        XCTAssertEqual(SplitsIO.seconds(3723456), "1:02:03.456")
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try RunFile.parse(Data("hello".utf8)))
    }

    func testTimerFlowAndLayoutState() throws {
        let session = try TimerSession(contentsOf: fixture("sample.lss"))
        let state = try XCTUnwrap(session.state)
        guard case .title(let title) = state.components.first else { return XCTFail("no title") }
        XCTAssertEqual(title.title, "NES Open Tournament Golf")
        XCTAssertTrue(state.components.contains { if case .timer = $0 { true } else { false } })

        session.splitOrStart()
        XCTAssertEqual(session.phase, .running)
        session.splitOrStart()
        XCTAssertEqual(session.currentSplitIndex, 1)
        session.undoSplit()
        XCTAssertEqual(session.currentSplitIndex, 0)
        session.skipSplit()
        XCTAssertEqual(session.currentSplitIndex, 1)
        session.togglePause()
        XCTAssertEqual(session.phase, .paused)
        session.splitOrStart()  // resumes rather than splitting
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.currentSplitIndex, 1)
        XCTAssertTrue(session.resetWouldUpdateSplits)
        session.reset(saveTimes: false)
        XCTAssertEqual(session.phase, .notRunning)

        let before = session.comparison
        session.nextComparison()
        XCTAssertNotEqual(session.comparison, before)
        session.toggleTimingMethod()
        XCTAssertEqual(session.timingMethod, .gameTime)
    }

    func testLibraryImportRoundTripAndAttemptSaving() throws {
        let dir = scratch.appendingPathComponent("Library")
        let library = RunLibrary(directory: dir)
        let url = try library.importFile(at: fixture("example-splitsio.json"))
        XCTAssertEqual(url.pathExtension, "lss")
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.entries.first?.game, "Example Quest")

        let session = try TimerSession(contentsOf: url)
        let attempts = library.entries[0].attempts
        session.splitOrStart()
        session.splitOrStart()
        session.reset(saveTimes: true)
        XCTAssertFalse(session.hasUnsavedChanges)
        library.reload()
        XCTAssertEqual(library.entries[0].attempts, attempts + 1)

        try library.importFile(at: fixture("example-splitsio.json"))
        XCTAssertEqual(Set(library.entries.map(\.url.lastPathComponent)).count, 2)
    }

    func testRunEditor() throws {
        let session = try TimerSession(contentsOf: fixture("sample.lss"))
        let editor = try XCTUnwrap(session.makeEditor())
        editor.setGameName("Golf")
        editor.renameSegment(0, to: "First")
        editor.insertSegment(below: 0)
        XCTAssertEqual(editor.state?.segments.count, 19)
        editor.removeSegment(1)
        XCTAssertTrue(editor.setSplitTime(0, "25.5"))
        XCTAssertFalse(editor.setSplitTime(0, "not a time"))
        try session.apply(editor)
        XCTAssertEqual(session.gameName, "Golf")
        XCTAssertEqual(session.segmentCount, 18)

        let fresh = try XCTUnwrap(RunEditorSession.newRun())
        XCTAssertEqual(fresh.state?.game, "New Game")
        XCTAssertEqual(fresh.state?.segments.count, 1)
    }

    func testSanitize() {
        XCTAssertEqual(RunLibrary.sanitize("A/B: C?"), "A-B- C-")
        XCTAssertEqual(RunLibrary.sanitize("   "), "Splits")
    }
}
