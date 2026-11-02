#!/usr/bin/env bash
# Render the job summary from a file of podbox ndjson events.
#
# Usage: summary.sh EVENTS_FILE
# Env in: GITHUB_STEP_SUMMARY (default: stdout)
# Output: markdown with a results table, `podbox create` lines for pushed
#         images, a first-publish visibility reminder, and failures.
# Exit: 0 ok; 1 on usage error
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

require jq

events="${1:-}"
if [ -z "$events" ] || [ ! -f "$events" ]; then
  die "usage: summary.sh EVENTS_FILE"
fi
out="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

image_count="$(jq -s '[.[] | select(.event == "image")] | length' "$events")"
err="$(jq -rs '[.[] | select(.error != null and .event == null) | .error.message] | first // empty' "$events")"

mapfile -t uses < <(jq -r '
  select(.event == "image" and .pushed == true and .error == null)
  | "\(.ref):\(((.tags // [])[0]) // "latest")"' "$events")

mapfile -t first_pushes < <(jq -r '
  select(.event == "image" and .first_push == true and .error == null) | .ref' "$events")

mapfile -t failures < <(jq -r '
  select(.event == "image" and .error != null) | "\(.key): \(.error)"' "$events")

{
  echo "## podbox images"
  echo

  if [ -n "$err" ]; then
    echo "**Error:** $err"
    echo
  fi

  if [ "$image_count" -eq 0 ]; then
    echo "_No images were built._"
  else
    echo "| Image | Ref | Digest | Status |"
    echo "|---|---|---|---|"
    jq -r '
      def status:
        if .error then "failed"
        elif .skipped then "skipped"
        elif .pushed then "pushed"
        else "built (not pushed)" end;
      def digest:
        if (.digest // "") == "" then "–"
        else "`" + (.digest[0:19]) + "`" end;
      select(.event == "image")
      | "| \(.key) | `\(.ref)` | \(digest) | \(status) |"' "$events"
  fi

  if [ "${#failures[@]}" -gt 0 ]; then
    echo
    echo "**Failed:**"
    echo
    for f in "${failures[@]}"; do
      echo "- $f"
    done
  fi

  if [ "${#uses[@]}" -gt 0 ]; then
    echo
    echo "Use the published image(s):"
    echo
    echo '```bash'
    for u in "${uses[@]}"; do
      echo "podbox create $u"
    done
    echo '```'
  fi

  if [ "${#first_pushes[@]}" -gt 0 ]; then
    echo
    echo "> **First publish.** GHCR creates new packages as private. To let others pull"
    echo "> without logging in, open each package, then *Package settings → Change"
    echo "> visibility → Public* (one-time, and it cannot be reversed from public to private):"
    echo ">"
    for r in "${first_pushes[@]}"; do
      echo "> - \`$r\`"
    done
  fi
} >>"$out"
