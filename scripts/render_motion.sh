#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
mkdir -p .local
bin_path="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$bin_path/Modules" \
  "$bin_path"/GuduCore.build/*.o Gudu/Views/DesignSystem.swift \
  Gudu/Animation/DrinkingRitualScene.swift Gudu/Animation/ConfettiCelebrationView.swift scripts/render_motion.swift \
  -o .local/render_motion
.local/render_motion "$PWD/.local"
