#!/bin/zsh
# Archive and export/upload Onto the Radio (iOS, tvOS, macOS) to App Store Connect / TestFlight.
# Requires an "Apple Distribution: Ian Todd (U87MQBZKJ5)" certificate in Keychain and
# an App Store Connect record for com.iantodd.ontotheradio / com.iantodd.ontotheradio.tv.
#
# Usage:
#   scripts/appstore-upload.sh archive     # builds signed .xcarchive bundles in build/archives/
#   scripts/appstore-upload.sh upload      # exports and uploads directly to App Store Connect
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-archive}"
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

echo "== archiving OntoTheRadioTV (tvOS)"
xcodebuild -project OntoTheRadio.xcodeproj -scheme OntoTheRadioTV \
  -configuration Release -destination 'generic/platform=tvOS' \
  -archivePath build/archives/OntoTheRadio-tvOS.xcarchive \
  -allowProvisioningUpdates archive

# Note: W40 workaround — Xcode's IDEDistributionCreateIPAStep runs /usr/bin/rsync -8aPhhE, which
# breaks if Homebrew rsync 3.5.x is first in PATH (--extended-attributes unknown). Keep system PATH
# for exportArchive.
if [[ "$MODE" == "upload" ]]; then
  PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
    -archivePath build/archives/OntoTheRadio-iOS.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist -exportPath build/export/ios -allowProvisioningUpdates
  PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
    -archivePath build/archives/OntoTheRadio-tvOS.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist -exportPath build/export/tvos -allowProvisioningUpdates
  echo "Uploaded iOS & tvOS builds to App Store Connect / TestFlight."
fi
