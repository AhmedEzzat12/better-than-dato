#!/usr/bin/env bash
# Builds BetterThanDato and assembles a signed .app bundle in build/.
# Usage: scripts/build-app.sh [debug|release]
# Optional env: APP_VERSION (e.g. 1.2.0), BUILD_NUMBER (must increase for Sparkle),
#               SPARKLE_PUBLIC_KEY (turns on auto-updates), SIGN_IDENTITY (default: ad-hoc),
#               UNIVERSAL=0 (release build for this Mac's architecture only).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
CONFIG="${1:-debug}"
NAME="BetterThanDato"
APP="build/$NAME.app"

# Release builds are universal: macOS 26 is the last release for Intel Macs, so ship an x86_64 slice too.
# Debug builds stay host-only for speed.
ARCH_FLAGS=""
if [[ "$CONFIG" == "release" && "${UNIVERSAL:-1}" == "1" ]]; then
  ARCH_FLAGS="--arch arm64 --arch x86_64"
fi
# shellcheck disable=SC2086 # ARCH_FLAGS is intentionally word-split
swift build -c "$CONFIG" --product "$NAME" $ARCH_FLAGS
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"
PLIST="$APP/Contents/Info.plist"
cp Resources/Info.plist "$PLIST"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [[ -n "${APP_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$PLIST"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
fi
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$PLIST"
fi

# Embed Sparkle (the binary's rpath points at Contents/Frameworks).
SPARKLE_FRAMEWORK="$(find "$BIN_DIR" -maxdepth 2 -name Sparkle.framework -type d | head -1)"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

# --deep also signs Sparkle's helpers (Autoupdate, Updater.app, XPC services) with the same identity.
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
