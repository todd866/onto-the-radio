#!/bin/zsh
# Archive and export/upload Onto the Radio (iOS, optional tvOS) to App Store Connect / TestFlight.
# Requires Xcode Apple account / Apple Distribution signing for team U87MQBZKJ5.
#
# Usage:
#   scripts/appstore-upload.sh archive     # builds signed .xcarchive bundles in build/archives/
#   scripts/appstore-upload.sh upload      # exports and uploads iOS build (plus tvOS if registered)
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-archive}"
TARGET="${2:-ios}"
mkdir -p build/archives build/export

xcodegen generate --spec project.yml --project . >/dev/null

cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>U87MQBZKJ5</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>upload</string>
</dict>
</plist>
EOF

echo "== archiving OntoTheRadio (iOS)"
xcodebuild -project OntoTheRadio.xcodeproj -scheme OntoTheRadio \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/archives/OntoTheRadio-iOS.xcarchive \
  -allowProvisioningUpdates archive

if [[ "$TARGET" == "all" || "$TARGET" == "tvos" ]]; then
  echo "== archiving OntoTheRadioTV (tvOS)"
  xcodebuild -project OntoTheRadio.xcodeproj -scheme OntoTheRadioTV \
    -configuration Release -destination 'generic/platform=tvOS' \
    -archivePath build/archives/OntoTheRadio-tvOS.xcarchive \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    archive
fi

# W40 workaround: Xcode's IDEDistributionCreateIPAStep invokes /usr/bin/rsync -8aPhhE, which
# breaks if Homebrew rsync 3.5.x is first in PATH (--extended-attributes unknown).
if [[ "$MODE" == "upload" ]]; then
  echo "== uploading OntoTheRadio (iOS) to App Store Connect / TestFlight"
  PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
    -archivePath build/archives/OntoTheRadio-iOS.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath build/export/ios \
    -allowProvisioningUpdates
  if [[ "$TARGET" == "all" || "$TARGET" == "tvos" ]]; then
    PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
      -archivePath build/archives/OntoTheRadio-tvOS.xcarchive \
      -exportOptionsPlist build/ExportOptions.plist \
      -exportPath build/export/tvos \
      -allowProvisioningUpdates
  fi
  echo "Uploaded to App Store Connect / TestFlight."
fi
