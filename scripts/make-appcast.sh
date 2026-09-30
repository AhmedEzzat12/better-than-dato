#!/usr/bin/env bash
# Writes build/appcast.xml — the feed Sparkle checks — for one release, with the zip's EdDSA signature.
# Usage: scripts/make-appcast.sh <version> <build-number> <zip>
# Signs with the Sparkle key in your login keychain, or with $SPARKLE_PRIVATE_KEY when set (e.g. in CI).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$1"
BUILD="$2"
ZIP="$3"
REPO="${GITHUB_REPOSITORY:-AhmedEzzat12/better-than-dato}"
source scripts/sparkle-tools.sh

# Prints: sparkle:edSignature="…" length="…"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  # Piped in, never written to disk.
  ENCLOSURE_ATTRS="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" --ed-key-file - "$ZIP")"
else
  ENCLOSURE_ATTRS="$("$SPARKLE_BIN/sign_update" "$ZIP")"
fi
URL="https://github.com/$REPO/releases/download/v$VERSION/$(basename "$ZIP")"
PUB_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)"

mkdir -p build
cat > build/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Better Than Dato</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="$URL" type="application/octet-stream" $ENCLOSURE_ATTRS/>
    </item>
  </channel>
</rss>
EOF
echo "Wrote build/appcast.xml for $VERSION ($BUILD)"
