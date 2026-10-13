// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterRemoteDisplay",
    platforms: [.macOS(.v14)],
    targets: [
        // Private CoreGraphics interface used to create the virtual display.
        .target(name: "CGVirtualDisplayPrivate"),
        .target(name: "BRDShared"),
        // The always-on menu bar agent that owns the virtual display.
        .executableTarget(
            name: "BetterRemoteDisplayHelper",
            dependencies: ["BRDShared", "CGVirtualDisplayPrivate"],
            path: "Sources/BRDHelper"
        ),
        // The settings window. Talks to the helper, never touches displays itself.
        .executableTarget(
            name: "BetterRemoteDisplay",
            dependencies: ["BRDShared"],
            path: "Sources/BetterRemoteDisplay"
        ),
    ],
    swiftLanguageModes: [.v5]
)
