# Sourced by the build and test scripts.
# The Command Line Tools for macOS 27 default to the macOS 27 SDK, where SwiftUI property wrappers such as
# @State are compiler macros whose plugin (SwiftUIMacros) ships only with Xcode. Without Xcode, build against
# the newest macOS 26 SDK the CLT still include. Set SDKROOT yourself to override.
if [[ "$(xcode-select -p)" == *CommandLineTools* && -z "${SDKROOT:-}" ]]; then
  CLT_SDK="$(/bin/ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1)"
  if [[ -n "$CLT_SDK" ]]; then
    export SDKROOT="$CLT_SDK"
  fi
fi
