#!/bin/bash
# Local verify for Nap Time: lint, then build and test Core. Runs on Linux and macOS.
# On Linux, it first installs the Swift version in .swift-version when Swift is missing or wrong.
# Prints the first failed step. Usage: scripts/verify.sh
set -uo pipefail
cd "$(dirname "$0")/.."

run() {
  local name="$1"
  shift
  echo "== $name: $*"
  if ! "$@"; then
    echo "verify: FAIL at step '$name'"
    exit 1
  fi
}

version="$(tr -d '[:space:]' < .swift-version)"
swiftly_dir="$HOME/.local/share/swiftly"

# Swift is at the right version when it prints "Swift version <v>", with no more digits or dots
# after <v>, and cloud-setup.sh has written its done marker for <v>.
swift_is_right() {
  local out
  out="$(swift --version 2>&1)" || return 1
  [ -f "$swiftly_dir/.done-$version" ] \
    && grep -Eq "Swift version ${version//./\\.}([^0-9.]|$)" <<< "$out"
}

check_swift() {
  swift --version || return 1
  if ! swift_is_right; then
    echo "verify: need Swift $version from scripts/cloud-setup.sh"
    return 1
  fi
}

if [ "$(uname -s)" = "Linux" ]; then
  if ! swift_is_right; then
    run "Install Swift" bash scripts/cloud-setup.sh
    export PATH="$swiftly_dir/bin:$PATH"
  fi
  run "Swift version" check_swift
else
  run "Swift version" swift --version
fi
run "Lint" swift format lint --strict --recursive .
run "Build Core" swift build --package-path Packages/Core
run "Test Core" swift test --package-path Packages/Core
echo "verify: PASS"
