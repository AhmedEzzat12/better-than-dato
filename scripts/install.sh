#!/usr/bin/env bash
# Release build copied to ~/Applications (a stable path for launch at login).
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh release
./scripts/quit-running.sh
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/BetterThanDato.app"
cp -R build/BetterThanDato.app "$HOME/Applications/"
open "$HOME/Applications/BetterThanDato.app"
