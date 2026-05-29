#!/usr/bin/env bash
set -euo pipefail

# Release build: sign with Developer ID + Hardened Runtime, notarize, staple, package as .dmg.
#
# Prereqs (one-time):
#   1. security find-identity -v -p codesigning  → "Developer ID Application: ao hirata (XDZ7L87T5C)" valid
#   2. xcrun notarytool store-credentials "MXGestureBar-notary" --apple-id ... --team-id XDZ7L87T5C --password ...
#
# Usage:
#   script/release.sh 1.0.0

VERSION="${1:?usage: release.sh <version> (e.g. 1.0.0)}"
APP_NAME="MXGestureBar"
BUNDLE_ID="dev.aovoq.MXGestureBar"
TEAM_ID="XDZ7L87T5C"
SIGN_ID="Developer ID Application: ao hirata (${TEAM_ID})"
NOTARY_PROFILE="Local Notary"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="$ROOT_DIR/script/MXGestureBar.entitlements"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

echo "==> swift build -c release"
swift build --package-path "$ROOT_DIR" -c release --product "$APP_NAME"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" -c release --show-bin-path)/$APP_NAME"

echo "==> Assemble app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 ao hirata. All rights reserved.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>MXGestureBar needs input monitoring to read MX Master HID++ gesture reports.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>MXGestureBar uses System Events to trigger Mission Control space-switching shortcuts.</string>
</dict>
</plist>
PLIST

echo "==> codesign (Developer ID + Hardened Runtime)"
/usr/bin/codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_ID" \
  "$APP_BUNDLE"

echo "==> Verify signature"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Zip for notarization"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Submit to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Staple ticket to .app"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

echo "==> Re-zip stapled app"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Build .dmg"
rm -f "$DMG_PATH"
TMP_DMG_DIR="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$TMP_DMG_DIR" \
  -ov -format ULFO "$DMG_PATH"
rm -rf "$TMP_DMG_DIR"

echo "==> Sign .dmg and notarize it too"
/usr/bin/codesign --force --timestamp --sign "$SIGN_ID" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$DMG_PATH"

echo
echo "Done."
echo "  App: $APP_BUNDLE"
echo "  Zip: $ZIP_PATH"
echo "  Dmg: $DMG_PATH"
echo
echo "Sanity check:"
echo "  spctl --assess -vv --type execute \"$APP_BUNDLE\""
