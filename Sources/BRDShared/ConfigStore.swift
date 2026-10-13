import Foundation
import Observation

public enum BRD {
    public static let appID = "com.hanzeqiu.BetterRemoteDisplay"
    public static let helperID = "com.hanzeqiu.BetterRemoteDisplay.Helper"
    public static let helperBundleName = "BetterRemoteDisplay Helper.app"

    public static let configChanged = Notification.Name("\(appID).configChanged")
    public static let quitHelper = Notification.Name("\(appID).quitHelper")

    /// Shared container for the sandboxed (App Store) build, where the app and the helper
    /// otherwise can't see each other's files. Prefixed with the signing team ID.
    public static let appGroup = "29ZMSYHTLL.com.hanzeqiu.BetterRemoteDisplay"

    public static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    public static var supportDirectory: URL {
        let base = isSandboxed
            ? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            : nil
        let dir = (base ?? URL.applicationSupportDirectory)
            .appending(path: "BetterRemoteDisplay", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func post(_ name: Notification.Name) {
        DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

/// The shared config file. Both the helper and the settings app hold one of these;
/// a distributed notification tells the other side to re-read after a write.
@MainActor
@Observable
public final class ConfigStore {
    public private(set) var config: Config

    /// Called after the config changes, locally or from the other process.
    @ObservationIgnored public var onChange: (() -> Void)?

    @ObservationIgnored private let url = BRD.supportDirectory.appending(path: "config.json")
    @ObservationIgnored private var observer: NSObjectProtocol?

    public init() {
        config = Config()
        config = load()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: BRD.configChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    public func update(_ body: (inout Config) -> Void) {
        var next = config
        body(&next)
        guard next != config else { return }
        config = next
        save()
        BRD.post(BRD.configChanged)
        onChange?()
    }

    private func reload() {
        let next = load()
        guard next != config else { return }
        config = next
        onChange?()
    }

    private func load() -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return config
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
