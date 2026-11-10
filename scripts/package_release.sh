#!/bin/zsh
# Build local artifacts only. This never signs with an account or publishes.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-unsigned}"
if [[ "$mode" != unsigned && "$mode" != adhoc ]]; then
  print -u2 'Usage: ./scripts/package_release.sh [unsigned|adhoc]'
  exit 2
fi
mkdir -p .local dist
xcodebuild -project Gudu.xcodeproj -scheme Gudu -configuration Release \
  -derivedDataPath build/distribution-arm64 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build > .local/release-build.log 2>&1
source_app="$PWD/build/distribution-arm64/Build/Products/Release/Gudu.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")
staging=$(mktemp -d "$PWD/.local/package-${mode}.XXXXXX")
trap 'rm -rf "$staging"' EXIT
folder="$staging/Gudu-${version}-${mode}"
mkdir -p "$folder"
ditto --noextattr --noqtn --norsrc "$source_app" "$folder/Gudu.app"
# The arm64 linker can add a signature even when Xcode signing is disabled.
# Strip that too: the unsigned artifact must actually be unsigned.
if codesign -dv "$folder/Gudu.app" > /dev/null 2>&1; then
  codesign --remove-signature "$folder/Gudu.app"
fi
cp LICENSE "$folder/LICENSE.txt"
cp Gudu/Gudu.entitlements "$folder/Gudu.entitlements"
if [[ "$mode" == adhoc ]]; then
  codesign --force --sign - --options runtime --entitlements Gudu/Gudu.entitlements "$folder/Gudu.app"
  codesign --verify --deep --strict "$folder/Gudu.app"
  codesign -dv "$folder/Gudu.app" 2>&1 | sed 's|^Executable=.*|Executable=Gudu.app/Contents/MacOS/Gudu|' > "$folder/SIGNATURE.txt"
  cat > "$folder/README.txt" <<'TEXT'
咕嘟 · Gudu — macOS 14+ / Apple Silicon (arm64)

This build has a local ad-hoc signature (Signature=adhoc, no Team ID).
It uses no Apple account, developer certificate, or provisioning profile,
and has not been notarized. It is NOT fully unsigned.

Drag Gudu.app into Applications. Gatekeeper may require approval in
System Settings > Privacy & Security. Do not disable Gatekeeper globally.
Only open a download whose source and SHA-256 checksum you trust.

Camera verification is experimental and ON for new installs. It starts only
at a reminder or explicit test; unavailable cameras allow manual confirmation.
It detects a vessel
near the remembered mouth position, not actual swallowing. Frames stay local.
The default schedule is Monday-Friday, 09:00-18:30, every 45 minutes, pointer
display, sound OFF, automatic dismissal OFF. Existing saved choices stay unchanged.
Login at startup is optional and must be enabled in the app.

Source: https://github.com/xcoderliu/Gudu
TEXT
else
  if codesign -dv "$folder/Gudu.app" > /dev/null 2>&1; then
    print -u2 'ERROR: unsigned artifact still has a signature'; exit 1
  fi
  cat > "$folder/README.txt" <<'TEXT'
咕嘟 · Gudu — FULLY UNSIGNED build
macOS 14+ / Apple Silicon arm64 only

This app has NO code signature, developer certificate, account, or notarization.
Apple Silicon requires at least an ad-hoc signature to execute arm64 code.
This fully unsigned artifact therefore cannot run natively as-is on Apple Silicon.

For a ready-to-test package without a developer certificate, choose the separate
adhoc ZIP. Alternatively, after extracting this folder, create a local signature:

  cd <this extracted folder>
  codesign --force --sign - --options runtime --entitlements Gudu.entitlements Gudu.app
  codesign --verify --deep --strict Gudu.app

Then copy Gudu.app to Applications. Gatekeeper approval may still be required
in System Settings > Privacy & Security. Do not disable Gatekeeper globally.
Only open downloads whose source and SHA-256 checksums you trust.

Camera verification is experimental and ON for new installs. App launch does
not start it; reminders/tests do. Unavailable cameras allow manual confirmation.
Frames stay local. The schedule defaults to Monday-Friday, 09:00-18:30, every
45 minutes on the pointer display, with sound and automatic dismissal OFF.
Source: https://github.com/xcoderliu/Gudu
TEXT
fi
archive="$PWD/dist/Gudu-${version}-macos-arm64-${mode}.zip"
ditto -c -k --sequesterRsrc --keepParent "$folder" "$archive"
shasum -a 256 "$archive" | sed "s|$PWD/dist/||" > "${archive}.sha256"
print "Prepared $archive"
cat "${archive}.sha256"
