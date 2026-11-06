#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Ripple.xcodeproj -scheme Ripple -configuration Debug \
  -derivedDataPath build build
if [[ "${1:-}" == "--run" ]]; then
  open build/Build/Products/Debug/Ripple.app
fi
