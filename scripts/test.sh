#!/usr/bin/env bash
# Runs the test suite. The Command Line Tools ship Swift Testing but SwiftPM
# doesn't find it on its own, so pass the framework, macro plugin and runtime paths explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
DEV_DIR="$(xcode-select -p)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  FW="$DEV_DIR/Library/Developer/Frameworks"
  LIB="$DEV_DIR/Library/Developer/usr/lib"
  PLUGINS="$DEV_DIR/usr/lib/swift/host/plugins/testing"
  exec swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xswiftc -plugin-path -Xswiftc "$PLUGINS" \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$LIB" \
    "$@"
fi
exec swift test "$@"
