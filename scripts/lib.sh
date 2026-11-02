#!/usr/bin/env bash
# Shared helpers. Source this file; do not execute it.
#
# Functions:
#   log_group NAME / log_endgroup   fold log output (::group:: / ::endgroup::)
#   log_error MSG / log_warn MSG    annotations
#   die MSG [CODE]                  log_error and exit CODE (default 1)
#   require CMD                     die unless CMD is on PATH
#   mask VALUE                      ::add-mask:: a secret-ish value
#   set_output NAME VALUE           single-line step output
#   set_output_multiline NAME VALUE step output safe for any content
#
# Note: sourcing scripts own `set -euo pipefail`; this file sets nothing.

log_group() { printf '::group::%s\n' "$1"; }
log_endgroup() { printf '::endgroup::\n'; }
log_error() { printf '::error::%s\n' "$1" >&2; }
log_warn() { printf '::warning::%s\n' "$1" >&2; }

die() {
  log_error "$1"
  exit "${2:-1}"
}

require() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found on PATH: $1"
}

mask() {
  printf '::add-mask::%s\n' "$1"
}

set_output() {
  printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT:-/dev/null}"
}

set_output_multiline() {
  local name="$1" value="$2" delim
  delim="PODBOX_EOF_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  {
    printf '%s<<%s\n' "$name" "$delim"
    printf '%s\n' "$value"
    printf '%s\n' "$delim"
  } >>"${GITHUB_OUTPUT:-/dev/null}"
}
