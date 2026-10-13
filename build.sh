#!/bin/zsh
# Builds BetterRemoteDisplay.app (settings app with the menu bar helper embedded).
#   ./build.sh            build into ./build
#   ./build.sh run        build, then open the app
#   ./build.sh install    build, then copy to /Applications and open it
#   ./build.sh appstore   sandboxed build into ./build/AppStore; with App Store certificates
#                         and profiles in place (see README) also a .pkg ready to upload
#   ./build.sh dist       build, then zip for distribution (notarized if NOTARY_PROFILE is set)
set -euo pipefail
cd "${0:A:h}"

MODE="${1:-}"
FLAGS=()
if [[ "$MODE" == appstore ]]; then
  # The App Store build is the only one with the in-app purchase.
  FLAGS=(-Xswiftc -DAPPSTORE)
  OUT="build/AppStore"
  CERT="Apple Distribution"
else
  OUT="build"
  CERT="Developer ID Application"
fi
APP="$OUT/BetterRemoteDisplay.app"
HELPER="$APP/Contents/Library/LoginItems/BetterRemoteDisplay Helper.app"

# Universal: macOS 14 and 15 still run on Intel Macs.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release $ARCHS $FLAGS
BIN="$(swift build -c release $ARCHS $FLAGS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$HELPER/Contents/MacOS" "$HELPER/Contents/Resources"
# SwiftPM stamps the binaries as built with the deployment target's SDK. macOS decides whether
# an app gets the current design (Liquid Glass) from that stamp, so record the real SDK.
SDK="$(xcrun --sdk macosx --show-sdk-version)"
vtool -set-build-version macos 14.0 "$SDK" -replace -output "$APP/Contents/MacOS/BetterRemoteDisplay" "$BIN/BetterRemoteDisplay"
vtool -set-build-version macos 14.0 "$SDK" -replace -output "$HELPER/Contents/MacOS/BetterRemoteDisplayHelper" "$BIN/BetterRemoteDisplayHelper"
cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/Helper-Info.plist "$HELPER/Contents/Info.plist"
# VERSION (e.g. 1.2) overrides the version in the plists; releases set it from the git tag.
if [[ -n "${VERSION:-}" ]]; then
  for plist in "$APP/Contents/Info.plist" "$HELPER/Contents/Info.plist"; do
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
                            -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$plist"
  done
fi

if [[ ! -f build/AppIcon.icns || Scripts/make-icon.swift -nt build/AppIcon.icns ]]; then
  rm -rf build/AppIcon.iconset
  swift Scripts/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/"
cp build/AppIcon.icns "$HELPER/Contents/Resources/"

# The matching certificate if there is one, otherwise ad-hoc. Override with SIGN_IDENTITY.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' -v cert="$CERT" 'index($2, cert) && !found {found = $2} END {print found}')}"
IDENTITY="${IDENTITY:--}"

# Entitlements for one bundle. The App Store wants each to name its own App ID and team,
# which only a matching provisioning profile can authorize, so those are added only when
# signing with a distribution certificate.
entitlements_for() {
  local bundle_id="$1" out="build/$1.entitlements"
  cp Resources/AppStore.entitlements "$out"
  if [[ "$IDENTITY" == "Apple Distribution"* || "$IDENTITY" == "3rd Party Mac Developer Application"* ]]; then
    local team="${${IDENTITY##*\(}%\)}"
    /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $team.$bundle_id" \
                            -c "Add :com.apple.developer.team-identifier string $team" "$out"
  fi
  echo "$out"
}

APP_ENTITLEMENTS=()
HELPER_ENTITLEMENTS=()
if [[ "$MODE" == appstore ]]; then
  APP_ENTITLEMENTS=(--entitlements "$(entitlements_for com.hanzeqiu.BetterRemoteDisplay)")
  HELPER_ENTITLEMENTS=(--entitlements "$(entitlements_for com.hanzeqiu.BetterRemoteDisplay.Helper)")
  # Mac App Store provisioning profiles, downloaded from the developer portal.
  [[ -f Signing/App.provisionprofile ]] && cp Signing/App.provisionprofile "$APP/Contents/embedded.provisionprofile"
  [[ -f Signing/Helper.provisionprofile ]] && cp Signing/Helper.provisionprofile "$HELPER/Contents/embedded.provisionprofile"
fi

xattr -cr "$APP"
# Notarization needs a secure timestamp, which ad-hoc signatures can't have.
TIMESTAMP=--timestamp
[[ "$IDENTITY" == - ]] && TIMESTAMP=--timestamp=none
codesign --force --options runtime $TIMESTAMP $HELPER_ENTITLEMENTS --sign "$IDENTITY" "$HELPER"
codesign --force --options runtime $TIMESTAMP $APP_ENTITLEMENTS --sign "$IDENTITY" "$APP"
echo "Built $APP (signed: $IDENTITY)"

case "$MODE" in
  appstore)
    INSTALLER="$(security find-identity -v | awk -F'"' '/Mac Installer Distribution|3rd Party Mac Developer Installer/ && !found {found = $2} END {print found}')"
    if [[ "$IDENTITY" == - || "$IDENTITY" == "Developer ID"* || -z "$INSTALLER" || ! -f "$APP/Contents/embedded.provisionprofile" ]]; then
      echo "Local test build only. An App Store package needs the Apple Distribution and"
      echo "Mac Installer Distribution certificates plus Signing/{App,Helper}.provisionprofile."
    else
      productbuild --component "$APP" /Applications --sign "$INSTALLER" "$OUT/BetterRemoteDisplay.pkg"
      echo "Packaged $OUT/BetterRemoteDisplay.pkg (upload with Transporter)"
    fi
    ;;
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
