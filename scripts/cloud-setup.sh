#!/bin/bash
# Installs swiftly and the Swift version in .swift-version, on Linux.
# scripts/verify.sh runs it when Swift is missing or wrong. CI runs it too.
# Runs from any folder: it finds the checkout from its own path. Safe to run again.
set -euo pipefail

sudo=""
if [ "$(id -u)" -ne 0 ]; then sudo="sudo"; fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_dir/.swift-version")"
export SWIFTLY_HOME_DIR="$HOME/.local/share/swiftly"
export SWIFTLY_BIN_DIR="$SWIFTLY_HOME_DIR/bin"
export PATH="$SWIFTLY_BIN_DIR:$PATH"
# The marker is written only after every install step, so a stopped install never counts as done.
marker="$SWIFTLY_HOME_DIR/.done-$version"

if [ -f "$marker" ]; then
  echo "cloud-setup: Swift $version is installed"
else
  echo "cloud-setup: installing swiftly and Swift $version from scratch"
  rm -rf "$SWIFTLY_HOME_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz" -o "$tmp/swiftly.tar.gz"
  tar -xzf "$tmp/swiftly.tar.gz" -C "$tmp"
  "$tmp/swiftly" init --assume-yes --quiet-shell-followup --skip-install --no-modify-profile
  rm -rf "$tmp"

  post_install="$(mktemp)"
  "$SWIFTLY_BIN_DIR/swiftly" install --assume-yes --use --post-install-file "$post_install" "$version"
  if [ -s "$post_install" ]; then
    echo "cloud-setup: installing the system packages that Swift needs"
    $sudo apt-get update -qq
    $sudo bash "$post_install"
  fi
  rm -f "$post_install"
  touch "$marker"
fi
# --assume-yes lets swiftly repair a broken tool link in its bin folder.
"$SWIFTLY_BIN_DIR/swiftly" use --global-default --assume-yes "$version" > /dev/null

# Non-interactive shells skip ~/.bashrc, so also link the Swift tools into /usr/local/bin.
for tool in "$SWIFTLY_BIN_DIR"/swift "$SWIFTLY_BIN_DIR"/swiftc "$SWIFTLY_BIN_DIR"/swiftly "$SWIFTLY_BIN_DIR"/swift-*; do
  name="$(basename "$tool")"
  target="/usr/local/bin/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then continue; fi
  $sudo ln -sf "$tool" "$target"
done

profile_line=". \"$SWIFTLY_HOME_DIR/env.sh\""
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  touch "$rc"
  grep -qxF "$profile_line" "$rc" || printf '\n%s\n' "$profile_line" >> "$rc"
done

swift --version
