import AppKit
import BRDShared
import Observation
import ServiceManagement

/// The settings app's view of the helper process: is it running, and does it start at login.
@MainActor
@Observable
final class HelperConnection {
    private(set) var isRunning = false
    private(set) var startsAtLogin = false
    private(set) var lastError: String?

    @ObservationIgnored private let loginItem = SMAppService.loginItem(identifier: BRD.helperID)

    private var helperURL: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Library/LoginItems/\(BRD.helperBundleName)")
    }

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == BRD.helperID else { return }
                let launched = note.name == NSWorkspace.didLaunchApplicationNotification
                MainActor.assumeIsolated { self?.isRunning = launched }
            }
        }
        refresh()
    }

    func refresh() {
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: BRD.helperID).isEmpty
        startsAtLogin = loginItem.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            setStartsAtLogin(true)
            launch()
        } else {
            setStartsAtLogin(false)
            BRD.post(BRD.quitHelper)
        }
    }

    func setStartsAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if loginItem.status != .enabled { try loginItem.register() }
            } else if loginItem.status == .enabled {
                try loginItem.unregister()
            }
        } catch {
            lastError = "Couldn’t change the login item: \(error.localizedDescription)"
        }
        startsAtLogin = loginItem.status == .enabled
    }

    private func launch() {
        guard !isRunning else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error { self?.lastError = "Couldn’t start the helper: \(error.localizedDescription)" }
                self?.refresh()
            }
        }
    }
}
