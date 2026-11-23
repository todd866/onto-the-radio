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
            maxEnergy: 0.9,
            maxHeaviness: 0.9
        )
        XCTAssertEqual(ranked.count, tracks.count)
        // Goldberg Variations is the 1.0 weight anchor for Chamber focus
        XCTAssertEqual(ranked.first?.work.workId, "mbid:7f5c1a38-44d3-4259-9a81-16f17eb8bc31")
        XCTAssertGreaterThan(ranked.first?.score ?? 0, 0.95)
    }

    func testEnergyCapFiltersHighEnergyItemsWhenLowerTracksExist() {
        let tracks = ManifoldRadioClient.bundledWorks
        // Cello Suite has energy 0.34; capping at 0.20 keeps Gymnopédie (0.12) and Clair de Lune (0.18)
        let calm = RadioMath.rankTracks(
            tracks: tracks,
            lens: ManifoldRadioClient.bundledLenses.first,
            maxEnergy: 0.20,
            maxHeaviness: 0.20
        )
        XCTAssertEqual(calm.count, 2)
        XCTAssertFalse(calm.contains { $0.work.workId == "mbid:41b02769-8872-4a45-8754-2b79383c3614" })
    }

    @MainActor
    func testRadioEngineInitializesCleanlyInSilentModeAndRendersLightAndDark() throws {
        let suiteName = "com.iantodd.ontotheradio.test.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = RadioEngine(defaults: suite)
        XCTAssertEqual(engine.hubURL, "https://manifold-chi.vercel.app")
        XCTAssertFalse(engine.rankedQueue.isEmpty)
        XCTAssertNotNil(engine.currentWork)

        for style: UIUserInterfaceStyle in [.light, .dark] {
            let scheme: ColorScheme = style == .dark ? .dark : .light
            let controller = UIHostingController(rootView: RadioScreen(engine: engine).environment(\.colorScheme, scheme))
            controller.overrideUserInterfaceStyle = style
            let size = CGSize(width: 390, height: 844)
            controller.view.bounds = CGRect(origin: .zero, size: size)
            controller.view.frame = CGRect(origin: .zero, size: size)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.overrideUserInterfaceStyle = style
            window.rootViewController = controller
            window.isHidden = false
            window.layoutIfNeeded()
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 2
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let png = try XCTUnwrap(img.pngData())
            let tag = style == .dark ? "dark" : "light"
            let outURL = URL(fileURLWithPath: "/tmp/ontotheradio-\(tag).png")
            try png.write(to: outURL)
            XCTAssertGreaterThan(png.count, 10_000)
        }
    }
}
