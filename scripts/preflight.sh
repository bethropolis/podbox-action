#!/usr/bin/env bash
# Verify the installed podbox can publish, and decide whether we may push.
#
# Env in:
#   INPUT_PUSH         auto | true | false          (default: auto)
#   GITHUB_EVENT_NAME  set by the runner
# Files out: push=true|false in $GITHUB_OUTPUT
# Exit: 0 ok; 1 podbox missing/too old/incompatible schema/bad input
#
# Contract (docs/clients.md): refuse a "schema" higher than 1, ignore unknown
# fields, and probe `features` rather than comparing versions. `publish`
# subsumes context emission (no separate `emit_context` feature exists).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

readonly SUPPORTED_SCHEMA=1
readonly REQUIRED_FEATURES=(publish)

require podbox
require jq

info="$(podbox info --output json)" || die "'podbox info --output json' failed"

schema="$(jq -r '.schema // empty' <<<"$info")"
[[ "$schema" =~ ^[0-9]+$ ]] || die "podbox info did not report a numeric schema"
if [ "$schema" -gt "$SUPPORTED_SCHEMA" ]; then
  die "podbox reports schema $schema; this action understands up to $SUPPORTED_SCHEMA. Upgrade the action."
fi

for feature in "${REQUIRED_FEATURES[@]}"; do
  if ! jq -e --arg f "$feature" '(.features // []) | index($f) != null' <<<"$info" >/dev/null; then
    die "this podbox does not support '$feature' (needed to publish). Use a newer podbox-version."
  fi
done

event="${GITHUB_EVENT_NAME:-}"
requested="${INPUT_PUSH:-auto}"
on_pr=false
case "$event" in
  pull_request | pull_request_target) on_pr=true ;;
esac

case "$requested" in
  auto) if [ "$on_pr" = true ]; then push=false; else push=true; fi ;;
  true)
    if [ "$on_pr" = true ]; then
      log_warn "push: true ignored on $event events; pull requests never push"
      push=false
    else
      push=true
    fi
    ;;
  false) push=false ;;
  *) die "invalid push input '$requested' (use auto, true or false)" ;;
esac

echo "podbox preflight ok (schema $schema, push=$push)"
set_output push "$push"
