#!/bin/zsh
# Build, sign with Developer ID Application (U87MQBZKJ5), notarize via Apple notarytool,
# staple, and Gatekeeper-verify Onto the Radio for macOS.
# Usage: scripts/release-mac-notarized.sh [--install]
set -euo pipefail
cd "${0:A:h}/.."

# Optional local signing overrides outside git: ~/.config/onto-the-radio/release.env
[[ -f "$HOME/.config/onto-the-radio/release.env" ]] && source "$HOME/.config/onto-the-radio/release.env"

INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1
PROFILE="${ONTO_NOTARY_PROFILE:-notarytool}"
TEAM_ID="${ONTO_TEAM_ID:-U87MQBZKJ5}"
SIGN_ID="${ONTO_SIGN_ID:-Developer ID Application}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ontotheradio-release.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

xcodegen generate --spec project.yml --project . >/dev/null

echo "== build Release (macOS)"
xcodebuild \
  -project OntoTheRadio.xcodeproj \
  -scheme OntoTheRadioMac \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  build > "$WORK/build.log" 2>&1 || { tail -40 "$WORK/build.log"; exit 1; }

BUILT_APP="$WORK/DerivedData/Build/Products/Release/Onto the Radio.app"
APP="$WORK/Onto the Radio.app"
ditto "$BUILT_APP" "$APP"
codesign --force --deep --options runtime --timestamp \
  --entitlements App/OntoTheRadioMac.entitlements \
  --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$WORK/upload.zip"
echo "== notarize with Apple"
xcrun notarytool submit "$WORK/upload.zip" --keychain-profile "$PROFILE" --wait --output-format json > "$WORK/notary.json"

notary_status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$WORK/notary.json")
[[ "$notary_status" == "Accepted" ]] || { cat "$WORK/notary.json"; exit 1; }

xcrun stapler staple "$APP" >/dev/null
xcrun stapler validate "$APP" >/dev/null

echo "== quarantined Gatekeeper check"
ditto -c -k --keepParent "$APP" "$WORK/dl.zip"
mkdir "$WORK/dl"
ditto -x -k "$WORK/dl.zip" "$WORK/dl"
xattr -w com.apple.quarantine "0081;$(printf %x "$(date +%s)");Safari;" "$WORK/dl/Onto the Radio.app"
spctl -a -t exec "$WORK/dl/Onto the Radio.app"

mkdir -p build/release
[[ -e "build/release/Onto the Radio.app" ]] && trash "build/release/Onto the Radio.app"
ditto "$APP" "build/release/Onto the Radio.app"
echo "verified notarized release: build/release/Onto the Radio.app"

if (( INSTALL )); then
  [[ -e "/Applications/Onto the Radio.app" ]] && trash "/Applications/Onto the Radio.app"
  ditto "$APP" "/Applications/Onto the Radio.app"
  echo "installed: /Applications/Onto the Radio.app"
fi
