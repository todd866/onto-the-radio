import Foundation
import Security

public enum RadioKeychain {
    private static let service = "com.iantodd.ontotheradio.homeserver"

    public static func savePassword(_ password: String, server: String) {
        let acct = normalizedServer(server)
        guard !acct.isEmpty, let data = password.data(using: .utf8) else { return }
        deletePassword(server: acct)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public static func loadPassword(server: String) -> String? {
        let acct = normalizedServer(server)
        guard !acct.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func deletePassword(server: String) {
        let acct = normalizedServer(server)
        guard !acct.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func normalizedServer(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.isEmpty && !s.contains("://") {
            s = "https://\(s)"
        }
        return s
    }
}

public enum HomeRadioError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .unauthorized: return "Incorrect server password"
        case .serverError(let code): return "Server returned HTTP \(code)"
        }
    }
}

public struct GlancebarNowState: Codable, Equatable, Sendable {
    public var state: String      // "playing", "paused", "stopped"
    public var title: String?
    public var artist: String?
    public var liked: Bool?
    public var host: String?
    public var epoch: Double?
    public var album: String?
    public var mood: String?
    public var station: String?
    public var elapsed: Double?
    public var duration: Double?

    public init(
        state: String,
        title: String? = nil,
        artist: String? = nil,
        liked: Bool? = nil,
        host: String? = nil,
        epoch: Double? = nil,
        album: String? = nil,
        mood: String? = nil,
        station: String? = nil,
        elapsed: Double? = nil,
        duration: Double? = nil
    ) {
        self.state = state
        self.title = title
        self.artist = artist
        self.liked = liked
        self.host = host
        self.epoch = epoch
        self.album = album
        self.mood = mood
        self.station = station
        self.elapsed = elapsed
        self.duration = duration
    }
}

private struct GlancebarCommandEnvelope: Decodable {
    var ok: Bool
    var now: GlancebarNowState?
}

private struct HomeEnvelope: Decodable {
    struct TilePoint: Decodable { var x: Double; var y: Double }
    struct StationInfo: Decodable { var id: String; var name: String; var color: String?; var count: Int? }
    struct Tile: Decodable {
        var kind: String
        var s: String?
        var title: String
        var sub: String
        var artist: String?
        var art: Bool?
        var color: String?
        var point: TilePoint?
        var mood: String?
        var logo: String?
        var station: StationInfo?
    }
    struct Shelf: Decodable {
        var id: String
        var title: String
        var tiles: [Tile]
    }
    var shelves: [Shelf]
}

private struct HomeQueueEnvelope: Decodable {
    struct Pick: Decodable {
        var s: String
        var a: String
        var t: String
        var al: String?
        var y: Int?
        var g: String?
        var e: Double?
        var h: Double?
        var x: Double?
        var yy: Double?
        var tag: String?
        var dur: Double?
        var color: String?
        var art: Bool?
        var pt: String?
    }
    var picks: [Pick]
}

public enum HomeRadioClient {
    public static func signIn(baseURL: String, password: String, session: URLSession = .shared) async throws -> String {
        let clean = RadioKeychain.normalizedServer(baseURL)
        guard let url = URL(string: "\(clean)/api/login") else { throw HomeRadioError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONEncoder().encode(["pass": password, "name": "Onto the Radio"])
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw HomeRadioError.unauthorized }
        guard (200..<300).contains(code) else { throw HomeRadioError.serverError(code) }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = json["name"] as? String, !name.isEmpty {
            return name
        }
        return "Connected"
    }

    public static func fetchHome(baseURL: String, session: URLSession = .shared) async throws -> (
        tracks: [RadioWork],
        stations: [RadioLens]
    ) {
        let clean = RadioKeychain.normalizedServer(baseURL)
        guard let url = URL(string: "\(clean)/api/home") else { throw HomeRadioError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw HomeRadioError.unauthorized }
        guard (200..<300).contains(code) else { throw HomeRadioError.serverError(code) }

        let env = try JSONDecoder().decode(HomeEnvelope.self, from: data)
        var tracks: [RadioWork] = []
        var stations: [RadioLens] = []
        var seenWorks = Set<String>()

        for shelf in env.shelves {
            for tile in shelf.tiles {
                if tile.kind == "song", let sha = tile.s, !sha.isEmpty {
                    let wid = "home:\(sha)"
                    if seenWorks.insert(wid).inserted {
                        let artStr = (tile.art ?? false) ? "\(clean)/api/art/\(sha)?size=300" : nil
                        let year = parseYear(tile.sub)
                        tracks.append(
                            RadioWork(
                                workId: wid,
                                title: tile.title,
                                creator: tile.artist ?? tile.sub,
                                year: year,
                                kind: shelf.title,
                                summary: tile.sub,
                                energy: 0.45,
                                heaviness: 0.35,
                                streamUrl: "\(clean)/api/audio/\(sha)?q=aac",
                                durationSec: 210,
                                vec32: nil,
                                localBookmark: nil,
                                x: tile.point?.x,
                                y: tile.point?.y,
                                artUrl: artStr,
                                colorHex: tile.color,
                                sourceLabel: "Home server"
                            )
                        )
                    }
                } else if tile.kind == "station", let st = tile.station {
                    stations.append(
                        RadioLens(
                            id: "home-station:\(st.id)",
                            domain: "radio",
                            name: st.name,
                            summary: tile.sub,
                            issuer: "home-server",
                            issuerHandle: "home.library",
                            modelId: "gemini-embedding-2",
                            subscribers: st.count,
                            completionRate: 0.96,
                            anchors: [],
                            signatureValid: true,
                            colorHex: tile.color,
                            artUrl: tile.logo.map { $0.hasPrefix("http") ? $0 : "\(clean)\($0)" }
                        )
                    )
                }
            }
        }
        return (tracks, stations)
    }

    public static func fetchStationQueue(baseURL: String, mood: String, session: URLSession = .shared) async throws -> [RadioWork] {
        let clean = RadioKeychain.normalizedServer(baseURL)
        guard let url = URL(string: "\(clean)/api/queue") else { throw HomeRadioError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["mood": mood, "n": 18])
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw HomeRadioError.unauthorized }
        guard (200..<300).contains(code) else { throw HomeRadioError.serverError(code) }

        let env = try JSONDecoder().decode(HomeQueueEnvelope.self, from: data)
        return env.picks.map { p in
            RadioWork(
                workId: "home:\(p.s)",
                title: p.t,
                creator: p.a,
                year: p.y ?? 2024,
                kind: p.g ?? "home mix",
                summary: p.tag ?? (p.al ?? "Home library"),
                energy: p.e,
                heaviness: p.h,
                streamUrl: "\(clean)/api/audio/\(p.s)?q=aac",
                durationSec: Int(p.dur ?? 210),
                vec32: nil,
                localBookmark: nil,
                x: p.x,
                y: p.yy,
                artUrl: (p.art ?? false) ? "\(clean)/api/art/\(p.s)?size=600" : nil,
                colorHex: p.color,
                sourceLabel: "Home server",
                pickToken: p.pt
            )
        }
    }

    public static func sendEvent(baseURL: String, pickToken: String, event: String, pos: Double, session: URLSession = .shared) async {
        let clean = RadioKeychain.normalizedServer(baseURL)
        guard !clean.isEmpty, !pickToken.isEmpty, let url = URL(string: "\(clean)/api/event") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["pt": pickToken, "ev": event, "pos": pos])
        _ = try? await session.data(for: req)
    }

    public static func fetchGlancebarNow(baseURL: String, session: URLSession = .shared) async throws -> GlancebarNowState {
        let url = try endpointURL(baseURL: baseURL, path: "/api/glancebar/now")
        var req = URLRequest(url: url)
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        let (data, resp) = try await session.data(for: req)
        try validateHTTPStatus(resp)
        return try JSONDecoder().decode(GlancebarNowState.self, from: data)
    }

    public static func sendGlancebarCommand(baseURL: String, cmd: String, session: URLSession = .shared) async throws -> GlancebarNowState? {
        let url = try endpointURL(baseURL: baseURL, path: "/api/glancebar/cmd")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        req.httpBody = try JSONEncoder().encode(["cmd": cmd])
        let (data, resp) = try await session.data(for: req)
        try validateHTTPStatus(resp)
        let env = try JSONDecoder().decode(GlancebarCommandEnvelope.self, from: data)
        return env.ok ? env.now : nil
    }

    private static func endpointURL(baseURL: String, path: String) throws -> URL {
        let clean = RadioKeychain.normalizedServer(baseURL)
        guard !clean.isEmpty,
              let url = URL(string: "\(clean)\(path)"),
              let scheme = url.scheme, !scheme.isEmpty,
              let host = url.host, !host.isEmpty else {
            throw HomeRadioError.invalidURL
        }
        return url
    }

    private static func validateHTTPStatus(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw HomeRadioError.unauthorized }
        guard (200..<300).contains(code) else { throw HomeRadioError.serverError(code) }
    }

    private static func parseYear(_ raw: String) -> Int {
        for token in raw.split(whereSeparator: { !$0.isNumber }) {
            if token.count == 4, let y = Int(token), (1700...2035).contains(y) {
                return y
            }
        }
        return 2024
    }
}
