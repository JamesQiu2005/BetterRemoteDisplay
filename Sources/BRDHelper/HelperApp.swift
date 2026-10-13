import AppKit
import BRDShared
import SwiftUI

@main
struct HelperApp: App {
    @State private var model: HelperModel

    init() {
        Self.exitIfAlreadyRunning()
        _model = State(initialValue: HelperModel.shared)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(model)
        } label: {
            Image(nsImage: MenuBarIcon.image(active: model.isActive))
                .accessibilityLabel("BetterRemoteDisplay")
        }
        .menuBarExtraStyle(.window)
    }

    /// Login items and the settings app can both try to start us; only one may own the display.
    private static func exitIfAlreadyRunning() {
        let path = BRD.supportDirectory.appending(path: "helper.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        // The lock is held for the life of the process.
        if fd < 0 || flock(fd, LOCK_EX | LOCK_NB) != 0 { exit(0) }
    }
}
