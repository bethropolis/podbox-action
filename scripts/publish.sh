#!/usr/bin/env bash
# Run `podbox publish`, parse its ndjson event stream, set step outputs and
# render the job summary. All decisions (tags, refs, skipping) belong to the
# podbox CLI; this script only translates inputs to flags and events to outputs.
#
# Env in:
#   PUSH            true | false   (from preflight; default false)
#   INPUT_ONLY      space-separated image keys           (default: all)
#   INPUT_IMAGES    manifest path; empty = CLI discovery
#   INPUT_REGISTRY  registry host                        (default: CLI default)
#   INPUT_FORCE     true | false                         (default false)
#   INPUT_WORKDIR   directory to run in                  (default .)
# Files out: outputs images (JSON array), pushed, skipped in $GITHUB_OUTPUT;
#            markdown appended to $GITHUB_STEP_SUMMARY
# Exit: podbox's exit code; 1 if podbox succeeded but an image event failed
#
# Event contract (see PROJECT_GUIDE.md section 1.6):
#   {"schema":1,"event":"image","key":..,"ref":..,"digest":..,"tags":[..],
#    "pushed":bool,"skipped":bool,"first_push":bool,"error":"msg"?}
#   {"schema":1,"event":"done",...}
#   {"schema":1,"error":{"code":..,"message":..}}   (terminal failure)
# Unknown events are ignored; unknown fields are ignored.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

require podbox
require jq

push="${PUSH:-false}"
case "$push" in
  true | false) ;;
  *) die "invalid PUSH value '$push' (expected true or false)" ;;
esac

workdir="${INPUT_WORKDIR:-.}"
cd "$workdir" || die "working-directory not found: $workdir"

common=(--ci github)
if [ -n "${INPUT_IMAGES:-}" ]; then
  common+=(--manifest "$INPUT_IMAGES")
fi
if [ -n "${INPUT_REGISTRY:-}" ]; then
  common+=(--registry "$INPUT_REGISTRY")
fi

keys=()
if [ -n "${INPUT_ONLY:-}" ]; then
  read -r -a keys <<<"$INPUT_ONLY"
fi

# Show the resolved plan first so a bad ref is visible before any build.
log_group "podbox publish plan"
podbox publish --list "${common[@]}" ${keys[@]+"${keys[@]}"} --output json \
  || log_warn "could not print the publish plan (continuing)"
log_endgroup

args=(publish "${common[@]}" ${keys[@]+"${keys[@]}"} --output ndjson)
if [ "$push" = true ]; then
  args+=(--push)
else
  args+=(--no-push)
fi
if [ "${INPUT_FORCE:-false}" = true ]; then
  args+=(--force)
fi

events="$(mktemp)"
trap 'rm -f "$events"' EXIT

set +e
podbox "${args[@]}" | while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  if jq -e 'type == "object"' >/dev/null 2>&1 <<<"$line"; then
    printf '%s\n' "$line" >>"$events"
    jq -r '
      if .event == "image" then
        "• \(.key): \(.ref) — \(if .error then "FAILED: " + .error elif .skipped then "skipped (unchanged)" elif .pushed then "pushed" else "built, not pushed" end)"
      elif (.event | not) and .error then
        "::error::\(.error.message // "podbox reported an error")"
      else empty end' <<<"$line"
  else
    log_warn "non-JSON line on podbox stdout (ignored): $line"
  fi
done
rc=${PIPESTATUS[0]}
set -e

images="$(jq -sc '
  [ .[] | select(.event == "image")
    | { key, ref, digest, tags,
        pushed: (.pushed // false),
        skipped: (.skipped // false),
        first_push: (.first_push // false),
        error: (.error // null) } ]' "$events")"

pushed="$(jq 'map(select(.pushed == true and .error == null)) | length' <<<"$images")"
skipped="$(jq 'map(select(.skipped == true and .error == null)) | length' <<<"$images")"
failed="$(jq 'map(select(.error != null)) | length' <<<"$images")"

set_output_multiline images "$images"
set_output pushed "$pushed"
set_output skipped "$skipped"

"$here/summary.sh" "$events" || log_warn "could not render the job summary"

if [ "$rc" -ne 0 ]; then
  exit "$rc"
fi
if [ "$failed" -gt 0 ]; then
  die "$failed image(s) failed to publish"
fi
