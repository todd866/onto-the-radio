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
            creator: "Johann Sebastian Bach · Kimiko Ishizaka (CC0)",
            year: 2012,
            kind: "classical · solo keyboard",
            summary: "Luminous ornamented sarabande on modern piano recorded under CC0 public dedication with crystalline voice-leading.",
            energy: 0.22,
            heaviness: 0.14,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/e6/Kimiko_Ishizaka_-_01_-_Aria.ogg/Kimiko_Ishizaka_-_01_-_Aria.ogg.mp3",
            durationSec: 300,
            vec32: [-30, -30, 32, -4, 29, 19, -25, 21, -55, -65, 51, 38, 43, 14, 10, -24, 22, -32, -9, -1, -28, -27, -32, 1, -2, 10, 23, 20, -28, -32, -5, 8],
            x: -0.6686,
            y: -0.2459,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/5b/56/fc/dj.rfpdsvls.jpg/600x600bb.jpg",
            sourceLabel: "CC0",
            shortTitle: "Goldberg: Aria",
            hook: "Crisp solo keyboard",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/22/58/6a/22586a4a-ac49-b6b9-d571-a01685798446/mzaf_10091356160329963106.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/aria/252825957?i=252825962&uo=4"
        ),
        RadioWork(
            workId: "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736",
            title: "Gymnopédie No. 1 (Lent et douloureux)",
            creator: "Erik Satie · Kevin MacLeod (CC BY)",
            year: 1888,
            kind: "ambient · chamber piano",
            summary: "Sparse suspended major-seventh piano chords floating in quiet nocturnal stillness, precursor to modern ambient minimalism.",
            energy: 0.12,
            heaviness: 0.08,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/6/68/Kevin_MacLeod_-_Erik_Satie_Gymnopedie_No_1.ogg/Kevin_MacLeod_-_Erik_Satie_Gymnopedie_No_1.ogg.mp3",
            durationSec: 189,
            vec32: [-49, -21, 1, -51, 15, -7, 1, 2, -49, -58, -31, -49, -1, 37, -12, -10, -21, -15, 21, 20, 3, 8, 8, 16, 13, -25, 13, 13, 26, 5, 1, -5],
            x: -0.6284,
            y: 0.4621,
            artUrl: nil,
            sourceLabel: "CC BY",
            shortTitle: "Gymnopédie No. 1",
            hook: "Minimal nocturnal piano",
            category: "classical",
            previewUrl: nil,
            appleMusicUrl: nil
        ),
        RadioWork(
            workId: "mbid:b30c5632-0842-4c9a-9459-6b525a67b87d",
            title: "Clair de Lune (Suite bergamasque)",
            creator: "Claude Debussy · Laurens Goedhart (CC BY)",
            year: 1905,
            kind: "impressionist · nocturnal piano",
            summary: "Rippling impressionist arpeggios in D-flat major evoking moonlight on still water.",
            energy: 0.18,
            heaviness: 0.11,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/be/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg.mp3",
            durationSec: 304,
            vec32: [-60, -25, 13, -13, 65, -27, -9, 2, -57, -47, -47, 37, -16, 21, 18, -6, 0, -6, -9, -3, 8, 9, 1, 31, 5, 18, 18, 24, 9, 12, -3, 22],
            x: -0.86,
            y: 0.3384,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/ed/f1/ef/edf1ef8d-88ea-dede-5c7c-2236e3b55456/888344195831.jpg/600x600bb.jpg",
            sourceLabel: "CC BY",
            shortTitle: "Clair de Lune",
            hook: "Shimmering Debussy piano",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/ee/40/d1/ee40d1d6-1324-1c8f-5104-b62d269b3f8d/mzaf_10121585798363736089.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/clair-de-lune-moonlight-debussy-classic-lullaby/1517956001?i=1517956004&uo=4"
        ),
        RadioWork(
            workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614",
            title: "Cello Suite No. 1 in G Major, Prelude",
            creator: "Johann Sebastian Bach · John Michel (CC BY-SA)",
            year: 1720,
            kind: "chamber · solo strings",
            summary: "Unbroken resonant cello arpeggios climbing steadily with warm wooden harmonics and focused momentum.",
            energy: 0.34,
            heaviness: 0.19,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/43/JOHN_MICHEL_CELLO-J_S_BACH_CELLO_SUITE_1_in_G_Prelude.ogg/JOHN_MICHEL_CELLO-J_S_BACH_CELLO_SUITE_1_in_G_Prelude.ogg.mp3",
            durationSec: 146,
            vec32: [-44, -37, -13, -30, 54, 4, -28, 34, -24, -53, 5, 39, 31, -23, 11, 11, -6, -19, 28, -23, 7, 43, 0, 0, -8, 25, -4, -23, -19, -11, -16, -42],
            x: -0.795,
            y: -0.2977,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/0c/f5/ed/0cf5ed24-02ba-03f4-8c83-ff41dcba5be3/884977621860.jpg/600x600bb.jpg",
            sourceLabel: "CC BY-SA",
            shortTitle: "Cello Suite No. 1",
            hook: "Resonant solo cello",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/92/5e/0a/925e0a0d-f33d-a493-f50a-2fa9bcbdd746/mzaf_352011344661116690.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/cello-suite-no-1-in-g-major-bwv-1007-i-pr%C3%A9lude/381515547?i=381515553&uo=4"
        ),
        RadioWork(
            workId: "mbid:95142316-7154-4f25-bd45-224352617045",
            title: "So What",
            creator: "Miles Davis",
            year: 1959,
            kind: "modal jazz",
            summary: "Double-bass call answered by two-chord Dorian horn voicings and unhurried trumpet phrasing on Kind of Blue.",
            energy: 0.39,
            heaviness: 0.22,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-44, -42, 19, 30, 24, -28, -36, -41, 21, 10, -24, -30, 26, 1, -18, -18, 6, 18, -54, -2, 0, 11, -7, 5, 10, 57, -14, -22, 10, -42, 27, -22],
            x: 0.0868,
            y: 0.7051,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music/7f/9f/d6/mzi.vtnaewef.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "So What",
            hook: "Walking bass & space",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/54/e8/0a/54e80a8b-1d60-6b59-e908-6fd65c4ff783/mzaf_2469862574651846302.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/so-what/268443092?i=268443097&uo=4"
        ),
        RadioWork(
            workId: "mbid:a21a9293-31f7-504c-9d9f-d4a4ec0bd6e2",
            title: "In a Silent Way",
            creator: "Miles Davis",
            year: 1969,
            kind: "electric jazz · ambient fusion",
            summary: "Floating dual electric pianos, clean guitar shimmer, and Teo Macero tape-spliced ambient groove — pure late-night headphones.",
            energy: 0.31,
            heaviness: 0.24,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-82, -59, -10, 19, -19, -1, -17, -58, -3, -9, -21, -20, 14, 22, -10, 3, -4, 11, -1, -17, 0, -21, -18, 7, 5, -20, -23, -33, -6, 2, -18, 5],
            x: 0.3153,
            y: 0.4482,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music/v4/f3/91/31/f391312d-0abf-bd64-3d19-8e6ba0d9774f/MilesDavis_InASilentWay_G010000669542M_F_001_RGB.jpeg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "In a Silent Way",
            hook: "Electric Rhodes trance",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/2d/44/52/2d4452eb-09b6-23cc-20a0-f785d3b31e03/mzaf_1693825392874386614.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/in-a-silent-way/830638388?i=830648679&uo=4"
        ),
        RadioWork(
            workId: "mbid:6cf409af-8afa-5d5b-bcd0-358795af40b4",
            title: "Générique (Ascenseur pour l'échafaud)",
            creator: "Miles Davis",
            year: 1958,
            kind: "cool jazz · film noir",
            summary: "Late-night muted trumpet improvised live to French noir footage over brushed snare and solitary walking bass.",
            energy: 0.24,
            heaviness: 0.26,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-70, -14, 1, 42, 46, -26, -10, -29, -5, -16, -33, -45, -3, -13, -33, -16, -5, 9, 3, 14, 24, -14, 12, 13, 7, 33, -21, -26, -15, 17, -21, -9],
            x: -0.2461,
            y: 0.6924,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/ba/73/b6/ba73b6d3-4c91-f42a-3c1d-b5f80dc0b1d1/00600753836583.rgb.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Générique",
            hook: "Dark Paris noir trumpet",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/1f/95/4e/1f954ed9-058d-3aae-9001-4eb5ca18fbe7/mzaf_18066099709055012290.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/g%C3%A9n%C3%A9rique-bof-ascenseur-pour-l%C3%A9chafaud/1389716930?i=1389717268&uo=4"
        ),
        RadioWork(
            workId: "mbid:e941c1ff-3620-50f4-8590-9df10c78eceb",
            title: "Time Moves Slow",
            creator: "BADBADNOTGOOD · Sam Herring",
            year: 2016,
            kind: "modern jazz · soul pocket",
            summary: "Dusty live-kit pocket, warm analog keys, and smoky jazz chord changes wired straight into modern hip-hop swing.",
            energy: 0.42,
            heaviness: 0.38,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-71, -58, -3, 7, 15, -1, -34, -3, 19, 15, -17, -3, 5, 12, -27, -26, -9, -1, 7, 4, 27, -9, -1, 9, -22, -40, 49, 3, -21, 1, 11, 11],
            x: 0.1208,
            y: 0.2934,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/cf/7a/c1/cf7ac163-867a-3d6a-6613-abb7d594aad0/196626360007.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Time Moves Slow",
            hook: "Hip-hop soul crossover",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/06/a8/65/06a86591-20cb-4c6e-ec2e-a88fee4e3838/mzaf_7792648677040532413.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/time-moves-slow/1608122086?i=1608122095&uo=4"
        ),
        RadioWork(
            workId: "mbid:912241ed-7bf9-5ab4-af62-b2eede1437ba",
            title: "Chameleon",
            creator: "Herbie Hancock",
            year: 1973,
            kind: "jazz funk · fusion",
            summary: "Rubber ARP Odyssey synth bassline and Clavinet pocket that laid the blueprint for West Coast funk and G-funk.",
            energy: 0.78,
            heaviness: 0.61,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-40, -34, 0, 40, -1, -1, -39, -33, -2, -5, 32, 5, 23, 25, -27, -16, 20, -11, -13, -1, 31, 18, 7, 8, 26, 35, 26, -24, 4, 15, 20, -16],
            x: 0.2164,
            y: 0.2984,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/4f/e5/f5/4fe5f511-462e-e87b-0711-d4e42809fb17/dj.goshfswo.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Chameleon",
            hook: "ARP Odyssey bassline",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/05/bc/d1/05bcd144-2db9-5e43-a4a9-1bd33cf7d169/mzaf_7915628022145635448.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/chameleon/158571524?i=158571527&uo=4"
        ),
        RadioWork(
            workId: "mbid:442026df-9ec1-5b41-a50a-c98b47617684",
            title: "Haitian Fight Song",
            creator: "Charles Mingus",
            year: 1957,
            kind: "post-bop · jazz groove",
            summary: "Furious bowed-and-plucked upright bass riff that erupts like an acoustic punk anthem.",
            energy: 0.74,
            heaviness: 0.66,
            streamUrl: nil,
            durationSec: nil,
            vec32: [-72, -41, 21, -11, 44, -7, -1, 20, 30, 39, 4, -20, 26, -25, 9, 11, 12, 5, -3, -13, 15, -8, -2, -17, -10, 18, 7, -11, -15, 41, 40, -48],
            x: -0.1922,
            y: -0.1876,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music/cc/01/b8/mzi.xxfrxghi.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Haitian Fight Song",
            hook: "Snarling upright bass",
            category: "jazz",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/4e/e6/98/4ee6980d-4d02-8e52-4870-e6eaffbaff49/mzaf_10479429169716073872.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/haitian-fight-song/298682127?i=298682128&uo=4"
        ),
        RadioWork(
            workId: "mbid:f4b1a3d0-52e1-5218-a4e1-2830a0b74211",
            title: "Acid Jazz (Extended Rhodes Mix)",
            creator: "Kevin MacLeod (CC BY)",
            year: 2014,
            kind: "acid jazz · hip-hop groove",
            summary: "Tight head-nodding breakbeat drums paired with warm Rhodes electric piano and punchy horn stabs.",
            energy: 0.62,
            heaviness: 0.44,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/26/Kevin_MacLeod_-_AcidJazz.ogg/Kevin_MacLeod_-_AcidJazz.ogg.mp3",
            durationSec: 218,
            vec32: [-63, -72, -5, 42, -15, -9, -33, -11, 21, 29, -9, -3, 3, 6, -13, 6, 11, -17, -16, -14, -24, -5, -18, 29, -22, -29, 38, -6, 10, -11, 2, 20],
            x: 0.4934,
            y: 0.2367,
            artUrl: nil,
            sourceLabel: "CC BY",
            shortTitle: "Acid Jazz",
            hook: "Breakbeat Rhodes pocket",
            category: "jazz",
            previewUrl: nil,
            appleMusicUrl: nil
        ),
        RadioWork(
            workId: "mbid:c314de09-6412-59f2-9214-b1721c22f902",
            title: "Night on the Docks (Sax Noir)",
            creator: "Kevin MacLeod (CC BY)",
            year: 2013,
            kind: "cool jazz · noir",
            summary: "Rainy midnight walking upright bass, brushed ride cymbal, and breathy tenor saxophone without clutter.",
            energy: 0.29,
            heaviness: 0.25,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/2d/Kevin_MacLeod_-_Night_on_the_Docks_-_Sax.ogg/Kevin_MacLeod_-_Night_on_the_Docks_-_Sax.ogg.mp3",
            durationSec: 206,
            vec32: [-79, -33, 2, 16, 31, -23, -21, -13, 11, -18, -34, -27, 6, 1, 3, -10, -6, -24, -24, 16, -15, 7, -17, -10, -4, -24, -37, -8, -3, 12, -14, 25],
            x: -0.2198,
            y: 0.5535,
            artUrl: nil,
            sourceLabel: "CC BY",
            shortTitle: "Night on the Docks",
            hook: "Smoky noir sax & bass",
            category: "jazz",
            previewUrl: nil,
            appleMusicUrl: nil
        ),
        RadioWork(
            workId: "mbid:92c48433-431b-52c5-ba0a-02cb4086a048",
            title: "The Planets, Op. 32: I. Mars, the Bringer of War",
            creator: "Gustav Holst · US Air Force Band (PD)",
            year: 1918,
            kind: "classical · orchestral thunder",
            summary: "Relentless asymmetric 5/4 ostinato and low brass stomp that directly birthed heavy film scoring and metal riffs.",
            energy: 0.89,
            heaviness: 0.92,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/54/Gustav_Holst_-_the_planets%2C_op._32_-_i._mars%2C_the_bringer_of_war.ogg/Gustav_Holst_-_the_planets%2C_op._32_-_i._mars%2C_the_bringer_of_war.ogg.mp3",
            durationSec: 452,
            vec32: [-64, -20, -4, -4, 53, 10, 33, 18, 12, 13, 1, -11, 0, 0, 1, 28, 37, 21, 0, -9, -4, 2, -26, 17, 19, 8, -14, 41, 3, 40, 32, -14],
            x: -0.4032,
            y: -0.287,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/17/23/56/17235601-0260-a78b-eff8-db1207a4e8a6/5065002170149.jpg/600x600bb.jpg",
            sourceLabel: "PD",
            shortTitle: "Mars (The Planets)",
            hook: "5/4 proto-metal stomp",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/8d/21/9b/8d219b62-b7bd-c177-0be3-c19687136dbe/mzaf_7571311820613072479.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/the-planets-suite-for-orchestra-h-125-op-32-jupiter/1599606481?i=1599607418&uo=4"
        ),
        RadioWork(
            workId: "mbid:20462048-c5fa-5ab4-8c39-08baa105ed0a",
            title: "Romeo and Juliet, Op. 64: Dance of the Knights",
            creator: "Sergei Prokofiev",
            year: 1938,
            kind: "classical · dark orchestral",
            summary: "Crushing low-string march and jagged brass stabs with sub-bass weight worthy of modern hip-hop production.",
            energy: 0.82,
            heaviness: 0.88,
            streamUrl: nil,
            durationSec: 330,
            vec32: [-76, -45, 10, 9, 64, 0, 14, 18, 23, 24, 0, -6, -4, -9, -29, 22, 44, -14, -5, 26, -19, 7, -25, 4, 5, 5, 22, -1, 13, 38, -11, 0],
            x: -0.3029,
            y: -0.1338,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6f/ff/30/6fff308b-e137-d064-4b66-d3ddb6e72f9f/mzi.fahflzui.tif/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Dance of the Knights",
            hook: "Menacing bass & brass",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/0e/90/92/0e909209-2713-8636-3e45-6309eb2707d4/mzaf_6051982219057076357.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/dance-of-the-knights/267058352?i=267058502&uo=4"
        ),
        RadioWork(
            workId: "mbid:9db35866-fbe8-5540-92a0-852c87a51e04",
            title: "Recomposed: Vivaldi Four Seasons – Spring 1",
            creator: "Max Richter",
            year: 2012,
            kind: "modern classical · post-minimalism",
            summary: "Baroque solo violin motifs rewired over subterranean modular synth sub-bass and hypnotic loop repetition.",
            energy: 0.64,
            heaviness: 0.41,
            streamUrl: nil,
            durationSec: 152,
            vec32: [-61, -34, -5, -7, 30, 59, 26, 28, -12, -25, 41, 22, 27, -22, 10, 20, -14, -4, 26, 2, 12, 7, -14, 5, 29, -10, 0, -6, -6, -5, 20, 15],
            x: -0.398,
            y: -0.7088,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/7b/53/8c/7b538c1b-8be0-baed-d664-b1e8e5c31aa3/22UMGIM10125.rgb.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Spring 1",
            hook: "Electronic Vivaldi pulse",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/51/68/ce/5168ce1a-c4f5-9749-34d5-03ce5ff02f65/mzaf_14901412187625388886.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/spring-1-2022/1613711918?i=1613711928&uo=4"
        ),
        RadioWork(
            workId: "mbid:ca34e1b0-9072-5ab4-b051-0b14239aa661",
            title: "The Four Seasons, Summer: Presto",
            creator: "Antonio Vivaldi · John Harrison (CC BY-SA)",
            year: 1725,
            kind: "classical · baroque shred",
            summary: "Relentless minor-key string storm and blazing sixteenth-note violin sweeps at pure punk tempo.",
            energy: 0.91,
            heaviness: 0.71,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/fa/Vivaldi_-_Four_Seasons_2_Summer_mvt_3_Presto_-_John_Harrison_violin.oga/Vivaldi_-_Four_Seasons_2_Summer_mvt_3_Presto_-_John_Harrison_violin.oga.mp3",
            durationSec: 168,
            vec32: [-64, -33, -2, -8, 50, 22, 10, 60, 19, 9, 22, 40, 25, -47, 18, 42, 7, 0, 33, -9, -26, -5, -9, -12, 6, 0, -16, 6, -21, 4, 10, -9],
            x: -0.4612,
            y: -0.86,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/d3/16/c8/d316c8bd-b6ac-8e94-8a7f-c75eceadcf61/00028947818892.rgb.jpg/600x600bb.jpg",
            sourceLabel: "CC BY-SA",
            shortTitle: "Summer: Presto",
            hook: "Baroque speed shred",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/2d/8d/6a/2d8d6a05-bdb2-fe03-1c1b-a414e07832fa/mzaf_5707626621297379594.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/summer/1440564488?i=1440564673&uo=4"
        ),
        RadioWork(
            workId: "mbid:ab2c5006-d203-582c-9e3a-04d9726449b5",
            title: "Koyaanisqatsi",
            creator: "Philip Glass",
            year: 1982,
            kind: "minimalism · synth-orchestral",
            summary: "Monolithic pipe-organ bass pedals and chanting arpeggios engineered like pure trance architecture.",
            energy: 0.72,
            heaviness: 0.79,
            streamUrl: nil,
            durationSec: 210,
            vec32: [-59, -37, -16, -7, -27, 2, 22, 4, -5, -8, 22, -31, -7, 13, 30, 2, 28, 41, 0, 24, 3, -3, 7, 11, 50, 3, 13, -2, 21, -56, -23, -38],
            x: 0.1121,
            y: -0.0804,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e8/90/83/e890834a-1a49-bd4a-dfa8-7390bff81e09/Koy.jpg/600x600bb.jpg",
            sourceLabel: nil,
            shortTitle: "Koyaanisqatsi",
            hook: "Hypnotic organ & drive",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/5d/c3/2d/5dc32dd2-e047-6868-827b-16a5b938c23a/mzaf_11522845028541496989.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/koyaanisqatsi/632828008?i=632828098&uo=4"
        ),
        RadioWork(
            workId: "mbid:1b9fd9b7-9ca2-5eb7-bed9-e5e447ecfb9b",
            title: "Gnossienne No. 1 (Lent)",
            creator: "Erik Satie · Public Domain",
            year: 1890,
            kind: "classical · nocturnal piano",
            summary: "Hypnotic minor-mode piano vamp with smoky chromatic ornaments that sounds ready-made for lo-fi beats.",
            energy: 0.21,
            heaviness: 0.29,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/91/Satie_-_Gnossienne_1.ogg/Satie_-_Gnossienne_1.ogg.mp3",
            durationSec: 218,
            vec32: [-54, -32, 9, -47, 33, 2, 15, 30, -42, -37, -41, -48, -18, 19, -2, 9, -12, -10, 23, 20, -7, 9, 16, -8, -15, -11, 21, 62, 23, 13, 0, 2],
            x: -0.6632,
            y: 0.2004,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/e2/bf/cb/e2bfcbdc-ff1f-965d-6b1b-b9cb8c56c479/cover.jpg/600x600bb.jpg",
            sourceLabel: "PD",
            shortTitle: "Gnossienne No. 1",
            hook: "Dark trip-hop loop",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/a7/51/61/a7516140-aa0b-71a1-1acd-3f02e48b5d78/mzaf_7843114211843587036.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/gnossienne-no-1/1667630289?i=1667630290&uo=4"
        ),
        RadioWork(
            workId: "mbid:9eaa00d3-48b8-5aff-8261-9a358ad3f8ad",
            title: "Night on Bald Mountain",
            creator: "Modest Mussorgsky · Skidmore Orchestra (PD)",
            year: 1867,
            kind: "classical · dramatic tone poem",
            summary: "Slashing string tremolo and thunderous brass fanfares erupting from subterranean gloom.",
            energy: 0.85,
            heaviness: 0.86,
            streamUrl: "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/ca/Modest_Mussorgsky_-_night_on_bald_mountain.ogg/Modest_Mussorgsky_-_night_on_bald_mountain.ogg.mp3",
            durationSec: 672,
            vec32: [-76, -14, -10, -32, 42, -14, 50, 20, -12, -4, -7, -5, -8, -12, 6, 19, 24, -18, -31, -6, -2, 7, -8, -4, -9, 0, -5, -33, 16, 15, -26, 18],
            x: -0.4662,
            y: -0.2069,
            artUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music7/v4/92/69/06/9269067e-0c22-849b-cb01-456619a1a9d8/099923082927.jpg/600x600bb.jpg",
            sourceLabel: "PD",
            shortTitle: "Night on Bald Mountain",
            hook: "Dark orchestral menace",
            category: "classical",
            previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/12/68/0e/12680e0a-fed7-3a1b-2693-2bdffca24d18/mzaf_10656720291966982391.plus.aac.p.m4a",
            appleMusicUrl: "https://music.apple.com/us/album/modest-mussorgsky-night-on-bald-mountain/1010057153?i=1010059860&uo=4"
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
                RadioLensAnchor(workId: "mbid:1b642322-7c90-4a8e-9b52-33f672941a64", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736", weight: 0.95, mark: "good"),
                RadioLensAnchor(workId: "mbid:28475649-0487-4258-e078-557685940378", weight: 0.88, mark: "good"),
                RadioLensAnchor(workId: "mbid:84031205-6043-4814-e634-113241506934", weight: 0.92, mark: "good")
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
                RadioLensAnchor(workId: "mbid:e317a495-2189-4138-8635-5a817c910421", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:a4298374-9201-438a-b829-174829104722", weight: 0.94, mark: "good"),
                RadioLensAnchor(workId: "mbid:51829304-1290-4a81-9f31-882910492811", weight: 0.91, mark: "good"),
                RadioLensAnchor(workId: "mbid:73920194-5932-4d03-9b23-002130495823", weight: 0.89, mark: "good")
            ],
            signatureValid: true
        ),
        RadioLens(
            id: "lens:radio:chamber-focus",
            domain: "radio",
            name: "Chamber focus",
            summary: "CC0 Goldberg counterpoint, solo cello suites, and modal jazz ballads",
            issuer: "ed25519:FTDs9aCjfVcsUDiZyq2SNyHaep2thFBDRSnNcLcmBfo",
            issuerHandle: "archive.curator",
            modelId: "embeddinggemma-2",
            subscribers: 184,
            completionRate: 0.92,
            anchors: [
                RadioLensAnchor(workId: "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:41b02769-8872-4a45-8754-2b79383c3614", weight: 0.95, mark: "good"),
                RadioLensAnchor(workId: "mbid:95142316-7154-4f25-bd45-224352617045", weight: 0.86, mark: "good"),
                RadioLensAnchor(workId: "mbid:06253427-8265-4036-ce56-335463728156", weight: 0.85, mark: "good")
            ],
            signatureValid: true
        ),
        RadioLens(
            id: "lens:radio:jazz-miles-orbit",
            domain: "radio",
            name: "Jazz, Miles orbit",
            summary: "Modal space, electric Rhodes groove, hip-hop horns, and smoky noir sax",
            issuer: "ed25519:82PCkbYGhiH595pnzwEKVxg-hBZGsURhGzvpRPwYfLQ",
            issuerHandle: "canon.steward",
            modelId: "embeddinggemma-2",
            subscribers: 412,
            completionRate: 0.95,
            anchors: [
                RadioLensAnchor(workId: "mbid:95142316-7154-4f25-bd45-224352617045", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:a21a9293-31f7-504c-9d9f-d4a4ec0bd6e2", weight: 0.96, mark: "good"),
                RadioLensAnchor(workId: "mbid:6cf409af-8afa-5d5b-bcd0-358795af40b4", weight: 0.92, mark: "good"),
                RadioLensAnchor(workId: "mbid:e941c1ff-3620-50f4-8590-9df10c78eceb", weight: 0.9, mark: "good"),
                RadioLensAnchor(workId: "mbid:912241ed-7bf9-5ab4-af62-b2eede1437ba", weight: 0.88, mark: "good")
            ],
            signatureValid: true
        ),
        RadioLens(
            id: "lens:radio:classical-heavy",
            domain: "radio",
            name: "Classical, no fluff",
            summary: "5/4 orchestral thunder, Prokofiev bass menace, and synth-classical drive",
            issuer: "ed25519:82PCkbYGhiH595pnzwEKVxg-hBZGsURhGzvpRPwYfLQ",
            issuerHandle: "canon.steward",
            modelId: "embeddinggemma-2",
            subscribers: 356,
            completionRate: 0.93,
            anchors: [
                RadioLensAnchor(workId: "mbid:92c48433-431b-52c5-ba0a-02cb4086a048", weight: 1.0, mark: "good"),
                RadioLensAnchor(workId: "mbid:20462048-c5fa-5ab4-8c39-08baa105ed0a", weight: 0.96, mark: "good"),
                RadioLensAnchor(workId: "mbid:9db35866-fbe8-5540-92a0-852c87a51e04", weight: 0.92, mark: "good"),
                RadioLensAnchor(workId: "mbid:ab2c5006-d203-582c-9e3a-04d9726449b5", weight: 0.9, mark: "good"),
                RadioLensAnchor(workId: "mbid:1b9fd9b7-9ca2-5eb7-bed9-e5e447ecfb9b", weight: 0.88, mark: "good")
            ],
            signatureValid: true
        )
    ]
}
