#!/bin/bash
# Installs (or reinstalls) the latest Better Than Dato release.
#
#   curl -fsSL https://raw.githubusercontent.com/AhmedEzzat12/better-than-dato/main/scripts/install-latest.sh | bash
#
# The app isn't notarized by Apple, so a copy downloaded in a browser gets the quarantine flag and macOS
# refuses to open it ("Apple could not verify…"). curl doesn't set that flag, and this script clears it
# anyway, so the app opens straight away. Later updates arrive in-app (Sparkle) and aren't quarantined either.
#
# Optional: INSTALL_DIR (default /Applications, falls back to ~/Applications), NO_LAUNCH=1.
set -euo pipefail

REPO="AhmedEzzat12/better-than-dato"
APP="BetterThanDato.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
if [[ ! -w "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading the latest Better Than Dato…"
curl -fsSL -o "$WORK/app.zip" "https://github.com/$REPO/releases/latest/download/BetterThanDato.zip"
ditto -x -k "$WORK/app.zip" "$WORK"
xattr -dr com.apple.quarantine "$WORK/$APP" 2>/dev/null || true

# Quit a running copy and wait for it to exit, so the new one really launches.
if pgrep -x BetterThanDato >/dev/null; then
  pkill -x BetterThanDato || true
  for _ in $(seq 50); do pgrep -x BetterThanDato >/dev/null || break; sleep 0.1; done
fi

# Copy next to the old app first and swap only once the copy succeeded.
STAGED="$INSTALL_DIR/.$APP.new"
rm -rf "$STAGED"
ditto "$WORK/$APP" "$STAGED"
rm -rf "${INSTALL_DIR:?}/$APP"
mv "$STAGED" "$INSTALL_DIR/$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_DIR/$APP/Contents/Info.plist")"
echo "Installed Better Than Dato $VERSION in $INSTALL_DIR"

if [[ "${NO_LAUNCH:-0}" != "1" ]]; then
  open "$INSTALL_DIR/$APP"
  echo "Look for the calendar icon in the menu bar, then click it → Grant Access."
fi
