#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Velnorr.app"
DMG_PATH="$DIST_DIR/Velnorr-1.0.0.dmg"
STAGING_DIR="$DIST_DIR/.dmg-staging"

rm -rf "$APP_PATH" "$DMG_PATH" "$STAGING_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$STAGING_DIR"

cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/Velnorr" "$APP_PATH/Contents/MacOS/Velnorr"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/Velnorr.icns" "$APP_PATH/Contents/Resources/Velnorr.icns"
RESOURCE_BUNDLE="$BIN_DIR/Velnorr_Velnorr.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
  # SwiftUI looks up Localizable.strings through the main app bundle.
  # Keep the package bundle for Bundle.module and expose its localization
  # directories at the app resource root as well.
  cp -R "$RESOURCE_BUNDLE"/*.lproj "$APP_PATH/Contents/Resources/" 2>/dev/null || true
fi
chmod 755 "$APP_PATH/Contents/MacOS/Velnorr"

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning \
    | awk -F '"' '/Apple Development:|Developer ID Application:/ { print $2; exit }')"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp=none \
    --entitlements "$PROJECT_DIR/Packaging/Entitlements.plist" \
    --sign "$SIGNING_IDENTITY" "$APP_PATH"
else
  codesign --force --deep --options runtime --timestamp=none \
    --entitlements "$PROJECT_DIR/Packaging/Entitlements.plist" \
    --sign - "$APP_PATH"
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "Velnorr" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

codesign --verify --deep --strict "$APP_PATH"
echo "Created: $DMG_PATH"
