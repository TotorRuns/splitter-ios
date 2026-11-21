import XCTest
@testable import SplitterCore

@MainActor
final class SpeedrunComTests: XCTestCase {
    /// Shape of speedrun.com's /games search response (trimmed, synthetic data).
    let response = """
    {"data":[
      {"id":"g2","names":{"international":"Example Quest 2"},"released":2021,"weblink":"https://www.speedrun.com/eq2",
       "assets":{"cover-large":{"uri":"https://www.speedrun.com/static/game/g2/cover?v=1"},"icon":{"uri":"https://www.speedrun.com/images/1st.png"},"background":null}},
      {"id":"g0","names":{"international":"The Example Quest Collection"},"released":2023,"weblink":"https://www.speedrun.com/eqc",
       "assets":{"cover-tiny":{"uri":"https://www.speedrun.com/static/game/g0/cover?v=2"}}},
      {"id":"g1","names":{"international":"Example Quest"},"released":2019,"weblink":"https://www.speedrun.com/eq","assets":{}}
    ],"pagination":{"size":3}}
    """

    func testParsesGamesAndPrefersCoverArt() throws {
        let games = try SpeedrunCom.parseGames(Data(response.utf8))
        XCTAssertEqual(games.map(\.id), ["g2", "g0", "g1"])
        XCTAssertEqual(games[0].coverURL?.absoluteString, "https://www.speedrun.com/static/game/g2/cover?v=1",
                       "cover, not the generic icon asset")
        XCTAssertEqual(games[1].coverURL?.absoluteString, "https://www.speedrun.com/static/game/g0/cover?v=2",
                       "falls back to smaller covers")
        XCTAssertNil(games[2].coverURL)
        XCTAssertEqual(games[0].released, 2021)
        XCTAssertEqual(games[0].webURL?.absoluteString, "https://www.speedrun.com/eq2")
    }

    func testRanksExactMatchFirst() throws {
        let games = try SpeedrunCom.parseGames(Data(response.utf8))
        XCTAssertEqual(SpeedrunCom.rank(games, for: "example quest").map(\.id), ["g1", "g2", "g0"])
        // Punctuation and accents don't matter.
        XCTAssertEqual(SpeedrunCom.normalize("Pokémon: Red/Blue"), SpeedrunCom.normalize("pokemon red blue"))
    }

    func testSearchURLEncodesName() {
        let url = SpeedrunCom.searchURL(for: "Mario & Sonic").absoluteString
        XCTAssertTrue(url.hasPrefix("https://www.speedrun.com/api/v1/games?"), url)
        XCTAssertTrue(url.contains("name=Mario%20%26%20Sonic"), url)
    }

    func testImageSniffing() {
        XCTAssertTrue(SpeedrunCom.isImage(Data([0xFF, 0xD8, 0xFF, 0xE0])))
        XCTAssertTrue(SpeedrunCom.isImage(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])))
        XCTAssertTrue(SpeedrunCom.isImage(Data("RIFF\u{0}\u{0}\u{0}\u{0}WEBP".utf8)))
        XCTAssertFalse(SpeedrunCom.isImage(Data("<!DOCTYPE html>".utf8)), "Cloudflare challenge page")
        XCTAssertFalse(SpeedrunCom.isImage(Data()))
    }

    func testEditorIconRoundTrip() throws {
        let editor = try XCTUnwrap(RunEditorSession.newRun())
        XCTAssertNil(editor.gameIconData())
        let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
            .appendingPathComponent("legacy.split/gameIcon.png")
        let png = try Data(contentsOf: url)
        editor.setGameIcon(png)
        let stored = try XCTUnwrap(editor.gameIconData())
        XCTAssertTrue(SpeedrunCom.isImage(stored))
        editor.setGameIcon(nil)
        XCTAssertNil(editor.gameIconData())
    }
}
