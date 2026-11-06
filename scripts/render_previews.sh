#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
mkdir -p .local
bin_path="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$bin_path/Modules" \
  "$bin_path"/RippleCore.build/*.o \
  Ripple/App/AppModel.swift Ripple/Animation/*.swift Ripple/Views/*.swift \
  Ripple/Reminder/*.swift Ripple/Camera/*.swift scripts/render_previews.swift -o .local/render_previews
.local/render_previews "${1:-$PWD/docs/images}"
