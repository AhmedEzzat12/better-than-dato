#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh debug
./scripts/quit-running.sh
open build/BetterThanDato.app
