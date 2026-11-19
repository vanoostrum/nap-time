#!/bin/bash
# Makes the Release archive of the scheme NapTime, signed ad hoc. The `Release` workflow exports and signs it,
# and `App (iOS)` checks it on each PR, so both use this one command (CRAFT-76).
# macOS only, after `xcodegen generate`. Usage: scripts/release-archive.sh <build number> <archive path>
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: scripts/release-archive.sh <build number> <archive path>" >&2
  exit 2
fi
build="$1"
archive="$2"

# Not signed by Xcode, so no run makes a development certificate. The build number goes to the app and the widget.
xcodebuild archive -project NapTime.xcodeproj -scheme NapTime -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION="$build"

# The export keeps only the entitlements that the archived code carries, and an unsigned bundle carries none
# (the first Release run lost iCloud, push, and the App Group). So sign ad hoc, with no certificate, with the
# entitlements files that `xcodegen generate` wrote. The export then signs again for App Store Connect, and
# switches aps-environment and the iCloud environment to production. Inner code first, the app last.
app="$archive/Products/Applications/NapTime.app"
for framework in "$app"/Frameworks/*; do
  if [ -e "$framework" ]; then
    codesign --force --sign - "$framework"
  fi
done
codesign --force --sign - --entitlements Widget/NapTimeWidget.entitlements "$app/PlugIns/NapTimeWidget.appex"
codesign --force --sign - --entitlements App/NapTime.entitlements "$app"
