#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
mkdir -p .local
bin_path="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$bin_path/Modules" \
  "$bin_path"/RippleCore.build/*.o \
  Ripple/App/AppModel.swift Ripple/Animation/*.swift Ripple/Views/*.swift \
  Ripple/Reminder/*.swift Ripple/Camera/*.swift scripts/check_completion.swift -o .local/check_completion
.local/check_completion
