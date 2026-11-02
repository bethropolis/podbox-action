load ../helpers

setup() {
  setup_env
  export PUSH=true
  export FAKE_PODBOX_EVENTS="$FIX/events-multi.ndjson"
}

@test "publishes with --push and --ci github, ndjson output" {
  run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  args="$(call_args 2)"
  grep -qx 'publish' <<<"$args"
  grep -qx -- '--ci' <<<"$args"
  grep -qx 'github' <<<"$args"
  grep -qx -- '--output' <<<"$args"
  grep -qx 'ndjson' <<<"$args"
  grep -qx -- '--push' <<<"$args"
  ! grep -qx -- '--no-push' <<<"$args"
}

@test "PUSH=false passes --no-push" {
  PUSH=false run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  args="$(call_args 2)"
  grep -qx -- '--no-push' <<<"$args"
  ! grep -qx -- '--push' <<<"$args"
}

@test "invalid PUSH value is rejected" {
  PUSH=banana run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid PUSH"* ]]
}

@test "prints the plan before building (--list call first)" {
  FAKE_PODBOX_PLAN="$FIX/plan-multi.json" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  grep -qx -- '--list' <<<"$(call_args 1)"
  ! grep -qx -- '--list' <<<"$(call_args 2)"
  [[ "$output" == *"ghcr.io/me/repo/dev"* ]]
}

@test "only='dev gaming' becomes two separate argv entries" {
  INPUT_ONLY="dev gaming" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  args="$(call_args 2)"
  grep -qx 'dev' <<<"$args"
  grep -qx 'gaming' <<<"$args"
  ! grep -qx 'dev gaming' <<<"$args"
}

@test "an unset images input does not pass --manifest" {
  run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  ! grep -qx -- '--manifest' <<<"$(call_args 2)"
}

@test "an images input with spaces is passed as ONE argument" {
  INPUT_IMAGES="my dir/images.toml" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  args="$(call_args 2)"
  grep -qx -- '--manifest' <<<"$args"
  grep -qx 'my dir/images.toml' <<<"$args"
}

@test "shell metacharacters in inputs are passed through inert" {
  INPUT_IMAGES='a$(touch pwned).toml' run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  grep -qxF 'a$(touch pwned).toml' <<<"$(call_args 2)"
  [ ! -e pwned ]
}

@test "registry input is forwarded" {
  INPUT_REGISTRY="registry.example.com" run "$REPO_ROOT/scripts/publish.sh"
  args="$(call_args 2)"
  grep -qx -- '--registry' <<<"$args"
  grep -qx 'registry.example.com' <<<"$args"
}

@test "force=true passes --force, anything else does not" {
  INPUT_FORCE=true run "$REPO_ROOT/scripts/publish.sh"
  grep -qx -- '--force' <<<"$(call_args 2)"
  INPUT_FORCE=false run "$REPO_ROOT/scripts/publish.sh"
  ! grep -qx -- '--force' <<<"$(call_args 4)"
}

@test "working directory is honored" {
  mkdir -p "$BATS_TEST_TMPDIR/sub"
  INPUT_WORKDIR="$BATS_TEST_TMPDIR/sub" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  run env INPUT_WORKDIR="$BATS_TEST_TMPDIR/missing" "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"working-directory not found"* ]]
}

@test "sets images, pushed and skipped outputs (one pushed, one skipped)" {
  run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  [ "$(get_output pushed)" = "1" ]
  [ "$(get_output skipped)" = "1" ]
  images="$(get_multiline_output images)"
  [ "$(jq 'length' <<<"$images")" -eq 2 ]
  [ "$(jq -r '.[0].key' <<<"$images")" = "dev" ]
  [ "$(jq -r '.[1].first_push' <<<"$images")" = "true" ]
}

@test "writes the job summary" {
  run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  grep -q "## podbox images" "$GITHUB_STEP_SUMMARY"
}

@test "a failed image fails the job but other images are still reported" {
  FAKE_PODBOX_EVENTS="$FIX/events-fail.ndjson" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"1 image(s) failed"* ]]
  [ "$(get_output pushed)" = "1" ]
  grep -q "failed" "$GITHUB_STEP_SUMMARY"
  grep -q "build failed at step 3" "$GITHUB_STEP_SUMMARY"
}

@test "podbox's exit code is propagated and the summary is still written" {
  FAKE_PODBOX_EVENTS="$FIX/events-fail.ndjson" FAKE_PODBOX_EXIT=4 run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 4 ]
  grep -q "## podbox images" "$GITHUB_STEP_SUMMARY"
}

@test "a terminal error object fails the run and appears in the summary" {
  FAKE_PODBOX_EVENTS="$FIX/events-error.ndjson" FAKE_PODBOX_EXIT=2 run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"::error::No images.toml"* ]]
  grep -q "No images.toml" "$GITHUB_STEP_SUMMARY"
  [ "$(jq 'length' <<<"$(get_multiline_output images)")" -eq 0 ]
}

@test "non-JSON stdout lines are reported, unknown events are ignored" {
  FAKE_PODBOX_EVENTS="$FIX/events-noise.ndjson" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"non-JSON line"* ]]
  [[ "$output" == *"hello from a buggy podbox"* ]]
  [ "$(jq 'length' <<<"$(get_multiline_output images)")" -eq 1 ]
  [ "$(get_output pushed)" = "1" ]
}
