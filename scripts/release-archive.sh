#!/bin/bash
# Makes the unsigned Release archive of the scheme NapTime. The `Release` workflow exports and signs it,
# and `App (iOS)` checks it on each PR, so both use this one command (CRAFT-76).
# macOS only, after `xcodegen generate`. Usage: scripts/release-archive.sh <build number> <archive path>
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: scripts/release-archive.sh <build number> <archive path>" >&2
  exit 2
fi
build="$1"
archive="$2"

# Unsigned, so no run makes a development certificate. The build number goes to the app and the widget.
xcodebuild archive -project NapTime.xcodeproj -scheme NapTime -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION="$build"
