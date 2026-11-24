import SwiftUI
#if os(iOS)
import UIKit

final class RadioAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            RadioQuickActionRouter.dispatch(shortcut.type)
        }
        let cfg = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        cfg.delegateClass = RadioSceneDelegate.self
        return cfg
    }
}

final class RadioSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        RadioQuickActionRouter.dispatch(shortcutItem.type)
        completionHandler(true)
    }
}
#endif

@main
struct OntoTheRadioApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(RadioAppDelegate.self) private var appDelegate
    #endif
    @State private var engine = RadioEngine()

    var body: some Scene {
        WindowGroup {
            RadioScreen(engine: engine)
                #if os(macOS)
                .frame(minWidth: 440, idealWidth: 920, minHeight: 580, idealHeight: 680)
                #endif
        }
        #if os(macOS)
        .commands {
            CommandMenu("Playback") {
                Button(engine.isPlaying ? "Pause" : "Play") {
                    engine.togglePlay()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Next Track") {
                    engine.skipNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Previous Track") {
                    engine.skipPrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
        #endif
    }
}
