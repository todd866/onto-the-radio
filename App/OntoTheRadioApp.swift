import SwiftUI

@main
struct OntoTheRadioApp: App {
    @State private var engine = RadioEngine()

    var body: some Scene {
        WindowGroup {
            RadioScreen(engine: engine)
                #if os(macOS)
                .frame(minWidth: 440, idealWidth: 920, minHeight: 580, idealHeight: 680)
                #endif
        }
    }
}
