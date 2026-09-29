#!/usr/bin/env bash
# Builds BetterThanDato and assembles a signed .app bundle in build/.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
CONFIG="${1:-debug}"
NAME="BetterThanDato"
APP="build/$NAME.app"

swift build -c "$CONFIG" --product "$NAME"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
