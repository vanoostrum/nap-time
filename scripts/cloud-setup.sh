#!/bin/bash
# Cloud setup for Nap Time on the shared "Craft" environment.
# Runs from the directory that holds the repository checkouts.
# Installs swiftly and the Swift version in nap-time/.swift-version.
# Does nothing when the nap-time checkout is missing. Safe to run again.
set -euo pipefail

sudo=""
if [ "$(id -u)" -ne 0 ]; then sudo="sudo"; fi

repo="nap-time"
if [ ! -f "$repo/.swift-version" ]; then
  echo "cloud-setup: no $repo checkout here, nothing to do"
  exit 0
fi

version="$(tr -d '[:space:]' < "$repo/.swift-version")"
export SWIFTLY_HOME_DIR="$HOME/.local/share/swiftly"
export SWIFTLY_BIN_DIR="$SWIFTLY_HOME_DIR/bin"
export PATH="$SWIFTLY_BIN_DIR:$PATH"

if command -v swiftly > /dev/null; then
  echo "cloud-setup: swiftly is installed"
else
  echo "cloud-setup: installing swiftly"
  tmp="$(mktemp -d)"
  curl -fsSL "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz" -o "$tmp/swiftly.tar.gz"
  tar -xzf "$tmp/swiftly.tar.gz" -C "$tmp"
  "$tmp/swiftly" init --assume-yes --quiet-shell-followup --skip-install --no-modify-profile
  rm -rf "$tmp"
fi

if swiftly list 2> /dev/null | grep -F "Swift $version" > /dev/null; then
  echo "cloud-setup: Swift $version is installed"
else
  echo "cloud-setup: installing Swift $version"
  post_install="$(mktemp)"
  swiftly install --assume-yes --use --post-install-file "$post_install" "$version"
  if [ -s "$post_install" ]; then
    echo "cloud-setup: installing the system packages that Swift needs"
    $sudo apt-get update -qq
    $sudo bash "$post_install"
  fi
  rm -f "$post_install"
fi
swiftly use --global-default "$version" > /dev/null

profile_line=". \"$SWIFTLY_HOME_DIR/env.sh\""
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  touch "$rc"
  grep -qxF "$profile_line" "$rc" || printf '\n%s\n' "$profile_line" >> "$rc"
done

swift --version
