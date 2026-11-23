import SwiftUI

@main
struct OntoTheRadioApp: App {
    @State private var engine = RadioEngine()

    var body: some Scene {
        WindowGroup {
            RadioScreen(engine: engine)
                #if os(macOS)
                .frame(minWidth: 460, idealWidth: 520, minHeight: 560, idealHeight: 620)
                #endif
        }
    }
}
