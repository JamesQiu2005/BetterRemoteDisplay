import Foundation

/// A logical (point) resolution.
public struct DisplaySize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }

    public var rotated: DisplaySize { DisplaySize(height, width) }
    public var isPortrait: Bool { height > width }
    public var label: String { "\(width) × \(height)" }

    /// Same resolution regardless of orientation.
    public func matches(_ other: DisplaySize) -> Bool {
        self == other || self == other.rotated
    }

    /// Largest backing store the virtual display is created with, in pixels.
    public static let maxPixels = 8192
    /// macOS also refuses desktops it considers too small (roughly under 960 × 540). That rule
    /// isn't a simple bound, so the helper checks what it actually got instead of guessing here.
    public static let sideRange = 400...maxPixels

    public var isValid: Bool {
        Self.sideRange.contains(width) && Self.sideRange.contains(height)
    }

    /// HiDPI needs a 2x backing store, which has to fit in `maxPixels`.
    public var supportsHiDPI: Bool {
        width * 2 <= Self.maxPixels && height * 2 <= Self.maxPixels
    }
}

public enum DeviceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case mac, ipad, iphone, custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .mac: "Mac"
        case .ipad: "iPad"
        case .iphone: "iPhone"
        case .custom: "Custom"
        }
    }

    public var symbol: String {
        switch self {
        case .mac: "macbook"
        case .ipad: "ipad.landscape"
        case .iphone: "iphone"
        case .custom: "slider.horizontal.3"
        }
    }
}

/// One selectable resolution: a built-in device mode or a user-defined one.
public struct DisplayPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: DeviceCategory
    /// Device name, e.g. "MacBook Pro 14″".
    public let name: String
    /// Which of the device's modes this is, e.g. "Default" or "More Space".
    public let variant: String?
    public let size: DisplaySize
    /// Whether the preset is listed in the menu bar panel before the user changes anything.
    public let showsByDefault: Bool

    public init(id: String, category: DeviceCategory, name: String, variant: String? = nil,
                size: DisplaySize, showsByDefault: Bool = true) {
        self.id = id
        self.category = category
        self.name = name
        self.variant = variant
        self.size = size
        self.showsByDefault = showsByDefault
    }
}

public struct CustomResolution: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var size: DisplaySize

    public init(id: UUID = UUID(), name: String, size: DisplaySize) {
        self.id = id
        self.name = name
        self.size = size
    }

    public var preset: DisplayPreset {
        DisplayPreset(id: "custom.\(id.uuidString)", category: .custom,
                      name: name.isEmpty ? size.label : name, size: size)
    }
}

/// Which build this is. The free edition is limited to one device; Pro (built with `-DPRO`)
/// adds more devices in the menu and custom resolutions.
public enum Edition {
    #if PRO
    public static let isPro = true
    #else
    public static let isPro = false
    #endif

    public static let name = isPro ? "BetterRemoteDisplay Pro" : "BetterRemoteDisplay"
    public static let upgradeURL = URL(string: "https://brd.spektralab.app")!
}

/// Everything the helper needs to know. Written by whichever side the user touched last.
public struct Config: Codable, Equatable, Sendable {
    /// Whether the virtual display exists at all.
    public var enabled = true
    public var hiDPI = true
    public var size = DisplaySize(1512, 945)
    /// Per-preset overrides of `DisplayPreset.showsByDefault`.
    public var visibility: [String: Bool] = [:]
    public var customs: [CustomResolution] = []
    /// The one device the free edition offers, by name.
    public var device = "MacBook Pro 14″"

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        hiDPI = try c.decodeIfPresent(Bool.self, forKey: .hiDPI) ?? d.hiDPI
        size = try c.decodeIfPresent(DisplaySize.self, forKey: .size) ?? d.size
        visibility = try c.decodeIfPresent([String: Bool].self, forKey: .visibility) ?? d.visibility
        customs = try c.decodeIfPresent([CustomResolution].self, forKey: .customs) ?? d.customs
        device = try c.decodeIfPresent(String.self, forKey: .device) ?? d.device
        if !size.isValid { size = d.size }
    }

    public func isVisible(_ preset: DisplayPreset) -> Bool {
        visibility[preset.id] ?? preset.showsByDefault
    }

    public func presets(in category: DeviceCategory) -> [DisplayPreset] {
        category == .custom ? customs.map(\.preset) : Presets.all.filter { $0.category == category }
    }

    /// The presets listed in the menu bar panel for a category.
    public func menuPresets(in category: DeviceCategory) -> [DisplayPreset] {
        presets(in: category).filter(isVisible)
    }

    /// Every mode of the free edition's one device.
    public var devicePresets: [DisplayPreset] {
        Presets.all.filter { $0.name == device }
    }

    /// The preset the current resolution came from, if any.
    public var currentPreset: DisplayPreset? {
        let candidates = Presets.all + customs.map(\.preset)
        return candidates.first { $0.size == size }
            ?? candidates.first { $0.size.matches(size) }
    }
}
