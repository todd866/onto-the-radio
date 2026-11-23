import Foundation

public struct AppleMusicLookupResult: Codable, Equatable, Sendable {
    public var artUrl: String?
    public var previewUrl: String?
    public var appleMusicUrl: String?

    public init(artUrl: String? = nil, previewUrl: String? = nil, appleMusicUrl: String? = nil) {
        self.artUrl = artUrl
        self.previewUrl = previewUrl
        self.appleMusicUrl = appleMusicUrl
    }
}

private struct ITunesSearchEnvelope: Decodable {
    struct Item: Decodable {
        var artworkUrl100: String?
        var previewUrl: String?
        var trackViewUrl: String?
    }
    var results: [Item]
}

public enum AppleMusicCatalog {
    public static func lookup(title: String, creator: String, session: URLSession = .shared) async -> AppleMusicLookupResult? {
        let primaryCreator = creator
            .split(separator: "·", maxSplits: 1).first.map(String.init)?
            .split(separator: "(", maxSplits: 1).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? creator
        let term = "\(primaryCreator) \(title)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              var comps = URLComponents(string: "https://itunes.apple.com/search") else {
            return nil
        }
        comps.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue(ManifoldRadioClient.httpUserAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let env = try? JSONDecoder().decode(ITunesSearchEnvelope.self, from: data),
              let hit = env.results.first else {
            return nil
        }
        let art600 = hit.artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        return AppleMusicLookupResult(
            artUrl: art600,
            previewUrl: hit.previewUrl,
            appleMusicUrl: hit.trackViewUrl
        )
    }

    public static func youtubeMusicSearchURL(title: String, creator: String) -> URL? {
        let primaryCreator = creator
            .split(separator: "·", maxSplits: 1).first.map(String.init)?
            .split(separator: "(", maxSplits: 1).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? creator
        let q = "\(primaryCreator) \(title)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, var comps = URLComponents(string: "https://music.youtube.com/search") else {
            return nil
        }
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        return comps.url
    }
}
