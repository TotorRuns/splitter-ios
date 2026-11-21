import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A game on speedrun.com, from its public REST API (https://github.com/speedruncomorg/api).
public struct SpeedrunComGame: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var released: Int?
    /// Box art. speedrun.com's `icon` asset is now a generic site image, so the cover is the
    /// useful artwork for a game icon.
    public var coverURL: URL?
    public var webURL: URL?
}

public enum SpeedrunComError: LocalizedError, Equatable {
    case noCover
    /// speedrun.com's Cloudflare protection refused the request (it returns an HTML challenge).
    case blocked
    case notAnImage
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .noCover: "speedrun.com has no artwork for this game."
        case .blocked: "speedrun.com didn't allow the download right now. Try again in a little while, or open the game on speedrun.com, save its artwork and choose it from Photos."
        case .notAnImage: "speedrun.com didn't return an image."
        case .http(let code): "speedrun.com returned an error (HTTP \(code))."
        }
    }
}

public enum SpeedrunCom {
    /// Identifies the app honestly, as speedrun.com's API guidelines ask.
    public static let userAgent = "Splitter-iOS/1.0 (+https://github.com/TotorRuns/splitter-ios)"
    static let api = URL(string: "https://www.speedrun.com/api/v1/")!

    public static func searchURL(for name: String) -> URL {
        var c = URLComponents(url: api.appendingPathComponent("games"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "max", value: "20")]
        return c.url!
    }

    // MARK: Parsing

    private struct Response: Decodable {
        struct Game: Decodable {
            struct Names: Decodable { var international: String }
            struct Asset: Decodable { var uri: String? }
            var id: String
            var names: Names
            var released: Int?
            var weblink: String?
            var assets: [String: Asset?]?
        }
        var data: [Game]
    }

    public static func parseGames(_ data: Data) throws -> [SpeedrunComGame] {
        try JSONDecoder().decode(Response.self, from: data).data.map { g in
            let cover = ["cover-large", "cover-medium", "cover-small", "cover-tiny"]
                .lazy.compactMap { g.assets?[$0]??.uri }.compactMap(URL.init(string:)).first
            return SpeedrunComGame(id: g.id, name: g.names.international, released: g.released,
                                   coverURL: cover, webURL: g.weblink.flatMap(URL.init(string:)))
        }
    }

    /// Exact name matches first, then names starting with the query, then the rest (stable).
    public static func rank(_ games: [SpeedrunComGame], for query: String) -> [SpeedrunComGame] {
        let q = normalize(query)
        func score(_ g: SpeedrunComGame) -> Int {
            let n = normalize(g.name)
            if n == q { return 0 }
            if n.hasPrefix(q) { return 1 }
            return 2
        }
        return games.enumerated()
            .sorted { (score($0.element), $0.offset) < (score($1.element), $1.offset) }
            .map(\.element)
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Recognises the image formats livesplit-core and UIKit both read.
    public static func isImage(_ data: Data) -> Bool {
        let b = [UInt8](data.prefix(12))
        guard b.count >= 4 else { return false }
        if b.starts(with: [0xFF, 0xD8, 0xFF]) { return true }                       // JPEG
        if b.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }                 // PNG
        if b.starts(with: [0x47, 0x49, 0x46, 0x38]) { return true }                 // GIF
        if b.count >= 12, b.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(b[8..<12]) == [0x57, 0x45, 0x42, 0x50] { return true }             // WebP
        return false
    }

    // MARK: Network

    private static func get(_ url: URL, accept: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpeedrunComError.http(0) }
        return (data, http)
    }

    public static func searchGames(named name: String) async throws -> [SpeedrunComGame] {
        let (data, http) = try await get(searchURL(for: name), accept: "application/json")
        if http.statusCode == 403 || http.statusCode == 429 { throw SpeedrunComError.blocked }
        guard http.statusCode == 200 else { throw SpeedrunComError.http(http.statusCode) }
        return rank(try parseGames(data), for: name)
    }

    /// Downloads the game's cover art. Throws `.blocked` when Cloudflare refuses the request;
    /// this doesn't try to get around that protection.
    public static func downloadCover(for game: SpeedrunComGame) async throws -> Data {
        guard let url = game.coverURL else { throw SpeedrunComError.noCover }
        let (data, http) = try await get(url, accept: "*/*")
        let type = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        if http.statusCode == 403 || http.statusCode == 429 || type.hasPrefix("text/html") {
            throw SpeedrunComError.blocked
        }
        guard http.statusCode == 200 else { throw SpeedrunComError.http(http.statusCode) }
        guard isImage(data) else { throw SpeedrunComError.notAnImage }
        return data
    }
}
