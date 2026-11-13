#!/bin/bash
# Selects the Xcode in .xcode-version and prints an iPhone simulator with the newest iOS 27.x as SIMULATOR_ID.
# CI only. Usage: scripts/ci-select-xcode.sh >> "$GITHUB_ENV"
set -euo pipefail

version="$(tr -d '[:space:]' < .xcode-version)"
app="/Applications/Xcode_${version}.app"
if [ ! -d "$app" ]; then
  echo "No $app on this runner. Installed:" >&2
  ls -d /Applications/Xcode* >&2
  exit 1
fi
sudo xcode-select -s "$app/Contents/Developer"
xcodebuild -version >&2
swift --version >&2

udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, items in devices.items():
    if ".iOS-27-" not in runtime:
        continue
    minor = int(runtime.rsplit("-", 1)[-1]) if runtime.count("-") >= 2 else 0
    for d in items:
        if d["name"].startswith("iPhone") and (best is None or minor > best[0]):
            best = (minor, d["udid"], d["name"], runtime)
if best is None:
    sys.exit("No iPhone simulator with iOS 27 on this runner")
print(best[1])
print(best[2], best[3], file=sys.stderr)
')"
echo "SIMULATOR_ID=$udid"
