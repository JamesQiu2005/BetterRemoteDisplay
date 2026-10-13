import AppKit

/// The menu bar glyph: a screen outline with a smaller screen nested in its corner, echoing
/// the app icon. Deliberately not the system "display" symbol, which reads as a real monitor
/// and collides with the Displays menu extra.
enum MenuBarIcon {
    static func image(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 15), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let outer = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 1.25, width: 17.5, height: 12.5),
                                     xRadius: 3, yRadius: 3)
            outer.lineWidth = 1.5
            outer.stroke()

            // Solid when the virtual display exists, hollow when it's off.
            let inner = NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 8, height: 5.5),
                                     xRadius: 1.5, yRadius: 1.5)
            if active {
                inner.fill()
            } else {
                inner.lineWidth = 1
                inner.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
