#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Gudu.xcodeproj -scheme Gudu -configuration Debug \
  -derivedDataPath build build
if [[ "${1:-}" == "--run" ]]; then
  open build/Build/Products/Debug/Gudu.app
fi
