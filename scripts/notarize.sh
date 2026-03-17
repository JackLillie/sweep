#!/bin/bash
set -euo pipefail

# signs, notarizes, and staples Sweep.app inside a dmg.
#
# required env vars:
#   APPLE_ID          — your apple id email
#   APPLE_TEAM_ID     — your team id (e.g. A64F9R7E55)
#   APPLE_APP_PASSWORD — app-specific password (generate at appleid.apple.com)
#
# usage:
#   export APPLE_ID="you@example.com"
#   export APPLE_TEAM_ID="XXXXXXXXXX"
#   export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#   ./scripts/notarize.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# load .env if present
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi
SCHEME="Sweep"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/${SCHEME}.app"
DMG_PATH="${BUILD_DIR}/${SCHEME}.dmg"
SIGNING_IDENTITY="Developer ID Application"

for var in APPLE_ID APPLE_TEAM_ID APPLE_APP_PASSWORD; do
    if [ -z "${!var:-}" ]; then
        echo "error: $var is not set"
        exit 1
    fi
done

echo "==> cleaning build dir"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> building release"
xcodebuild -project "${PROJECT_DIR}/Sweep.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -quiet

# find the built app
BUILT_APP="$(find "${BUILD_DIR}/DerivedData" -name "${SCHEME}.app" -path "*/Release/*" -maxdepth 5 | head -1)"
if [ -z "$BUILT_APP" ]; then
    echo "error: built app not found"
    exit 1
fi

echo "==> copying app to build dir"
cp -R "$BUILT_APP" "$APP_PATH"

# re-sign embedded binaries (mole go binaries) with timestamp
echo "==> signing embedded binaries"
find "$APP_PATH" -type f -perm +111 -not -name "*.sh" -not -name "mole" | while read -r bin; do
    codesign --force --timestamp --options runtime \
        --sign "$SIGNING_IDENTITY" "$bin" 2>/dev/null || true
done

# sign scripts
find "$APP_PATH" -name "*.sh" -o -name "mole" -not -path "*/MacOS/*" | while read -r script; do
    codesign --force --timestamp --options runtime \
        --sign "$SIGNING_IDENTITY" "$script" 2>/dev/null || true
done

# sign the app bundle
echo "==> signing app"
codesign --force --deep --timestamp --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "${PROJECT_DIR}/Sweep/Sweep.entitlements" \
    "$APP_PATH"

# verify
echo "==> verifying signature"
codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type exec --verbose "$APP_PATH" 2>&1 || true

echo "==> creating dmg"
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH"
mv "${PROJECT_DIR}/Sweep.dmg" "$DMG_PATH"

# sign the dmg
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "==> notarizing"
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "==> stapling"
xcrun stapler staple "$DMG_PATH"

echo ""
echo "done: $DMG_PATH"
echo "ready for distribution."
