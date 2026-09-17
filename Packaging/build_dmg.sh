#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Velnorr.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Packaging/Info.plist")"
DMG_PATH="$DIST_DIR/Velnorr-$APP_VERSION.dmg"
STAGING_DIR="$DIST_DIR/.dmg-staging"
ICON_BUILD_DIR="$DIST_DIR/.icon-build"

distribution_build=false
run_application=false
for argument in "$@"; do
  case "$argument" in
    --distribution) distribution_build=true ;;
    --run) run_application=true ;;
    *)
      print -u2 "Usage: $0 [--distribution|--run]"
      exit 2
      ;;
  esac
done

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  if $distribution_build; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning \
      | awk -F '"' '/Developer ID Application:/ { print $2; exit }')"
  else
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning \
      | awk -F '"' '/Developer ID Application:|Apple Development:/ { print $2; exit }')"
  fi
fi

if $distribution_build && [[ "$SIGNING_IDENTITY" != *"Developer ID Application:"* ]]; then
  print -u2 -- "--distribution requires a Developer ID Application signing identity."
  print -u2 -- "Set CODE_SIGN_IDENTITY or install a Developer ID Application certificate."
  exit 1
fi

if $distribution_build && $run_application; then
  print -u2 -- "--distribution and --run cannot be used together."
  exit 2
fi

if $distribution_build; then
  codesign_timestamp=(--timestamp)
else
  codesign_timestamp=(--timestamp=none)
fi

rm -rf "$APP_PATH" "$DMG_PATH" "$STAGING_DIR" "$ICON_BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$STAGING_DIR" "$ICON_BUILD_DIR"

cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
actool \
  --compile "$ICON_BUILD_DIR" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon Velnorr \
  --output-partial-info-plist "$ICON_BUILD_DIR/Info.plist" \
  "$PROJECT_DIR/Packaging/Velnorr.icon" >/dev/null
cp "$BIN_DIR/Velnorr" "$APP_PATH/Contents/MacOS/Velnorr"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ICON_BUILD_DIR/Velnorr.icns" "$APP_PATH/Contents/Resources/Velnorr.icns"
cp "$ICON_BUILD_DIR/Assets.car" "$APP_PATH/Contents/Resources/Assets.car"
RESOURCE_BUNDLE="$BIN_DIR/Velnorr_Velnorr.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
  # SwiftUI looks up Localizable.strings through the main app bundle.
  # Keep the package bundle for Bundle.module and expose its localization
  # directories at the app resource root as well.
  for localization_directory in "$RESOURCE_BUNDLE"/*.lproj(N); do
    cp -R "$localization_directory" "$APP_PATH/Contents/Resources/"
  done
fi
chmod 755 "$APP_PATH/Contents/MacOS/Velnorr"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --options runtime "${codesign_timestamp[@]}" \
    --entitlements "$PROJECT_DIR/Packaging/Entitlements.plist" \
    --sign "$SIGNING_IDENTITY" "$APP_PATH"
else
  codesign --force --deep --options runtime "${codesign_timestamp[@]}" \
    --entitlements "$PROJECT_DIR/Packaging/Entitlements.plist" \
    --sign - "$APP_PATH"
fi

codesign --verify --deep --strict "$APP_PATH"

if $run_application; then
  open "$APP_PATH"
  echo "Launched: $APP_PATH"
  exit 0
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "Velnorr" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null
echo "Created: $DMG_PATH"
