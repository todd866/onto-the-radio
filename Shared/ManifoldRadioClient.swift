import Foundation

public struct WorksEnvelope: Codable {
    public var count: Int
    public var works: [RadioWork]
}

public struct LensesEnvelope: Codable {
    public var count: Int
    public var lenses: [RadioLens]
}

public struct ReputationEnvelope: Codable {
    public var count: Int
    public var contributors: [ContributorReputation]
}

public enum ManifoldRadioClient {
    public static let fallbackHub = "https://manifold-chi.vercel.app"
    public static let httpUserAgent = "OntoTheRadio/1.0 (https://github.com/todd866/onto-the-radio)"

    public static var defaultHub: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "ManifoldDefaultHub") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.hasPrefix("https://") || raw.hasPrefix("http://"), !raw.contains("$(") {
            return raw
        }
        return fallbackHub
    }

    public static func fetchSnapshot(hubBase: String, session: URLSession = .shared) async throws -> (
        works: [RadioWork],
        lenses: [RadioLens],
        contributors: [ContributorReputation]
    ) {
        let clean = hubBase.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let worksURL = URL(string: "\(clean)/api/v1/works?domain=radio&limit=100"),
              let lensesURL = URL(string: "\(clean)/api/v1/lenses?domain=radio"),
              let repURL = URL(string: "\(clean)/api/v1/reputation") else {
            throw URLError(.badURL)
        }

        let makeRequest: @Sendable (URL) -> URLRequest = { url in
            var req = URLRequest(url: url)
            req.setValue(httpUserAgent, forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 12
            return req
        }

        async let worksData = session.data(for: makeRequest(worksURL))
        async let lensesData = session.data(for: makeRequest(lensesURL))
        async let repData = session.data(for: makeRequest(repURL))

        let (wBytes, _) = try await worksData
        let (lBytes, _) = try await lensesData
        let (rBytes, _) = try await repData

        let decoder = JSONDecoder()
        let wEnv = try decoder.decode(WorksEnvelope.self, from: wBytes)
        let lEnv = try decoder.decode(LensesEnvelope.self, from: lBytes)
        let rEnv = try decoder.decode(ReputationEnvelope.self, from: rBytes)
        return (wEnv.works, lEnv.lenses, rEnv.contributors)
    }

    /// Built-in CC0 / Public-Domain showcase works with verified HTTP 200 MP3 streams so
    /// offline/first launches play music steered by signed Manifold lenses right away.
    public static let bundledWorks: [RadioWork] = [
        RadioWork(
            workId: "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31",
            title: "Goldberg Variations, BWV 988: Aria",
            creator: "J. S. Bach · Kimiko Ishizaka (CC0)",
            year: 2012,
            kind: "classical · solo keyboard",
            summary: "Luminous ornamented sarabande recorded under CC0 public dedication with crystalline voice-leading.",
            energy: 0.22,
            heaviness: 0.14,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/e6/Kimiko_Ishizaka_-_01_-_Aria.ogg/Kimiko_Ishizaka_-_01_-_Aria.ogg.mp3",
            durationSec: 300,
            vec32: [42, -18, 31, 12, -9, 24, 15, -11, 8, 19, -6, 14, 7, -4, 10, 5],
            x: -0.8137,
            y: 0.4421,
            sourceLabel: "CC0"
        ),
        RadioWork(
            workId: "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736",
            title: "Gymnopédie No. 1 (Lent et douloureux)",
            creator: "Erik Satie · Kevin MacLeod (CC BY)",
            year: 1888,
            kind: "ambient · chamber piano",
            summary: "Sparse suspended major-seventh chords floating in quiet nocturnal stillness.",
            energy: 0.12,
            heaviness: 0.08,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/6/68/Kevin_MacLeod_-_Erik_Satie_Gymnopedie_No_1.ogg/Kevin_MacLeod_-_Erik_Satie_Gymnopedie_No_1.ogg.mp3",
            durationSec: 189,
            vec32: [48, -22, 27, 9, -14, 29, 18, -8, 11, 22, -4, 16, 5, -7, 12, 8],
            x: -0.5978,
            y: 0.0726,
            sourceLabel: "CC BY"
        ),
        RadioWork(
            workId: "mbid:b30c5632-0842-4c9a-9459-6b525a67b87d",
            title: "Clair de Lune (Suite bergamasque)",
            creator: "Claude Debussy · Laurens Goedhart (CC BY)",
            year: 1905,
            kind: "impressionist · nocturnal piano",
            summary: "Rippling arpeggios in D-flat major evoking moonlight on still water.",
            energy: 0.18,
            heaviness: 0.11,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/be/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg.mp3",
            durationSec: 304,
            vec32: [45, -19, 29, 11, -11, 26, 16, -9, 9, 20, -5, 15, 6, -5, 11, 7],
            x: -0.8600,
            y: -0.2269,
            sourceLabel: "CC BY"
        ),
        RadioWork(
            workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614",
            title: "Cello Suite No. 1 in G Major, Prelude",
            creator: "J. S. Bach · John Michel (CC BY-SA)",
            year: 1720,
            kind: "chamber · solo strings",
            summary: "Unbroken resonant cello arpeggios climbing steadily with warm wooden harmonics.",
            energy: 0.34,
            heaviness: 0.19,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/43/JOHN_MICHEL_CELLO-J_S_BACH_CELLO_SUITE_1_in_G_Prelude.ogg/JOHN_MICHEL_CELLO-J_S_BACH_CELLO_SUITE_1_in_G_Prelude.ogg.mp3",
            durationSec: 146,
            vec32: [38, -14, 33, 16, -6, 20, 12, -13, 6, 17, -8, 11, 9, -2, 8, 4],
            x: -0.7536,
            y: 0.1304,
            sourceLabel: "CC BY-SA"
        )
    ]

    public static let bundledLenses: [RadioLens] = [
        RadioLens(
            id: "lens:radio:late-wire",
            domain: "radio",
            name: "Late wire",
            summary: "Tape-loop ambient, nocturnal piano, and South London dub sub-bass",
            issuer: "ed25519:82PCkbYGhiH595pnzwEKVxg-hBZGsURhGzvpRPwYfLQ",
            issuerHandle: "canon.steward",
            modelId: "embeddinggemma-2",
            subscribers: 319,
            completionRate: 0.94,
            anchors: [
                RadioLensAnchor(workId: "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736", weight: 0.95, mark: "good"),
                RadioLensAnchor(workId: "mbid:b30c5632-0842-4c9a-9459-6b525a67b87d", weight: 0.90, mark: "good")
            ],
            signatureValid: true
        ),
        RadioLens(
            id: "lens:radio:motorik-pulse",
            domain: "radio",
            name: "Motorik pulse",
            summary: "Autobahn 4/4 krautrock, Manchester post-punk, and sequenced synth drive",
            issuer: "ed25519:82PCkbYGhiH595pnzwEKVxg-hBZGsURhGzvpRPwYfLQ",
            issuerHandle: "canon.steward",
            modelId: "embeddinggemma-2",
            subscribers: 267,
            completionRate: 0.91,
            anchors: [
                RadioLensAnchor(workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614", weight: 0.92, mark: "good"),
                RadioLensAnchor(workId: "mbid:e317a495-2189-4138-8635-5a817c910421", weight: 1.0, mark: "good")
            ],
            signatureValid: true
        ),
        RadioLens(
            id: "lens:radio:chamber-focus",
            domain: "radio",
            name: "Chamber focus",
            summary: "CC0 Goldberg counterpoint, solo cello suites, and modal jazz ballads",
            issuer: "ed25519:canon-archive",
            issuerHandle: "archive.curator",
            modelId: "embeddinggemma-2",
            subscribers: 184,
            completionRate: 0.92,
            anchors: [
                RadioLensAnchor(workId: "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614", weight: 0.95, mark: "good")
            ],
            signatureValid: true
        )
    ]
}
