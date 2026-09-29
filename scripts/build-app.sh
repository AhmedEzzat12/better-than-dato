#!/usr/bin/env bash
# Builds BetterThanDato and assembles a signed .app bundle in build/.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
CONFIG="${1:-debug}"
NAME="BetterThanDato"
APP="build/$NAME.app"

# Release builds are universal: macOS 26 is the last release for Intel Macs, so ship an x86_64 slice too.
# Debug builds stay host-only for speed.
ARCH_FLAGS=""
if [[ "$CONFIG" == "release" ]]; then
  ARCH_FLAGS="--arch arm64 --arch x86_64"
fi
# shellcheck disable=SC2086 # ARCH_FLAGS is intentionally word-split
swift build -c "$CONFIG" --product "$NAME" $ARCH_FLAGS
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
