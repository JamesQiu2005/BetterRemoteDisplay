#!/bin/zsh
# Builds BetterRemoteDisplay.app (settings app with the menu bar helper embedded).
#   ./build.sh            build into ./build
#   ./build.sh run        build, then open the app
#   ./build.sh install    build, then copy to /Applications and open it
#   ./build.sh appstore   sandboxed build into ./build/AppStore
#   ./build.sh dist       build, then zip for distribution (notarized if NOTARY_PROFILE is set)
set -euo pipefail
cd "${0:A:h}"

MODE="${1:-}"
if [[ "$MODE" == appstore ]]; then
  OUT="build/AppStore"
  CERT="Apple Distribution"
  ENTITLEMENTS=(--entitlements Resources/AppStore.entitlements)
else
  OUT="build"
  CERT="Developer ID Application"
  ENTITLEMENTS=()
fi
APP="$OUT/BetterRemoteDisplay.app"
HELPER="$APP/Contents/Library/LoginItems/BetterRemoteDisplay Helper.app"

# Universal: macOS 14 and 15 still run on Intel Macs.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$HELPER/Contents/MacOS" "$HELPER/Contents/Resources"
# SwiftPM stamps the binaries as built with the deployment target's SDK. macOS decides whether
# an app gets the current design (Liquid Glass) from that stamp, so record the real SDK.
SDK="$(xcrun --sdk macosx --show-sdk-version)"
vtool -set-build-version macos 14.0 "$SDK" -replace -output "$APP/Contents/MacOS/BetterRemoteDisplay" "$BIN/BetterRemoteDisplay"
vtool -set-build-version macos 14.0 "$SDK" -replace -output "$HELPER/Contents/MacOS/BetterRemoteDisplayHelper" "$BIN/BetterRemoteDisplayHelper"
cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/Helper-Info.plist "$HELPER/Contents/Info.plist"

if [[ ! -f build/AppIcon.icns || Scripts/make-icon.swift -nt build/AppIcon.icns ]]; then
  rm -rf build/AppIcon.iconset
  swift Scripts/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/"
cp build/AppIcon.icns "$HELPER/Contents/Resources/"

# The matching certificate if there is one, otherwise ad-hoc. Override with SIGN_IDENTITY.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' -v cert="$CERT" 'index($2, cert) {print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
xattr -cr "$APP"
# Notarization needs a secure timestamp, which ad-hoc signatures can't have.
TIMESTAMP=--timestamp
[[ "$IDENTITY" == - ]] && TIMESTAMP=--timestamp=none
codesign --force --options runtime $TIMESTAMP $ENTITLEMENTS --sign "$IDENTITY" "$HELPER"
codesign --force --options runtime $TIMESTAMP $ENTITLEMENTS --sign "$IDENTITY" "$APP"
echo "Built $APP (signed: $IDENTITY)"

case "$MODE" in
  run)
    open "$APP"
    ;;
  install)
    # Stop a running helper first so the old copy isn't the one holding the display.
    pkill -x BetterRemoteDisplayHelper || true
    pkill -x BetterRemoteDisplay || true
    rm -rf "/Applications/BetterRemoteDisplay.app"
    ditto "$APP" "/Applications/BetterRemoteDisplay.app"
    open "/Applications/BetterRemoteDisplay.app"
    ;;
  dist)
    ZIP="build/BetterRemoteDisplay.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    # NOTARY_PROFILE is a keychain profile made with `xcrun notarytool store-credentials`.
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
      xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
      xcrun stapler staple "$APP"
      rm -f "$ZIP"
      ditto -c -k --keepParent "$APP" "$ZIP"
    else
      echo "Not notarized (NOTARY_PROFILE unset): Gatekeeper will block this on other Macs."
    fi
    echo "Packaged $ZIP"
    ;;
esac
