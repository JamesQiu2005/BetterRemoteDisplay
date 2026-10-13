import Foundation

/// Built-in logical resolutions of Apple devices, in points.
///
/// MacBook sizes are the 16:10 area below the notch, not the full panel
/// (e.g. 1512 × 945 rather than 1512 × 982). iPad and iPhone sizes are landscape;
/// the menu's rotate button gives portrait.
public enum Presets {
    public static let all: [DisplayPreset] = mac + ipad + iphone

    private static func preset(_ category: DeviceCategory, _ key: String, _ name: String, _ variant: String? = nil,
                               _ width: Int, _ height: Int, shown: Bool = true) -> DisplayPreset {
        DisplayPreset(id: "\(category.rawValue).\(key)", category: category, name: name, variant: variant,
                      size: DisplaySize(width, height), showsByDefault: shown)
    }

    static let mac: [DisplayPreset] = [
        preset(.mac, "mba13.default", "MacBook Air 13″", "Default", 1470, 918),
        preset(.mac, "mba13.more", "MacBook Air 13″", "More Space", 1710, 1068, shown: false),
        preset(.mac, "mba13.larger", "MacBook Air 13″", "Larger Text", 1280, 800, shown: false),
        preset(.mac, "mba15.default", "MacBook Air 15″", "Default", 1710, 1068),
        preset(.mac, "mba15.more", "MacBook Air 15″", "More Space", 1920, 1200, shown: false),
        preset(.mac, "mba15.larger", "MacBook Air 15″", "Larger Text", 1440, 900, shown: false),
        preset(.mac, "mbp14.default", "MacBook Pro 14″", "Default", 1512, 945),
        preset(.mac, "mbp14.more", "MacBook Pro 14″", "More Space", 1800, 1125),
        preset(.mac, "mbp14.larger", "MacBook Pro 14″", "Larger Text", 1352, 845, shown: false),
        preset(.mac, "mbp16.default", "MacBook Pro 16″", "Default", 1728, 1080),
        preset(.mac, "mbp16.more", "MacBook Pro 16″", "More Space", 2056, 1285),
        preset(.mac, "mbp16.larger", "MacBook Pro 16″", "Larger Text", 1496, 935, shown: false),
        preset(.mac, "neo.default", "MacBook Neo", "Default", 1408, 881),
        preset(.mac, "neo.more", "MacBook Neo", "More Space", 1637, 1024, shown: false),
        preset(.mac, "imac24.default", "iMac 24″", "Default", 2240, 1260),
        preset(.mac, "imac24.more", "iMac 24″", "More Space", 2560, 1440, shown: false),
        preset(.mac, "studio.default", "Studio Display", "Default", 2560, 1440),
        preset(.mac, "studio.more", "Studio Display", "More Space", 3200, 1800, shown: false),
        preset(.mac, "xdr.default", "Pro Display XDR", "Default", 3008, 1692, shown: false),
    ]

    static let ipad: [DisplayPreset] = [
        preset(.ipad, "mini", "iPad mini", nil, 1133, 744),
        preset(.ipad, "11", "iPad · iPad Air 11″", nil, 1180, 820),
        preset(.ipad, "pro11", "iPad Pro 11″", "M4 and later", 1210, 834),
        preset(.ipad, "air13", "iPad Air 13″", nil, 1366, 1024),
        preset(.ipad, "air13.more", "iPad Air 13″", "More Space", 1590, 1192, shown: false),
        preset(.ipad, "pro13", "iPad Pro 13″", "M4 and later", 1376, 1032),
        preset(.ipad, "pro11.2018", "iPad Pro 11″", "2018–2022", 1194, 834, shown: false),
        preset(.ipad, "10.2", "iPad 10.2″", "7th–9th generation", 1080, 810, shown: false),
    ]

    // macOS refuses desktops as small as an iPhone's point size (e.g. 874 × 402), so these are
    // the panel's native pixels at 2x instead: same aspect ratio, pixel-exact on the phone.
    static let iphone: [DisplayPreset] = [
        preset(.iphone, "6.1a", "iPhone 17e · 16e", "Also 13, 14", 1266, 585),
        preset(.iphone, "6.1b", "iPhone 16 · 15", "Also 14 Pro, 15 Pro", 1278, 590, shown: false),
        preset(.iphone, "6.3", "iPhone 17 · 17 Pro · 18 Pro", "Also 16 Pro", 1311, 603),
        preset(.iphone, "air", "iPhone Air", nil, 1368, 630),
        preset(.iphone, "6.9", "iPhone 18 Pro Max", "Also 16 Pro Max, 17 Pro Max", 1434, 660),
        preset(.iphone, "6.7b", "iPhone 16 Plus", "Also 14 Pro Max, 15 Plus, 15 Pro Max", 1398, 645, shown: false),
        preset(.iphone, "6.7a", "iPhone 14 Plus", "Also 13 Pro Max", 1389, 642, shown: false),
    ]
}
