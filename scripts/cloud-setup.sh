#!/bin/bash
# Installs the Swift version in .swift-version on Ubuntu 24.04, without swiftly.
# It downloads the toolchain from download.swift.org, checks its PGP signature, and unpacks it
# into ~/.local/share/swift/<version>. scripts/verify.sh runs it when Swift is missing or wrong.
# CI runs it too. Runs from any folder: it finds the checkout from its own path. Safe to run again.
#
# Test-only environment variables:
#   SWIFT_KEYS_URL=<url>               replaces the URL of the swift.org signing keys.
#   SWIFT_SETUP_STOP_BEFORE_MARKER=1   exits with an error just before the done marker.
set -euo pipefail

sudo=""
if [ "$(id -u)" -ne 0 ]; then sudo="sudo"; fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_dir/.swift-version")"
swift_root="$HOME/.local/share/swift"
install_dir="$swift_root/$version"
# The marker is written only after every install step, so a stopped install never counts as done.
marker="$install_dir/.done"
keys_url="${SWIFT_KEYS_URL:-https://www.swift.org/keys/all-keys.asc}"

# Only Ubuntu 24.04 on x86_64 or aarch64: the cloud sessions and the Core (Linux) job.
os_id="$(. /etc/os-release 2> /dev/null && echo "${ID:-}-${VERSION_ID:-}")" || os_id="unknown"
arch="$(uname -m)"
case "$os_id/$arch" in
  ubuntu-24.04/x86_64) platform="ubuntu2404" suffix="ubuntu24.04" ;;
  ubuntu-24.04/aarch64) platform="ubuntu2404-aarch64" suffix="ubuntu24.04-aarch64" ;;
  *)
    echo "cloud-setup: this script supports only Ubuntu 24.04 on x86_64 or aarch64, not $os_id on $arch" >&2
    exit 1
    ;;
esac

# swift.org's package list for Ubuntu 24.04, plus curl for this script.
packages=(binutils git unzip gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev
  libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config
  tzdata zlib1g-dev curl)
missing=()
for package in "${packages[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$package" 2> /dev/null | grep -q "install ok installed"; then
    missing+=("$package")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "cloud-setup: installing the system packages that Swift needs: ${missing[*]}"
  $sudo apt-get update -qq
  $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
fi

# The exit trap deletes the download folder and the unpack folder, so a stopped run leaves nothing.
work=""
unpack=""
cleanup() { rm -rf "$work" "$unpack"; }
trap cleanup EXIT

if [ -f "$marker" ]; then
  echo "cloud-setup: Swift $version is installed"
else
  echo "cloud-setup: installing Swift $version from scratch"
  rm -rf "$install_dir"
  mkdir -p "$swift_root"
  work="$(mktemp -d)"

  # --compressed: the swift.org CDN sometimes sends the keys gzipped, also unasked (CRAFT-58).
  # A temporary keyring keeps the user's keyring unchanged.
  export GNUPGHOME="$work/gnupg"
  mkdir -m 700 "$GNUPGHOME"
  curl -fsSL --compressed "$keys_url" -o "$work/keys.asc"
  gpg --batch --quiet --import "$work/keys.asc"

  name="swift-$version-RELEASE"
  url="https://download.swift.org/swift-$version-release/$platform/$name/$name-$suffix.tar.gz"
  echo "cloud-setup: downloading $url"
  curl -fsSL "$url" -o "$work/swift.tar.gz"
  curl -fsSL "$url.sig" -o "$work/swift.tar.gz.sig"
  echo "cloud-setup: checking the signature"
  gpg --batch --verify "$work/swift.tar.gz.sig" "$work/swift.tar.gz"

  # Unpack next to the install folder, and move it into place only when the unpack is complete.
  unpack="$(mktemp -d "$swift_root/.unpack-$version.XXXXXX")"
  tar -xzf "$work/swift.tar.gz" -C "$unpack" --strip-components=1
  rm -f "$work/swift.tar.gz"
  mv "$unpack" "$install_dir"
  unpack=""
fi

# Every run: link the Swift tools into /usr/local/bin, which is on the PATH of every shell.
# Only swift, swiftc, and swift-*: the toolchain's clang and lldb stay out of the PATH.
# A real file is never replaced.
for tool in "$install_dir"/usr/bin/swift "$install_dir"/usr/bin/swiftc "$install_dir"/usr/bin/swift-*; do
  [ -f "$tool" ] || continue
  target="/usr/local/bin/$(basename "$tool")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then continue; fi
  $sudo ln -sfn "$tool" "$target"
done

# Remove what swiftly installs left behind: the swiftly link, links into the swiftly folder
# that the loop above did not replace, and the env.sh line. ~/.local/share/swiftly stays.
for link in /usr/local/bin/swift*; do
  if [ -L "$link" ] && { [ "$link" = /usr/local/bin/swiftly ] \
    || [[ "$(readlink "$link")" == "$HOME/.local/share/swiftly/"* ]]; }; then
    $sudo rm -f "$link"
  fi
done
profile_line=". \"$HOME/.local/share/swiftly/env.sh\""
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  if [ -f "$rc" ] && grep -qxF "$profile_line" "$rc"; then
    grep -vxF "$profile_line" "$rc" > "$rc.cloud-setup" || true
    cat "$rc.cloud-setup" > "$rc"
    rm -f "$rc.cloud-setup"
  fi
done

if [ "${SWIFT_SETUP_STOP_BEFORE_MARKER:-}" = "1" ]; then
  echo "cloud-setup: stopped before the done marker (SWIFT_SETUP_STOP_BEFORE_MARKER=1)" >&2
  exit 1
fi
touch "$marker"

"$install_dir/usr/bin/swift" --version
