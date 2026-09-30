#!/usr/bin/env bash
# Publishes a release from this Mac — no GitHub Actions, nothing to pay for.
#   1. runs the tests and builds the universal app with version <version>
#   2. signs the update with your Sparkle key (login keychain; created on first run — Keychain may ask)
#   3. writes appcast.xml and creates GitHub release v<version> with the zip and appcast attached
# Installed copies find the new version through the appcast and update themselves.
#
# Usage: scripts/release.sh 1.2.0
# Optional: SIGN_IDENTITY="<code-signing certificate name>" keeps one identity across updates,
#           so macOS doesn't ask for Calendar/Reminders access again after each update.
#
# Back up the signing key once (losing it means installed copies can't verify future updates):
#   .build/sparkle-tools/*/bin/generate_keys -x ~/sparkle-private-key.txt   → then into a password manager
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?Usage: scripts/release.sh <version, e.g. 1.2.0>}"
TAG="v$VERSION"

if ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1; then
  echo "Install and sign in to the GitHub CLI first: brew install gh && gh auth login" >&2; exit 1
fi
if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  echo "This branch has no upstream on GitHub yet; publish the branch first." >&2; exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first." >&2; exit 1
fi
git fetch --quiet origin
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]]; then
  echo "Push your commits first — the release tag points at what's on GitHub." >&2; exit 1
fi
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists." >&2; exit 1
fi

source scripts/sparkle-tools.sh
"$SPARKLE_BIN/generate_keys" >/dev/null
export SPARKLE_PUBLIC_KEY="$("$SPARKLE_BIN/generate_keys" -p)"
export APP_VERSION="$VERSION"
# Sparkle compares build numbers; the commit count only ever grows on main.
export BUILD_NUMBER="$(git rev-list --count HEAD)"

scripts/test.sh
scripts/build-app.sh release
# Stable asset name so releases/latest/download/BetterThanDato.zip always points at the newest build.
ZIP="build/BetterThanDato.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/BetterThanDato.app "$ZIP"
scripts/make-appcast.sh "$VERSION" "$BUILD_NUMBER" "$ZIP"

gh release create "$TAG" "$ZIP" build/appcast.xml \
  --target "$(git rev-parse HEAD)" --title "Better Than Dato $VERSION" --generate-notes
echo "Published $TAG"
