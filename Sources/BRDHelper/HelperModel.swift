import AppKit
import BRDShared
import Observation

/// Keeps the virtual display in step with the shared config.
@MainActor
@Observable
final class HelperModel {
    static let shared = HelperModel()

    let store = ConfigStore()
    /// False when the display should exist but could not be created.
    private(set) var isHealthy = true
    /// What macOS is really showing. Differs from the config when it rejects a size as too small.
    private(set) var actualSize: DisplaySize?

    @ObservationIgnored private let controller = VirtualDisplayController()

    private init() {
        store.onChange = { [weak self] in self?.sync() }
        controller.onResolved = { [weak self] in self?.actualSize = $0 }
        controller.onTerminated = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.sync() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync() }
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: BRD.quitHelper, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.controller.teardown()
                NSApp.terminate(nil)
            }
        }
        sync()
    }

    var config: Config { store.config }

    func sync() {
        if config.enabled {
            isHealthy = controller.apply(size: config.size, hiDPI: config.hiDPI)
        } else {
            controller.teardown()
            isHealthy = true
        }
        if !controller.isActive { actualSize = nil }
    }

    /// The size macOS fell back to, when it refused the requested one.
    var fallbackSize: DisplaySize? {
        guard config.enabled, let actualSize, actualSize != config.size else { return nil }
        return actualSize
    }

    func select(_ preset: DisplayPreset) {
        store.update {
            // Keep the orientation the user is currently in.
            $0.size = $0.size.isPortrait == preset.size.isPortrait ? preset.size : preset.size.rotated
            $0.enabled = true
        }
    }

    func rotate() {
        store.update { $0.size = $0.size.rotated }
    }

    func openSettings() {
        // Helper lives at <App>.app/Contents/Library/LoginItems/<Helper>.app
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app" else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
