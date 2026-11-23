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

        async let worksData = session.data(from: worksURL)
        async let lensesData = session.data(from: lensesURL)
        async let repData = session.data(from: repURL)

        let (wBytes, _) = try await worksData
        let (lBytes, _) = try await lensesData
        let (rBytes, _) = try await repData

        let decoder = JSONDecoder()
        let wEnv = try decoder.decode(WorksEnvelope.self, from: wBytes)
        let lEnv = try decoder.decode(LensesEnvelope.self, from: lBytes)
        let rEnv = try decoder.decode(ReputationEnvelope.self, from: rBytes)
        return (wEnv.works, lEnv.lenses, rEnv.contributors)
    }

    /// Built-in CC0 / Public-Domain showcase works so offline launches & Apple App Review
    /// play music steered by signed Manifold lenses immediately with zero external setup.
    public static let bundledWorks: [RadioWork] = [
        RadioWork(
            workId: "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31",
            title: "Goldberg Variations, BWV 988: Aria",
            creator: "J. S. Bach · Kimiko Ishizaka (CC0)",
            year: 2012,
            kind: "classical · solo keyboard",
            summary: "CC0 public dedication recording with crystalline voice-leading.",
            energy: 0.22,
            heaviness: 0.14,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d3/Kimiko_Ishizaka_-_J.S._Bach_-_%27Open%27_Goldberg_Variations%2C_BWV_988_-_01_Aria.flac/Kimiko_Ishizaka_-_J.S._Bach_-_%27Open%27_Goldberg_Variations%2C_BWV_988_-_01_Aria.flac.mp3",
            durationSec: 300,
            vec32: [42, -18, 31, 12, -9, 24, 15, -11, 8, 19, -6, 14, 7, -4, 10, 5]
        ),
        RadioWork(
            workId: "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736",
            title: "Gymnopédie No. 1",
            creator: "Erik Satie · Public Domain",
            year: 1888,
            kind: "ambient · chamber piano",
            summary: "Suspended major-seventh chords in quiet nocturnal stillness.",
            energy: 0.12,
            heaviness: 0.08,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/98/Gymnopedie_No_1.ogg/Gymnopedie_No_1.ogg.mp3",
            durationSec: 189,
            vec32: [48, -22, 27, 9, -14, 29, 18, -8, 11, 22, -4, 16, 5, -7, 12, 8]
        ),
        RadioWork(
            workId: "mbid:b30c5632-0842-4c9a-9459-6b525a67b87d",
            title: "Clair de Lune",
            creator: "Claude Debussy · CC BY",
            year: 1905,
            kind: "impressionist · nocturnal piano",
            summary: "Rippling arpeggios in D-flat major.",
            energy: 0.18,
            heaviness: 0.11,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/be/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg.mp3",
            durationSec: 304,
            vec32: [45, -19, 29, 11, -11, 26, 16, -9, 9, 20, -5, 15, 6, -5, 11, 7]
        ),
        RadioWork(
            workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614",
            title: "Cello Suite No. 1 in G Major, Prelude",
            creator: "J. S. Bach · John Michel",
            year: 1720,
            kind: "chamber · solo strings",
            summary: "Resonant solo cello arpeggios with steady harmonic climb.",
            energy: 0.34,
            heaviness: 0.19,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/47/BWV_1007_-_Prelude.ogg/BWV_1007_-_Prelude.ogg.mp3",
            durationSec: 146,
            vec32: [38, -14, 33, 16, -6, 20, 12, -13, 6, 17, -8, 11, 9, -2, 8, 4]
        )
    ]

    public static let bundledLenses: [RadioLens] = [
        RadioLens(
            id: "lens:radio:late-wire",
            domain: "radio",
            name: "Late wire",
            summary: "Tape-loop ambient, nocturnal piano, and dub sub-bass",
            issuer: "ed25519:canon-steward",
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
            id: "lens:radio:chamber-focus",
            domain: "radio",
            name: "Chamber focus",
            summary: "CC0 Goldberg counterpoint, solo cello suites, and modal ballads",
            issuer: "ed25519:archive-curator",
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
