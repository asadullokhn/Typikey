#!/bin/bash
# Archive, sign, upload and hand the build to TestFlight.
#
# Signing does not touch Xcode's account: it uses the Apple Distribution
# certificate in the keychain and the four App Store profiles created from
# the App Store Connect API key. That is the whole point — the cloud-signing
# path this replaced depended on an Apple ID session that expires silently
# and is invisible to CI, which is how build 54 came to be stuck.
#
#   ./Tools/release/ship.sh            archive, upload, external review
#   ./Tools/release/ship.sh --internal upload, internal testers only
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${ASC_KEY_ID:=YBPKW7X9FV}"
: "${ASC_ISSUER_ID:=980e538b-542f-4311-b6be-3bf4306a0b7f}"
: "${ASC_APP_ID:=6798125679}"
EXTERNAL_GROUP=7c48964c-1fcb-4077-a05d-ef64b905b307
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

internal_only=false
[[ "${1:-}" == "--internal" ]] && internal_only=true

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
version=$(grep -m1 CURRENT_PROJECT_VERSION project.yml | tr -dc '0-9')
echo "==> Typikey build $version"

echo "==> archiving"
xcodebuild archive -project Typikey.xcodeproj -scheme Typikey \
  -destination 'generic/platform=iOS' -archivePath "$work/Typikey.xcarchive" \
  -quiet

echo "==> exporting"
xcodebuild -exportArchive -archivePath "$work/Typikey.xcarchive" \
  -exportOptionsPlist Tools/release/ExportOptions.plist \
  -exportPath "$work/export" -quiet

echo "==> uploading"
xcrun altool --upload-app -f "$work/export/Typikey.ipa" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "==> waiting for processing"
build_id=$(python3 Tools/release/testflight.py await "$version")
echo "    build $version is $build_id"

python3 Tools/release/testflight.py notes "$build_id"
if [[ "$internal_only" == false ]]; then
  python3 Tools/release/testflight.py external "$build_id" "$EXTERNAL_GROUP"
fi
python3 Tools/release/testflight.py status "$build_id"
