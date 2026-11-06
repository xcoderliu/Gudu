#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
mkdir -p .local
bin_path="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$bin_path/Modules" \
  "$bin_path"/RippleCore.build/*.o Ripple/App/AppModel.swift \
  scripts/smoke_test.swift -o .local/smoke_test
.local/smoke_test
