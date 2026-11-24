import SwiftUI
import UIKit
import XCTest
@testable import OntoTheRadio

final class OntoTheRadioTests: XCTestCase {
    func testCosineAndLensRankingPrioritizePlayableAnchors() {
        let tracks = ManifoldRadioClient.bundledWorks
        let chamber = ManifoldRadioClient.bundledLenses.first { $0.id == "lens:radio:chamber-focus" }
        XCTAssertNotNil(chamber)

        let ranked = RadioMath.rankTracks(
            tracks: tracks,
            lens: chamber,
            maxEnergy: 1.0,
            maxHeaviness: 1.0
        )
        XCTAssertEqual(ranked.count, tracks.count)
        XCTAssertEqual(ranked.first?.work.workId, "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31")
        XCTAssertGreaterThan(ranked.first?.score ?? 0, 0.95)
    }

    func testEnergyCapFiltersHighEnergyItemsWhenLowerTracksExist() {
        let tracks = ManifoldRadioClient.bundledWorks
        let calm = RadioMath.rankTracks(
            tracks: tracks,
            lens: ManifoldRadioClient.bundledLenses.first,
            maxEnergy: 0.20,
            maxHeaviness: 0.20
        )
        XCTAssertEqual(calm.count, 2)
        XCTAssertFalse(calm.contains { $0.work.workId == "mbid:41b02769-8872-4a45-8754-2b79383c3614" })
    }

    func testBundledStreamsUseVerifiedNonBrokenWikimediaMP3URLs() {
        XCTAssertGreaterThanOrEqual(ManifoldRadioClient.bundledWorks.count, 15)
        for work in ManifoldRadioClient.bundledWorks {
            XCTAssertTrue(work.isPlayable, "Bundled work must be playable: \(work.title)")
            if let url = work.streamUrl, !url.isEmpty {
                XCTAssertTrue(url.hasPrefix("https://"))
                XCTAssertTrue(url.hasSuffix(".mp3"))
                XCTAssertFalse(url.contains("/9/98/Gymnopedie_No_1.ogg"))
                XCTAssertFalse(url.contains("_Goldberg_Variations%2C_BWV_988_-_01_Aria.flac"))
                XCTAssertFalse(url.contains("/4/47/BWV_1007_-_Prelude.ogg"))
            }
            if let preview = work.previewUrl, !preview.isEmpty {
                XCTAssertTrue(preview.hasPrefix("https://"))
            }
            XCTAssertFalse((work.shortTitle ?? "").isEmpty, "Missing shortTitle for \(work.title)")
            XCTAssertFalse((work.hook ?? "").isEmpty, "Missing hook for \(work.title)")
            XCTAssertFalse((work.shortTitle ?? "").contains("..."))
            XCTAssertFalse((work.shortTitle ?? "").contains("…"))
            XCTAssertNotNil(work.x)
            XCTAssertNotNil(work.y)
        }
    }

    @MainActor
    func testSkipNextOnlyAdvancesPlayableWorksAndTasteSteersQueue() throws {
        let suiteName = "com.iantodd.ontotheradio.test.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = RadioEngine(defaults: suite)
        // Inject an unplayable reference-pool work with extreme score
        let unplayable = RadioWork(
            workId: "mbid:unplayable-ref",
            title: "Reference Track",
            creator: "Ref Artist",
            year: 1994,
            kind: "electronic",
            summary: "Coords only",
            energy: 0.2,
            heaviness: 0.1,
            streamUrl: nil,
            vec32: [48, -22, 27, 9, -14, 29, 18, -8, 11, 22, -4, 16, 5, -7, 12, 8],
            x: 0.4,
            y: -0.1
        )
        engine.works = ManifoldRadioClient.bundledWorks + [unplayable]
        XCTAssertTrue(engine.discoveryWorks.contains { $0.work.workId == unplayable.workId })
        XCTAssertFalse(engine.playableQueue.contains { $0.work.workId == unplayable.workId })

        for _ in 0..<(engine.playableQueue.count + 2) {
            engine.skipNext()
            XCTAssertTrue(engine.currentWork?.isPlayable ?? false)
            XCTAssertNotEqual(engine.currentWork?.workId, unplayable.workId)
        }

        let targetTrack = try XCTUnwrap(engine.playableQueue.last?.work)
        engine.toggleLike(targetTrack)
        XCTAssertTrue(engine.likedIDs.contains(targetTrack.workId))

        engine.tuneToMap(x: -0.6284, y: 0.4621)
        XCTAssertEqual(engine.currentWork?.workId, "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736")
        engine.tuneToMap(x: 0.4934, y: 0.2367)
        XCTAssertEqual(engine.currentWork?.workId, "mbid:f4b1a3d0-52e1-5218-a4e1-2830a0b74211")

        engine.selectMood(.chill)
        XCTAssertEqual(engine.moodPreset, .chill)
        engine.selectMood(.chill)
        XCTAssertEqual(engine.moodPreset, .all)

        engine.activeTab = .map
        XCTAssertEqual(engine.activeTab, .map)
        engine.activeTab = .library
        XCTAssertEqual(engine.activeTab, .library)
    }

    func testAITitleFitterProducesZeroEllipsesAndFitsBudget() {
        let samples = [
            ("Goldberg Variations, BWV 988: Aria", 19),
            ("The Planets, Op. 32: I. Mars, the Bringer of War", 19),
            ("Romeo and Juliet, Op. 64: Dance of the Knights", 22),
            ("Générique (Ascenseur pour l'échafaud)", 19),
            ("Cello Suite No. 1 in G Major, Prelude", 19),
            ("Recomposed: Vivaldi Four Seasons – Spring 1 - Remastered", 24),
            ("Gymnopédie No. 1 (Lent et douloureux)", 19),
        ]
        for (raw, budget) in samples {
            let fitted = AITitleFitter.heuristicFit(raw, maxChars: budget)
            XCTAssertFalse(fitted.isEmpty, "Empty fitted result for \(raw)")
            XCTAssertLessThanOrEqual(fitted.count, budget, "Exceeded budget for \(raw) -> \(fitted)")
            XCTAssertFalse(fitted.contains("..."), "Ellipsis in fitted title: \(fitted)")
            XCTAssertFalse(fitted.contains("…"), "Unicode ellipsis in fitted title: \(fitted)")
        }

        let subtitleSamples: [(String, String?, Int)] = [
            ("Johann Sebastian Bach · Kimiko Ishizaka (CC0)", "Crisp solo keyboard", 34),
            ("Modest Mussorgsky", "Dark orchestral menace", 34),
            ("Miles Davis", "Electric Rhodes trance", 34),
            ("Antonio Vivaldi", "Baroque speed shred", 22),
        ]
        for (creator, hook, budget) in subtitleSamples {
            let sub = AITitleFitter.compactSubtitle(creator: creator, hook: hook, maxChars: budget)
            XCTAssertFalse(sub.isEmpty)
            XCTAssertLessThanOrEqual(sub.count, budget, "Subtitle exceeded budget: \(sub)")
            XCTAssertFalse(sub.contains("..."))
            XCTAssertFalse(sub.contains("…"))
        }
    }

    @MainActor
    func testJazzAndClassicalGatewayShelvesPopulatedAndPlayable() {
        let suiteName = "com.iantodd.ontotheradio.gateway.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = RadioEngine(defaults: suite)
        XCTAssertFalse(engine.jazzPicks.isEmpty)
        XCTAssertFalse(engine.classicalPicks.isEmpty)
        XCTAssertTrue(engine.jazzPicks.contains(where: { $0.creator.localizedCaseInsensitiveContains("Miles Davis") }))
        XCTAssertTrue(engine.classicalPicks.contains(where: { $0.title.localizedCaseInsensitiveContains("Mars") }))
        XCTAssertTrue(engine.jazzPicks.contains(where: \.isPlayable))
        XCTAssertTrue(engine.classicalPicks.contains(where: \.isPlayable))
        XCTAssertTrue(engine.allLenses.contains(where: { $0.id == "lens:radio:jazz-miles-orbit" }))
        XCTAssertTrue(engine.allLenses.contains(where: { $0.id == "lens:radio:classical-heavy" }))

        for work in engine.jazzPicks + engine.classicalPicks {
            let fitted = engine.fittedTitle(for: work, maxChars: 19)
            XCTAssertLessThanOrEqual(fitted.count, 19, "Shelf title too long: \(fitted)")
            XCTAssertFalse(fitted.contains("..."))
            XCTAssertFalse(fitted.contains("…"))
        }
    }

    @MainActor
    func testHeadlessRenderHomeAndNowPlayingLightAndDark() throws {
        let suiteName = "com.iantodd.ontotheradio.render.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = RadioEngine(defaults: suite)
        engine.elapsedSec = 42
        engine.durationSec = 189
        engine.contributors = [
            ContributorReputation(
                issuer: "ed25519:steward",
                handle: "canon.steward",
                tier: "steward",
                trust: 0.986,
                verifiedVectors: 48,
                meanCanaryCosine: 0.996,
                credits: 620
            )
        ]

        XCTAssertEqual(engine.hubURL, "https://manifold-chi.vercel.app")
        XCTAssertFalse(engine.playableQueue.isEmpty)
        XCTAssertNotNil(engine.currentWork)

        let size = CGSize(width: 390, height: 844)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let scheme: ColorScheme = style == .dark ? .dark : .light
            let tag = style == .dark ? "dark" : "light"

            try renderPNG(
                view: RadioScreen(engine: engine).environment(\.colorScheme, scheme),
                style: style,
                size: size,
                to: "/tmp/ontotheradio-home-\(tag).png"
            )
            try renderPNG(
                view: NowPlayingView(engine: engine).environment(\.colorScheme, scheme),
                style: style,
                size: size,
                to: "/tmp/ontotheradio-np-\(tag).png"
            )
        }
    }

    @MainActor
    private func renderPNG<V: View>(view: V, style: UIUserInterfaceStyle, size: CGSize, to path: String) throws {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = style
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let png = try XCTUnwrap(img.pngData())
        try png.write(to: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(png.count, 10_000)
    }

    func testGlancebarNowStateDecodingPlayingPausedStopped() throws {
        let playingJSON = """
        {"state":"playing","title":"So What","artist":"Miles Davis","liked":true,"host":"studio-mac","epoch":1732400000.5}
        """.data(using: .utf8)!
        let playing = try JSONDecoder().decode(GlancebarNowState.self, from: playingJSON)
        XCTAssertEqual(playing.state, "playing")
        XCTAssertEqual(playing.title, "So What")
        XCTAssertEqual(playing.artist, "Miles Davis")
        XCTAssertEqual(playing.liked, true)
        XCTAssertEqual(playing.host, "studio-mac")
        XCTAssertEqual(playing.epoch, 1732400000.5)

        let pausedJSON = """
        {"state":"paused","title":"Gymnopédie No. 1","artist":"Erik Satie","liked":false,"host":"studio-mac","epoch":1732400010}
        """.data(using: .utf8)!
        let paused = try JSONDecoder().decode(GlancebarNowState.self, from: pausedJSON)
        XCTAssertEqual(paused.state, "paused")
        XCTAssertEqual(paused.title, "Gymnopédie No. 1")
        XCTAssertEqual(paused.artist, "Erik Satie")
        XCTAssertEqual(paused.liked, false)
        XCTAssertEqual(paused.epoch, 1732400010.0)

        let stoppedJSON = """
        {"state":"stopped"}
        """.data(using: .utf8)!
        let stopped = try JSONDecoder().decode(GlancebarNowState.self, from: stoppedJSON)
        XCTAssertEqual(stopped.state, "stopped")
        XCTAssertNil(stopped.title)
        XCTAssertNil(stopped.artist)
        XCTAssertNil(stopped.liked)
        XCTAssertNil(stopped.host)
        XCTAssertNil(stopped.epoch)
    }

    func testHomeRadioClientGlancebarFetchAndCommandAndErrors() async throws {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockGlancebarURLProtocol.self]
        let session = URLSession(configuration: cfg)

        MockGlancebarURLProtocol.handler = { req in
            let url = try XCTUnwrap(req.url)
            if url.path == "/api/glancebar/now" {
                let body = #"{"state":"playing","title":"Blue in Green","artist":"Miles Davis","liked":false,"host":"studio-mac","epoch":1234}"#
                    .data(using: .utf8)!
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            if url.path == "/api/glancebar/cmd" {
                let body = #"{"ok":true,"now":{"state":"paused","title":"Blue in Green","artist":"Miles Davis","liked":true,"host":"studio-mac","epoch":1235}}"#
                    .data(using: .utf8)!
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let now = try await HomeRadioClient.fetchGlancebarNow(baseURL: "https://mock.example.com", session: session)
        XCTAssertEqual(now.state, "playing")
        XCTAssertEqual(now.title, "Blue in Green")
        XCTAssertEqual(now.liked, false)

        let updated = try await HomeRadioClient.sendGlancebarCommand(baseURL: "https://mock.example.com", cmd: "like", session: session)
        XCTAssertEqual(updated?.state, "paused")
        XCTAssertEqual(updated?.liked, true)

        MockGlancebarURLProtocol.handler = { req in
            let url = try XCTUnwrap(req.url)
            return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await HomeRadioClient.fetchGlancebarNow(baseURL: "https://mock.example.com", session: session)
            XCTFail("Expected unauthorized")
        } catch let err as HomeRadioError {
            if case .unauthorized = err {} else { XCTFail("Expected .unauthorized, got \(err)") }
        }

        MockGlancebarURLProtocol.handler = { req in
            let url = try XCTUnwrap(req.url)
            return (HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await HomeRadioClient.sendGlancebarCommand(baseURL: "https://mock.example.com", cmd: "toggle", session: session)
            XCTFail("Expected serverError")
        } catch let err as HomeRadioError {
            if case .serverError(let code) = err {
                XCTAssertEqual(code, 503)
            } else {
                XCTFail("Expected .serverError, got \(err)")
            }
        }
    }

    @MainActor
    func testRadioEngineGlancebarControlPausesLocalPlayerAndResetsOnDisconnect() throws {
        let suiteName = "com.iantodd.ontotheradio.glancebar.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = RadioEngine(defaults: suite)
        let firstWork = try XCTUnwrap(engine.playableQueue.first?.work)
        engine.play(firstWork, autoStart: true)
        XCTAssertTrue(engine.isPlaying)

        engine.homeServerURL = "https://mock.example.com"
        engine.homeServerConnected = true
        engine.homeServerStatus = "Connected · 1 tracks"
        engine.glancebarAvailable = true
        engine.glancebarNow = GlancebarNowState(
            state: "playing",
            title: "Goldberg Variations, BWV 988: Aria",
            artist: "Johann Sebastian Bach",
            liked: true,
            host: "studio-mac",
            epoch: 1732400000
        )

        engine.controlGlancebar = true
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.player.rate, 0)
        XCTAssertTrue(engine.isControllingGlancebar)

        let fitted = AITitleFitter.heuristicFit(engine.glancebarRawTitle, maxChars: 20)
        XCTAssertLessThanOrEqual(fitted.count, 20)
        XCTAssertFalse(fitted.contains("..."))
        XCTAssertFalse(fitted.contains("…"))

        // Render Glancebar mode in Light & Dark cleanly
        let size = CGSize(width: 390, height: 844)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let scheme: ColorScheme = style == .dark ? .dark : .light
            let tag = style == .dark ? "dark" : "light"
            try renderPNG(
                view: RadioScreen(engine: engine).environment(\.colorScheme, scheme),
                style: style,
                size: size,
                to: "/tmp/ontotheradio-glancebar-home-\(tag).png"
            )
            try renderPNG(
                view: NowPlayingView(engine: engine).environment(\.colorScheme, scheme),
                style: style,
                size: size,
                to: "/tmp/ontotheradio-glancebar-np-\(tag).png"
            )
        }

        // Toggle off and back on via toggleGlancebarControl()
        engine.toggleGlancebarControl()
        XCTAssertFalse(engine.controlGlancebar)
        engine.play(firstWork, autoStart: true)
        XCTAssertTrue(engine.isPlaying)
        engine.homeServerURL = "" // ensure toggle doesn't hit network
        engine.toggleGlancebarControl()
        XCTAssertTrue(engine.controlGlancebar)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.player.rate, 0)

        // Disconnect resets all Glancebar and home-server state cleanly
        engine.disconnectHomeServer()
        XCTAssertFalse(engine.homeServerConnected)
        XCTAssertFalse(engine.glancebarAvailable)
        XCTAssertFalse(engine.controlGlancebar)
        XCTAssertNil(engine.glancebarNow)
        XCTAssertTrue(engine.homeWorks.isEmpty)
        XCTAssertTrue(engine.homeStations.isEmpty)
        XCTAssertEqual(engine.homeServerStatus, "Local + Manifold CC0")
    }

    func testResolveDefaultHomeServerValidation() {
        XCTAssertEqual(RadioEngine.resolveDefaultHomeServer("https://radio.example.com:8447/"), "https://radio.example.com:8447")
        XCTAssertEqual(RadioEngine.resolveDefaultHomeServer("  http://localhost:8787  "), "http://localhost:8787")
        XCTAssertEqual(RadioEngine.resolveDefaultHomeServer(""), "")
        XCTAssertEqual(RadioEngine.resolveDefaultHomeServer("$(OTR_DEFAULT_HOME_SERVER)"), "")
        XCTAssertEqual(RadioEngine.resolveDefaultHomeServer("ftp://radio.example.com"), "")
    }

    @MainActor
    func testPasswordlessHomeConnectPromotesFirstTrackAndDisconnectPersists() async throws {
        let suiteName = "com.iantodd.ontotheradio.autoconnect.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockGlancebarURLProtocol.self]
        let session = URLSession(configuration: cfg)

        MockGlancebarURLProtocol.handler = { req in
            let url = try XCTUnwrap(req.url)
            if url.path == "/api/home" {
                let body = """
                {
                  "shelves": [
                    {
                      "id": "library",
                      "title": "Glancebar Lossless",
                      "tiles": [
                        {"kind":"song","s":"abc123","title":"Home Track","sub":"Home Artist · Album (2025)","artist":"Home Artist","art":true,"color":"#0ea5e9"}
                      ]
                    },
                    {
                      "id": "stations",
                      "title": "Stations",
                      "tiles": [
                        {"kind":"station","title":"Dance","sub":"12 tracks","color":"#e11d48","station":{"id":"dance","name":"Dance","color":"#e11d48","count":12}}
                      ]
                    }
                  ]
                }
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            if url.path == "/api/glancebar/now" {
                let body = #"{"state":"playing","title":"Blue Monday","artist":"New Order","liked":true,"host":"Mac","epoch":1732400100}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let engine = RadioEngine(defaults: suite, homeSession: session)
        engine.homeServerURL = "https://mock.example.com"
        await engine.refreshHomeLibrary()

        XCTAssertTrue(engine.homeServerConnected)
        XCTAssertEqual(engine.homeWorks.count, 1)
        XCTAssertEqual(engine.currentWork?.workId, "home:abc123")
        XCTAssertEqual(engine.selectedLensID, "home-station:dance")
        XCTAssertTrue(engine.glancebarAvailable)
        XCTAssertEqual(engine.glancebarRawTitle, "Blue Monday")

        engine.disconnectHomeServer()
        XCTAssertEqual(engine.homeServerURL, "")
        let reloaded = RadioEngine(defaults: suite, homeSession: session)
        XCTAssertEqual(reloaded.homeServerURL, "")
    }
}

private final class MockGlancebarURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (resp, data) = try handler(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
