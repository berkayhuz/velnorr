#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"

APP_PATH="$DIST_DIR/Velnorr.app"

APP_VERSION="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$PROJECT_DIR/Packaging/Info.plist"
)"

DMG_PATH="$DIST_DIR/Velnorr-$APP_VERSION.dmg"
STAGING_DIR="$DIST_DIR/.dmg-staging"
ICON_BUILD_DIR="$DIST_DIR/.icon-build"

distribution_build=false
run_application=false

for argument in "$@"; do
  case "$argument" in
    --distribution)
      distribution_build=true
      ;;

    --run)
      run_application=true
      ;;

    *)
      print -u2 -- "Usage: $0 [--distribution] [--run]"
      exit 2
      ;;
  esac
done

if $distribution_build && $run_application; then
  print -u2 -- "--distribution and --run cannot be used together."
  exit 2
fi

# -------------------------------------------------------------------
# Code-signing identity
# -------------------------------------------------------------------

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then

  if $distribution_build; then

    # Distribution builds MUST use Developer ID Application.
    SIGNING_IDENTITY="$(
      security find-identity -v -p codesigning \
        | awk -F '"' \
          '/Developer ID Application:/ {
            print $2
            exit
          }'
    )"

  else

    # Local development/testing:
    # Prefer Apple Development so every local DMG/app build
    # keeps a stable development identity.
    SIGNING_IDENTITY="$(
      security find-identity -v -p codesigning \
        | awk -F '"' \
          '/Apple Development:/ {
            print $2
            exit
          }'
    )"

    # If Apple Development is unavailable,
    # Developer ID Application is still a valid stable identity.
    if [[ -z "$SIGNING_IDENTITY" ]]; then
      SIGNING_IDENTITY="$(
        security find-identity -v -p codesigning \
          | awk -F '"' \
            '/Developer ID Application:/ {
              print $2
              exit
            }'
      )"
    fi
  fi
fi

# Never fall back to ad-hoc signing.
if [[ -z "$SIGNING_IDENTITY" ]]; then
  print -u2 -- ""
  print -u2 -- "ERROR: No valid Apple code-signing identity was found."
  print -u2 -- ""
  print -u2 -- "Velnorr uses macOS privacy permissions and CGEventTap."
  print -u2 -- "Ad-hoc signing is intentionally disabled because it does"
  print -u2 -- "not provide a stable code identity across builds."
  print -u2 -- ""
  print -u2 -- "Install one of:"
  print -u2 -- "  - Apple Development certificate"
  print -u2 -- "  - Developer ID Application certificate"
  print -u2 -- ""
  print -u2 -- "Available identities:"
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

if $distribution_build \
  && [[ "$SIGNING_IDENTITY" != *"Developer ID Application:"* ]]; then

  print -u2 -- ""
  print -u2 -- "ERROR: --distribution requires:"
  print -u2 -- "Developer ID Application"
  print -u2 -- ""
  print -u2 -- "Current identity:"
  print -u2 -- "$SIGNING_IDENTITY"
  print -u2 -- ""
  print -u2 -- "Set CODE_SIGN_IDENTITY or install a Developer ID certificate."
  exit 1
fi

echo ""
echo "Signing Velnorr with:"
echo "  $SIGNING_IDENTITY"
echo ""

# Distribution signing requires a secure timestamp.
if $distribution_build; then
  codesign_timestamp=(--timestamp)
else
  codesign_timestamp=(--timestamp=none)
fi

# -------------------------------------------------------------------
# Clean
# -------------------------------------------------------------------

rm -rf \
  "$APP_PATH" \
  "$DMG_PATH" \
  "$STAGING_DIR" \
  "$ICON_BUILD_DIR"

mkdir -p \
  "$APP_PATH/Contents/MacOS" \
  "$APP_PATH/Contents/Resources" \
  "$STAGING_DIR" \
  "$ICON_BUILD_DIR"

# -------------------------------------------------------------------
# Build
# -------------------------------------------------------------------

cd "$PROJECT_DIR"

echo "Building release binary..."
swift build -c release

BIN_DIR="$(
  swift build \
    -c release \
    --show-bin-path
)"

# -------------------------------------------------------------------
# App icon
# -------------------------------------------------------------------

echo "Building app icon..."

actool \
  --compile "$ICON_BUILD_DIR" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon Velnorr \
  --output-partial-info-plist "$ICON_BUILD_DIR/Info.plist" \
  "$PROJECT_DIR/Packaging/Velnorr.icon" \
  >/dev/null

# -------------------------------------------------------------------
# App bundle
# -------------------------------------------------------------------

echo "Creating Velnorr.app..."

cp \
  "$BIN_DIR/Velnorr" \
  "$APP_PATH/Contents/MacOS/Velnorr"

cp \
  "$PROJECT_DIR/Packaging/Info.plist" \
  "$APP_PATH/Contents/Info.plist"

cp \
  "$ICON_BUILD_DIR/Velnorr.icns" \
  "$APP_PATH/Contents/Resources/Velnorr.icns"

cp \
  "$ICON_BUILD_DIR/Assets.car" \
  "$APP_PATH/Contents/Resources/Assets.car"

RESOURCE_BUNDLE="$BIN_DIR/Velnorr_Velnorr.bundle"

if [[ -d "$RESOURCE_BUNDLE" ]]; then

  cp -R \
    "$RESOURCE_BUNDLE" \
    "$APP_PATH/Contents/Resources/"

  # SwiftUI looks up Localizable.strings through the main app bundle.
  # Keep Bundle.module resources while also exposing localization
  # directories at the app resource root.
  for localization_directory in "$RESOURCE_BUNDLE"/*.lproj(N); do
    cp -R \
      "$localization_directory" \
      "$APP_PATH/Contents/Resources/"
  done
fi

chmod 755 \
  "$APP_PATH/Contents/MacOS/Velnorr"

# -------------------------------------------------------------------
# Code signing
# -------------------------------------------------------------------

echo "Signing Velnorr.app..."

codesign \
  --force \
  --options runtime \
  "${codesign_timestamp[@]}" \
  --entitlements "$PROJECT_DIR/Packaging/Entitlements.plist" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_PATH"

# -------------------------------------------------------------------
# Signature verification
# -------------------------------------------------------------------

echo ""
echo "Verifying signature..."

codesign \
  --verify \
  --strict \
  --verbose=2 \
  "$APP_PATH"

echo ""
echo "Code-signing information:"
echo "------------------------------------------------------------"

codesign \
  --display \
  --verbose=4 \
  "$APP_PATH" \
  2>&1 \
  | grep -E \
    'Identifier=|Format=|CodeDirectory|Signature=|Authority=|TeamIdentifier=|Runtime Version'

echo "------------------------------------------------------------"

echo ""
echo "Designated requirement:"
echo "------------------------------------------------------------"

codesign \
  --display \
  --requirements - \
  "$APP_PATH" \
  2>&1

echo "------------------------------------------------------------"
echo ""

# -------------------------------------------------------------------
# Optional local run
# -------------------------------------------------------------------

if $run_application; then
  echo "Launching:"
  echo "  $APP_PATH"

  open "$APP_PATH"

  exit 0
fi

# -------------------------------------------------------------------
# DMG
# -------------------------------------------------------------------

echo "Creating DMG staging directory..."

cp -R \
  "$APP_PATH" \
  "$STAGING_DIR/"

ln -s \
  /Applications \
  "$STAGING_DIR/Applications"

echo "Creating DMG..."

hdiutil create \
  -volname "Velnorr" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

echo "Verifying DMG..."

hdiutil verify \
  "$DMG_PATH" \
  >/dev/null

echo ""
echo "Created:"
echo "  $DMG_PATH"
echo ""
echo "Signed app:"
echo "  $APP_PATH"
echo ""