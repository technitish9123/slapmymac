import SwiftUI
import AppKit

@main
struct SlapMyMacApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("SlapMyMac", systemImage: "hand.raised.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
