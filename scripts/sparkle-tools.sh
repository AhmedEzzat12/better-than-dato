# Sourced by make-appcast.sh and setup-updates.sh. Downloads Sparkle's command-line tools
# (sign_update, generate_keys) once and exports SPARKLE_BIN. Keep the version in step with Package.resolved.
SPARKLE_VERSION="2.10.0"
SPARKLE_TOOLS=".build/sparkle-tools/$SPARKLE_VERSION"
if [[ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]]; then
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS"
fi
export SPARKLE_BIN="$SPARKLE_TOOLS/bin"
