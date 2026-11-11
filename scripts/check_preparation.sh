#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
mkdir -p .local
bin_path="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$bin_path/Modules" \
  "$bin_path"/GuduCore.build/*.o Gudu/App/AppModel.swift \
  Gudu/Views/DesignSystem.swift Gudu/Reminder/PreparationBubbleController.swift \
  scripts/check_preparation.swift -o .local/check_preparation
.local/check_preparation "$@"
