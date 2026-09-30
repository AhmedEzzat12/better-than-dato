#!/usr/bin/env bash
# Builds Better Than Dato from source and installs it in place of any installed copy.
# For Macs where downloaded apps are blocked (e.g. managed by an organization), or to run unreleased code.
#
# Usage: scripts/update-from-source.sh          # latest release tag (tested code)
#        scripts/update-from-source.sh --main   # tip of main (unreleased changes)
#
# Needs the Command Line Tools (xcode-select --install). Your settings are kept.
# Source builds don't auto-update; run this again to update.
# Self-cleaning: it builds in a temporary checkout that is deleted when the script ends — on success,
# failure or Ctrl-C — so nothing is left in the repo or on disk except the installed app.
# Optional env:
#   SIGN_IDENTITY  code-signing certificate name; keeps Calendar/Reminders access across rebuilds
#                  (otherwise macOS asks again after each rebuild — see README)
#   INSTALL_DIR    where to install (default ~/Applications, no admin rights needed)
#   NO_LAUNCH=1    don't open the app afterwards
set -euo pipefail
cd "$(dirname "$0")/.."

USE_MAIN=0
case "${1:-}" in
  --main) USE_MAIN=1 ;;
  "") ;;
  *) echo "Usage: $0 [--main]" >&2; exit 1 ;;
esac

APP="BetterThanDato.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/better-than-dato-build.XXXXXX")"
BUILD_TREE="$WORK/src"

remove_checkout() {
  git worktree remove --force "$1" 2>/dev/null || rm -rf "$1"
}
cleanup() {
  remove_checkout "$BUILD_TREE"
  rm -rf "$WORK"
  git worktree prune
}
trap cleanup EXIT

# Older versions of this script kept a build checkout here; reclaim it.
if [[ -e .build/source-build ]]; then
  remove_checkout .build/source-build
fi

echo "==> Updating from GitHub"
git fetch --quiet --tags origin
# Bring the local repo up to date when that can't disturb your work.
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" && -z "$(git status --porcelain)" ]]; then
  git merge --quiet --ff-only origin/main && echo "    local main is up to date"
else
  echo "    (not on a clean main — leaving your working copy as it is)"
fi

LATEST_TAG="$(git tag --list 'v*' --sort=-v:refname | head -1)"
if [[ "$USE_MAIN" == "1" || -z "$LATEST_TAG" ]]; then
  REF="origin/main"
  APP_VERSION="${LATEST_TAG#v}"
  APP_VERSION="${APP_VERSION:-0.0.0}+main.$(git rev-parse --short origin/main)"
else
  REF="$LATEST_TAG"
  APP_VERSION="${LATEST_TAG#v}"
fi
echo "==> Building $APP_VERSION from $REF"

# A throwaway checkout keeps your working copy untouched.
git worktree prune
git worktree add --quiet --detach "$BUILD_TREE" "$REF"

(
  cd "$BUILD_TREE"
  # Host architecture only (faster); source builds carry no update key, so they never self-update.
  unset SPARKLE_PUBLIC_KEY
  APP_VERSION="$APP_VERSION" BUILD_NUMBER="$(git rev-list --count HEAD)" UNIVERSAL=0 \
    scripts/build-app.sh release
)

echo "==> Replacing installed copies"
"$BUILD_TREE/scripts/quit-running.sh"
for dir in /Applications "$HOME/Applications"; do
  if [[ -e "$dir/$APP" && "$dir" != "$INSTALL_DIR" ]]; then
    if rm -rf "${dir:?}/$APP" 2>/dev/null; then
      echo "    removed $dir/$APP"
    else
      echo "    couldn't remove $dir/$APP (needs admin rights) — delete it in Finder to avoid two copies" >&2
    fi
  fi
done
mkdir -p "$INSTALL_DIR"
# Copy next to the old app first and swap only once the copy succeeded.
STAGED="$INSTALL_DIR/.$APP.new"
rm -rf "$STAGED"
ditto "$BUILD_TREE/build/$APP" "$STAGED"
rm -rf "${INSTALL_DIR:?}/$APP"
mv "$STAGED" "$INSTALL_DIR/$APP"
echo "    installed $INSTALL_DIR/$APP ($APP_VERSION)"

if [[ "${NO_LAUNCH:-0}" != "1" ]]; then
  open "$INSTALL_DIR/$APP"
fi
echo "Done. If macOS asks for Calendar/Reminders access again, allow it (the app was rebuilt)."
echo "If you use Launch at login and the app moved folders, turn it off and on again in Settings."
