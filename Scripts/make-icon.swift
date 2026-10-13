// Renders the app icon into an .iconset directory. Usage: swift make-icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // Rounded tile on the standard macOS icon grid.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [NSColor(red: 0.16, green: 0.45, blue: 0.98, alpha: 1),
                        NSColor(red: 0.05, green: 0.16, blue: 0.48, alpha: 1)])!
        .draw(in: tilePath, angle: -90)

    // Three nested screens: one display, several sizes.
    let frames: [(NSRect, CGFloat)] = [
        (NSRect(x: 232, y: 330, width: 560, height: 364), 0.30),
        (NSRect(x: 232, y: 330, width: 430, height: 280), 0.55),
        (NSRect(x: 232, y: 330, width: 300, height: 196), 1.00),
    ]
    for (rect, alpha) in frames {
        let r = NSRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s)
        let path = NSBezierPath(roundedRect: r, xRadius: 34 * s, yRadius: 34 * s)
        NSColor.white.withAlphaComponent(alpha * 0.22).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(alpha).setStroke()
        path.lineWidth = 22 * s
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: out.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: out.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
