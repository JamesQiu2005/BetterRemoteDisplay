import AppKit
import Observation

/// Whether this Mac has a real display attached. The app only acts on a headless Mac: with a
/// monitor (or an open laptop lid) present, it stays out of the way.
@MainActor
@Observable
public final class DisplayEnvironment {
    /// Vendor ID of the virtual display this app creates.
    public static let ownVendorID: UInt32 = 0xB2D0
    /// 'unkn': what macOS reports for a display with no EDID, such as the placeholder it
    /// invents for a headless Mac. Real panels and monitors always carry a vendor.
    private static let unknownVendorID: UInt32 = 0x756E_6B6E

    public private(set) var hasRealDisplay = DisplayEnvironment.detectRealDisplay()

    public init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hasRealDisplay = Self.detectRealDisplay() }
        }
    }

    public static func detectRealDisplay() -> Bool {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.prefix(Int(count)).contains { id in
            let vendor = CGDisplayVendorNumber(id)
            return vendor != ownVendorID && vendor != unknownVendorID
        }
    }
}
