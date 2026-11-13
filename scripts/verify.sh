#!/bin/bash
# Local verify for Nap Time: lint, then build and test Core. Runs on Linux and macOS.
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

run "Swift version" swift --version
run "Lint" swift format lint --strict --recursive .
run "Build Core" swift build --package-path Packages/Core
run "Test Core" swift test --package-path Packages/Core
echo "verify: PASS"
