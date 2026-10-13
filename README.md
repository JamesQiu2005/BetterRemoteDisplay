# BetterRemoteDisplay

A macOS menu bar app that does one thing: sets the resolution of the display you see when
you connect to a Mac remotely.

Pick an Apple device from the menu and the remote Mac's desktop takes that device's logical
resolution, in HiDPI, so the session fits the screen you are sitting at. On a headless Mac
(a Mac mini or Mac Studio with no monitor) it replaces the fixed 1920 × 1080 display macOS
falls back to.

## Features

- Built-in resolutions for current MacBook, iMac, Studio Display, iPad and iPhone models.
  MacBook sizes exclude the notch (1512 × 945 rather than 1512 × 982).
- Custom resolutions.
- Portrait and landscape.
- HiDPI (2x) rendering, on by default.
- A background helper that lives in the menu bar and starts at login, and a small settings
  window that only needs to be open while you change something.

## Requirements

- macOS 14 or later, Apple silicon or Intel. Liquid Glass styling on macOS 26 and later.
- To build: Xcode 26 or later (Swift 6 toolchain).

## Build

```sh
./build.sh            # build into ./build
./build.sh run        # build and open
./build.sh install    # build, copy to /Applications, open
./build.sh appstore   # sandboxed build into ./build/AppStore
./build.sh dist       # build and zip for distribution
```

`./build.sh dist` also zips the result, and notarizes it when `NOTARY_PROFILE` names a
`notarytool` keychain profile.

The script signs with a Developer ID certificate if the keychain has one and ad-hoc
otherwise. Set `SIGN_IDENTITY` to choose a different identity.

If you build under your own team, replace the team ID in the app group identifier in
`Sources/BRDShared/ConfigStore.swift` and `Resources/AppStore.entitlements`, and the bundle
identifiers in `Resources/*.plist`.

## How it works

The helper creates a virtual display through `CGVirtualDisplay` and resizes it in place when
you choose a resolution. `CGVirtualDisplay` is a private CoreGraphics interface (declared in
`Sources/CGVirtualDisplayPrivate`); it is not documented by Apple and could change in a
future macOS release.

| Path | Contents |
| --- | --- |
| `Sources/BRDHelper` | Menu bar helper: owns the virtual display and the menu panel |
| `Sources/BetterRemoteDisplay` | Settings window |
| `Sources/BRDShared` | Config model, built-in presets, the config file both processes share |
| `Sources/CGVirtualDisplayPrivate` | Header for the private virtual display interface |

The two processes share one JSON config file and tell each other about changes with a
distributed notification.

## Limitations

- macOS refuses desktops smaller than roughly 960 × 540 points, so iPhone presets use the
  phone's native pixels at 2x (same aspect ratio) instead of its point size.
- On a Mac with a physical display attached, the virtual display is added as an extra
  display rather than replacing it.

## License

MIT. See [LICENSE](LICENSE).
