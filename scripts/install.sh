#!/usr/bin/env bash
# Install a pinned podbox release by running podbox's own online installer
# from the SAME tag, then put it on PATH.
#
# Env in:
#   PODBOX_VERSION  "latest" or a tag like v0.10.0 / 0.10.0   (default: latest)
#   RUNNER_TEMP     scratch dir                                (default: mktemp)
#   GITHUB_PATH     file the runner reads to extend PATH
#   GITHUB_TOKEN    optional; only used to avoid API rate limits
#   Test/override hooks (not action inputs):
#     PODBOX_REPO  (bethropolis/podbox)  PODBOX_API  (https://api.github.com)
#     PODBOX_RAW   (https://raw.githubusercontent.com)  UNAME_M  (uname -m)
# Files out: $RUNNER_TEMP/podbox/bin/podbox; appends bin dir to $GITHUB_PATH
# Exit: 0 ok; 1 any failure (fails closed, PATH untouched)
#
# DISCOVERY (verified against podbox's scripts/install-online.sh, served at
# https://bethropolis.github.io/podbox/install.sh):
#   * Release asset:   podbox-{TAG}-linux-{ARCH}.tar.gz   (ARCH: x86_64 | arm64)
#   * Checksum file:   checksums.txt at the same release download URL
#   * Checksum verified: yes — sha256sum -c -, hard-fails when no entry matches
#   * Env vars honored by the installer:
#       PODBOX_BINDIR   install dir   (default: ~/.local/bin)
#       PODBOX_VERSION  tag, with or without leading "v" (normalized to vX.Y.Z)
#       PODBOX_FORCE    1 to reinstall even when already up to date
#   * Arch mapping in the installer: x86_64 -> x86_64, aarch64|arm64 -> arm64
#   * The installer itself downloads from GitHub releases (not raw.githubusercontent).
#   * We validate the arch here and let the installer detect it (same runner).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

repo="${PODBOX_REPO:-bethropolis/podbox}"
api="${PODBOX_API:-https://api.github.com}"
raw="${PODBOX_RAW:-https://raw.githubusercontent.com}"
version="${PODBOX_VERSION:-latest}"
arch="${UNAME_M:-$(uname -m)}"

require curl
require jq

case "$arch" in
  x86_64 | aarch64 | arm64) ;;
  *) die "unsupported architecture: $arch (podbox publishes Linux x86_64 and arm64 only)" ;;
esac

if [ "$version" = "latest" ]; then
  auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  body="$(curl -fsSL --retry 3 --retry-delay 2 ${auth[@]+"${auth[@]}"} \
    -H 'Accept: application/vnd.github+json' \
    "$api/repos/$repo/releases/latest")" || die "could not resolve the latest podbox release"
  tag="$(jq -r '.tag_name // empty' <<<"$body")"
  [ -n "$tag" ] || die "latest release response had no tag_name"
else
  if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    tag="v${version#v}"
  else
    die "invalid podbox-version '$version' (use 'latest' or a tag like v0.10.0)"
  fi
fi

tmp="${RUNNER_TEMP:-$(mktemp -d)}"
bindir="$tmp/podbox/bin"
mkdir -p "$bindir" "$tmp/podbox/dl"
installer="$tmp/podbox/dl/install-online.sh"

log_group "Installing podbox $tag"
curl -fsSL --retry 3 --retry-delay 2 -o "$installer" \
  "$raw/$repo/$tag/scripts/install-online.sh" \
  || die "could not download the podbox installer for $tag"

PODBOX_BINDIR="$bindir" PODBOX_VERSION="$tag" PODBOX_FORCE=1 sh "$installer" \
  || die "podbox installer failed for $tag"
log_endgroup

[ -x "$bindir/podbox" ] || die "installer finished but $bindir/podbox is missing"

"$bindir/podbox" --version
printf '%s\n' "$bindir" >>"${GITHUB_PATH:-/dev/null}"
set_output version "$tag"
