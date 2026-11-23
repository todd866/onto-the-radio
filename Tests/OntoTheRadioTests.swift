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
}
