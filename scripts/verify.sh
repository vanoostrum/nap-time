#!/bin/bash
# Local verify for Nap Time: lint, build and test Core, then test the CI change script. Runs on Linux and macOS.
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
install_dir="$HOME/.local/share/swift/$version"

# Swift is at the right version when it prints "Swift version <v>", with no more digits or dots
# after <v>, and cloud-setup.sh has written its done marker for <v>.
swift_is_right() {
  local out
  out="$(swift --version 2>&1)" || return 1
  [ -f "$install_dir/.done" ] \
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
    export PATH="$install_dir/usr/bin:$PATH"
  fi
  run "Swift version" check_swift
else
  run "Swift version" swift --version
fi
run "Lint" swift format lint --strict --recursive .
run "Build Core" swift build --package-path Packages/Core
run "Test Core" swift test --package-path Packages/Core
run "Test the change script" env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts -p 'test_*.py'
echo "verify: PASS"
