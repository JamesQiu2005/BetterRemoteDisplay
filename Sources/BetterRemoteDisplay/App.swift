import AppKit
import BRDShared
import SwiftUI

@main
struct BetterRemoteDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = ConfigStore()
    @State private var helper = HelperConnection()
    @State private var displays = DisplayEnvironment()

    var body: some Scene {
        Window("BetterRemoteDisplay", id: "settings") {
            SettingsView()
                .environment(store)
                .environment(helper)
                .environment(displays)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The settings window is only a portal; the helper keeps running without it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
