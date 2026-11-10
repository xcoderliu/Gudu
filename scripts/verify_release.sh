#!/bin/zsh
# Read/extract local artifacts for review; never launch or publish them.
set -euo pipefail
cd "$(dirname "$0")/.."
staging=$(mktemp -d "$PWD/.local/verify-release.XXXXXX")
trap 'rm -rf "$staging"' EXIT
if (( $# == 0 )); then set -- unsigned; fi
for mode in "$@"; do
  [[ "$mode" == unsigned || "$mode" == adhoc ]] || exit 2
  archive="Gudu-0.1.0-macos-arm64-${mode}.zip"
  (cd dist && shasum -a 256 -c "${archive}.sha256")
  mkdir -p "$staging/$mode"
  ditto -x -k "dist/$archive" "$staging/$mode"
  app="$staging/$mode/Gudu-0.1.0-${mode}/Gudu.app"
  info="$app/Contents/Info.plist"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$info")" == '咕嘟' ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")" == '0.1.0' ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info")" == '14.0' ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")" == 'local.ripple.WaterReminder' ]]
  executable="$app/Contents/MacOS/Gudu"
  architectures=$(lipo -archs "$executable")
  [[ "$architectures" == arm64 ]]
  [[ ! -f "$app/Contents/embedded.provisionprofile" ]]
  if [[ "$mode" == adhoc ]]; then
    codesign --verify --deep --strict "$app"
    codesign -dv "$app" 2> "$staging/signature.txt"
    /usr/bin/grep -q '^Signature=adhoc$' "$staging/signature.txt"
    /usr/bin/grep -q '^TeamIdentifier=not set$' "$staging/signature.txt"
    codesign -d --entitlements :- "$app" > "$staging/entitlements.plist" 2>/dev/null
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$staging/entitlements.plist" | /usr/bin/grep -q '^true$'
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.camera' "$staging/entitlements.plist" | /usr/bin/grep -q '^true$'
  else
    for architecture in arm64; do
      if codesign -dv --arch "$architecture" "$app" > /dev/null 2> "$staging/unsigned.txt"; then
        print -u2 "ERROR: unsigned $architecture slice is still signed"; exit 1
      fi
      /usr/bin/grep -q 'code object is not signed at all' "$staging/unsigned.txt"
    done
    # Verify the exact local-signing instructions shipped with the unsigned
    # package, using only the temporary extracted copy, never the ZIP itself.
    codesign --force --sign - --options runtime \
      --entitlements "$staging/$mode/Gudu-0.1.0-${mode}/Gudu.entitlements" "$app"
    codesign --verify --deep --strict "$app"
  fi
  print "PASS: $mode — 咕嘟 0.1.0, macOS 14+, $architectures, correct signature state"
done
