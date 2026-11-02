load ../helpers

setup() {
  setup_env
}

@test "matches the golden summary for the multi fixture" {
  run "$REPO_ROOT/scripts/summary.sh" "$FIX/events-multi.ndjson"
  [ "$status" -eq 0 ]
  diff -u "$FIX/golden/summary-multi.md" "$GITHUB_STEP_SUMMARY"
}

@test "no first-publish hint when first_push is absent" {
  run "$REPO_ROOT/scripts/summary.sh" "$FIX/events-fail.ndjson"
  [ "$status" -eq 0 ]
  ! grep -q "First publish" "$GITHUB_STEP_SUMMARY"
}

@test "empty event stream says no images were built" {
  : >"$BATS_TEST_TMPDIR/empty.ndjson"
  run "$REPO_ROOT/scripts/summary.sh" "$BATS_TEST_TMPDIR/empty.ndjson"
  [ "$status" -eq 0 ]
  grep -q "No images were built" "$GITHUB_STEP_SUMMARY"
}

@test "skipped images get no podbox create line" {
  run "$REPO_ROOT/scripts/summary.sh" "$FIX/events-multi.ndjson"
  ! grep -q "podbox create ghcr.io/me/repo/dev" "$GITHUB_STEP_SUMMARY"
  grep -q "podbox create ghcr.io/me/repo/gaming:latest" "$GITHUB_STEP_SUMMARY"
}

@test "writes to stdout when GITHUB_STEP_SUMMARY is unset" {
  unset GITHUB_STEP_SUMMARY
  run "$REPO_ROOT/scripts/summary.sh" "$FIX/events-multi.ndjson"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## podbox images"* ]]
}

@test "usage error without an events file" {
  run "$REPO_ROOT/scripts/summary.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}
