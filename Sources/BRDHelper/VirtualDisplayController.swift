import AppKit
import BRDShared
import CGVirtualDisplayPrivate

/// Owns the one virtual display. While it exists, a headless Mac uses it in place of
/// the system's fallback display, so its resolution is what the remote session sees.
@MainActor
final class VirtualDisplayController {
    private var display: CGVirtualDisplay?
    private var applied: (size: DisplaySize, hiDPI: Bool)?

    /// Called when the system tears the display down behind our back.
    var onTerminated: (() -> Void)?
    /// Called shortly after a change with the resolution macOS actually settled on.
    var onResolved: ((DisplaySize) -> Void)?

    var isActive: Bool { display != nil }

    @discardableResult
    func apply(size: DisplaySize, hiDPI: Bool) -> Bool {
        let hiDPI = hiDPI && size.supportsHiDPI
        if let applied, applied.size == size, applied.hiDPI == hiDPI,
           let display, CGDisplayIsOnline(display.displayID) != 0 {
            return true
        }
        guard size.isValid, let display = display ?? makeDisplay(for: size) else { return false }

        // Resizing in place keeps the display ID, so windows stay where they are.
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = hiDPI ? 1 : 0
        settings.modes = [CGVirtualDisplayMode(width: UInt(size.width), height: UInt(size.height), refreshRate: 60)]
        guard display.apply(settings) else {
            NSLog("BetterRemoteDisplay: applySettings failed for %@", size.label)
            teardown()
            return false
        }
        self.display = display
        applied = (size, hiDPI)

        let id = display.displayID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.display?.displayID == id else { return }
            self.selectMode(on: id, size: size, hiDPI: hiDPI)
            if let mode = CGDisplayCopyDisplayMode(id) {
                self.onResolved?(DisplaySize(mode.width, mode.height))
            }
        }
        return true
    }

    func teardown() {
        display = nil
        applied = nil
    }

    private func makeDisplay(for size: DisplaySize) -> CGVirtualDisplay? {
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.queue = .main
        descriptor.name = "Remote Display"
        descriptor.maxPixelsWide = UInt32(DisplaySize.maxPixels)
        descriptor.maxPixelsHigh = UInt32(DisplaySize.maxPixels)
        // Nominal physical size at ~110 points per inch.
        descriptor.sizeInMillimeters = CGSize(width: Double(size.width) / 110 * 25.4,
                                              height: Double(size.height) / 110 * 25.4)
        // A stable identity lets macOS remember per-display settings between launches.
        descriptor.vendorID = 0xB2D0
        descriptor.productID = 0x0001
        descriptor.serialNum = 1
        descriptor.terminationHandler = { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, self.display != nil else { return }
                self.teardown()
                self.onTerminated?()
            }
        }
        return CGVirtualDisplay(descriptor: descriptor)
    }

    /// A HiDPI display also exposes each resolution at 1x. Make sure the one we want is current.
    private func selectMode(on id: CGDirectDisplayID, size: DisplaySize, hiDPI: Bool) {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] else { return }
        let pixelWidth = hiDPI ? size.width * 2 : size.width
        guard let wanted = modes.first(where: {
            $0.width == size.width && $0.height == size.height && $0.pixelWidth == pixelWidth
        }) else { return }
        if let current = CGDisplayCopyDisplayMode(id),
           current.width == wanted.width, current.height == wanted.height,
           current.pixelWidth == wanted.pixelWidth {
            return
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayWithDisplayMode(config, id, wanted, nil)
        CGCompleteDisplayConfiguration(config, .permanently)
    }
}
