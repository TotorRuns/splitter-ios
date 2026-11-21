import XCTest
@testable import SplitterCore

final class PaletteTests: XCTestCase {
    /// livesplit-core's default layout background.
    let background = RGBA(0.06, 0.06, 0.06)
    let states: [SemanticColor] = [.AheadGainingTime, .AheadLosingTime, .BehindGainingTime, .BehindLosingTime,
                                   .BestSegment, .NotRunning, .Paused, .PersonalBest]

    func testEveryPaletteMeetsItsContrastTarget() {
        for scheme in SplitColorScheme.allCases {
            for increased in [false, true] {
                let palette = Palette(scheme: scheme, increasedContrast: increased)
                for state in states {
                    let color = try! XCTUnwrap(palette.color(for: state))
                    let ratio = color.contrast(against: background)
                    XCTAssertGreaterThanOrEqual(ratio, palette.targetContrast,
                        "\(scheme) increased=\(increased) \(state): \(ratio)")
                }
            }
        }
    }

    func testLiveSplitDefaultRedFailsWhichIsWhyWeReplaceIt() {
        // livesplit-core's default "behind, losing time" colour.
        XCTAssertLessThan(RGBA(0.8, 0, 0).contrast(against: background), 4.5)
    }

    func testColorBlindPaletteAvoidsRedGreen() {
        let p = Palette(scheme: .colorBlindFriendly)
        let ahead = p.color(for: .AheadGainingTime)!, behind = p.color(for: .BehindLosingTime)!
        XCTAssertGreaterThan(ahead.b, ahead.r, "ahead is blue")
        XCTAssertGreaterThan(behind.r, behind.b, "behind is orange")
        XCTAssertLessThan(behind.g, behind.r)
    }

    func testDefaultUsesTextColorAndSpokenDescriptions() {
        XCTAssertNil(Palette().color(for: .Default))
        XCTAssertEqual(SemanticColor.BehindLosingTime.spokenDescription, "behind, losing time")
        XCTAssertEqual(SemanticColor.BestSegment.spokenDescription, "best segment")
        XCTAssertNil(SemanticColor.Default.spokenDescription)
        XCTAssertTrue(SemanticColor.BestSegment.isBestSegment)
    }

    func testContrastMath() {
        XCTAssertEqual(RGBA(1, 1, 1).contrast(against: RGBA(0, 0, 0)), 21, accuracy: 0.01)
        XCTAssertEqual(RGBA(0.5, 0.5, 0.5).contrast(against: RGBA(0.5, 0.5, 0.5)), 1, accuracy: 0.001)
        // Half-transparent white over black is a mid grey.
        XCTAssertEqual(RGBA(1, 1, 1, 0.5).over(RGBA(0, 0, 0)).r, 0.5, accuracy: 0.001)
    }
}
