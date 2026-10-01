#!/usr/bin/env bash
# Renders the demo video as motion graphics — no screen recording, no permissions, no personal data.
# The scenes (Tools/DemoVideo) are drawn in SwiftUI and driven by the app's real DatoCore logic with sample
# data, then encoded with ffmpeg (brew install ffmpeg).
# Output: docs/demo.mp4 (1080p) and docs/demo.gif (for the README; ordered dithering keeps it ~4 MB).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg" >&2; exit 1; }

# The Settings scene shows the latest release's version.
DEMO_VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
export DEMO_VERSION="${DEMO_VERSION:-0.0.0}"
swift run -c release DemoVideo docs/demo.mp4
ffmpeg -y -loglevel error -i docs/demo.mp4 \
  -vf "fps=12,scale=960:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=2:diff_mode=rectangle" \
  docs/demo.gif
ls -lh docs/demo.mp4 docs/demo.gif
