import XCTest
import LiveSplitCore
@testable import SplitterCore

@MainActor
final class GreenSplitTests: XCTestCase {
    var url: URL { Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent("example.gss") }

    func testImportsRunMetadataAndSegments() throws {
        let run = try RunFile.load(from: url)
        XCTAssertEqual(run.gameName(), "Example Quest & Friends")      // XML escaping round-trips
        XCTAssertEqual(run.categoryName(), "Any% <Glitchless>")
        XCTAssertEqual(run.attemptCount(), 3)
        XCTAssertEqual(run.attemptHistoryLen(), 3)
        // The branch-only "Secret Shortcut" segment is not on the main route.
        XCTAssertEqual((0..<run.len()).map { run.segment($0).name() },
                       ["Tutorial", "Forest", "Boss 1", "Caves", "Boss 2", "Ending"])
        let comparisons = (0..<run.comparisonsLen()).map { run.comparison($0) }
        XCTAssertTrue(comparisons.contains("Goal"))
        let lss = run.saveAsLss()
        XCTAssertTrue(lss.contains("<Offset>-00:00:01.5000"), "negative offset")
        XCTAssertTrue(lss.contains("<Platform usesEmulator=\"False\">Switch</Platform>"))
        // ISO 8601 attempt dates are converted to LiveSplit's UTC format; pause time is kept.
        XCTAssertTrue(lss.contains("started=\"11/20/2026 12:10:39\""))
        XCTAssertTrue(lss.contains("<PauseTime>00:00:04.5000"), "pause time")
        XCTAssertTrue(lss.contains("<Time id=\"3\">"), "segment history")
    }

    func testTimesAndGroups() throws {
        let session = try TimerSession(contentsOf: url)
        let editor = try XCTUnwrap(session.makeEditor())
        let state = try XCTUnwrap(editor.state, editor.lastError ?? "")
        XCTAssertEqual(state.segments.map(\.splitTime), ["30.50", "1:15.00", "2:00.75", "3:00.00", "4:01.12", "5:00.00"])
        XCTAssertEqual(state.segments[0].bestSegmentTime, "28.25")
        // Two groups: [Tutorial, Forest, Boss 1] named "World 1", and [Caves, Boss 2] unnamed.
        XCTAssertEqual(state.rows.filter { $0.kind == "SegmentGroup" }.count, 2)
        let lss = session.lssText()
        XCTAssertTrue(lss.contains("<SegmentGroup start=\"0\" end=\"3\"><Name>World 1</Name>"))
        XCTAssertTrue(lss.contains("<SegmentGroup start=\"3\" end=\"5\""))

        editor.select(0)
        let gameTime = lss.components(separatedBy: "<GameTime>").count - 1
        XCTAssertGreaterThan(gameTime, 0, "game time carried over")
    }

    func testLayoutShowsGroupHeaders() throws {
        let session = try TimerSession(contentsOf: url)
        session.splitOrStart()
        guard case .splits(let splits)? = session.state?.components.first(where: {
            if case .splits = $0 { true } else { false }
        }) else { return XCTFail("no splits component") }
        let rows = splits.splits.filter { !$0.isPlaceholder }
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count, "row ids must be unique")
        XCTAssertEqual(rows.first?.kind, .groupHeader)
        XCTAssertEqual(rows.first?.name, "World 1")
        XCTAssertTrue(rows.contains { $0.kind == .segment && $0.isCurrentSplit && $0.name == "Tutorial" })
        XCTAssertTrue(rows.contains { $0.kind == .groupHeader && $0.name == "Boss 2" }, "collapsed unnamed group")
    }

    func testHelpers() {
        XCTAssertEqual(GreenSplit.timeSpan(200_221_886_560), "00:03:20.2218865")
        XCTAssertEqual(GreenSplit.timeSpan(90_061_000_000_000), "1.01:01:01.0000000")
        XCTAssertEqual(GreenSplit.liveSplitDate("2026-11-20T08:45:29.906Z"), "11/20/2026 08:45:29")
        XCTAssertEqual(GreenSplit.liveSplitDate("07/14/2026 19:32:31"), "07/14/2026 19:32:31")
        XCTAssertNil(GreenSplit.liveSplitDate("yesterday"))
        XCTAssertEqual(GreenSplit.esc("a<b>&\"c\u{1}"), "a&lt;b&gt;&amp;&quot;c")
        XCTAssertEqual(GreenSplit.icon("not base64!"), "")
        let groups = GreenSplit.groups([
            .init(name: "a", depth: 1), .init(name: "b", depth: 0, sectionName: "S"),
            .init(name: "c", depth: 0), .init(name: "d", depth: 1),
        ])
        // A trailing depth-1 segment can't open a group (nothing closes it).
        XCTAssertEqual(groups.map { "\($0.start)-\($0.end)-\($0.name ?? "")" }, ["0-2-S"])
    }
}
