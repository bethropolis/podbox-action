load ../helpers

setup() {
  setup_env
}

@test "passes with the required features and schema 1" {
  run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -eq 0 ]
}

@test "missing publish feature fails and names the feature" {
  FAKE_PODBOX_FEATURES='["emit_context"]' run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"'publish'"* ]]
}

@test "schema higher than 1 is refused" {
  FAKE_PODBOX_SCHEMA=2 run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"schema 2"* ]]
}

@test "unknown fields in podbox info are ignored" {
  FAKE_PODBOX_EXTRA='{"future":true,"features_v2":["x"]}' run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -eq 0 ]
}

@test "auto + pull_request resolves push=false" {
  GITHUB_EVENT_NAME=pull_request INPUT_PUSH=auto run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -eq 0 ]
  [ "$(get_output push)" = "false" ]
}

@test "auto + pull_request_target resolves push=false" {
  GITHUB_EVENT_NAME=pull_request_target INPUT_PUSH=auto run "$REPO_ROOT/scripts/preflight.sh"
  [ "$(get_output push)" = "false" ]
}

@test "auto + push event resolves push=true" {
  GITHUB_EVENT_NAME=push INPUT_PUSH=auto run "$REPO_ROOT/scripts/preflight.sh"
  [ "$(get_output push)" = "true" ]
}

@test "auto + schedule resolves push=true" {
  GITHUB_EVENT_NAME=schedule INPUT_PUSH=auto run "$REPO_ROOT/scripts/preflight.sh"
  [ "$(get_output push)" = "true" ]
}

@test "unset input behaves like auto" {
  GITHUB_EVENT_NAME=push run "$REPO_ROOT/scripts/preflight.sh"
  [ "$(get_output push)" = "true" ]
}

@test "explicit true on a pull_request still resolves false and warns" {
  GITHUB_EVENT_NAME=pull_request INPUT_PUSH=true run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -eq 0 ]
  [ "$(get_output push)" = "false" ]
  [[ "$output" == *"::warning::"* ]]
}

@test "explicit false is always false" {
  GITHUB_EVENT_NAME=push INPUT_PUSH=false run "$REPO_ROOT/scripts/preflight.sh"
  [ "$(get_output push)" = "false" ]
}

@test "invalid push input is rejected" {
  INPUT_PUSH=maybe run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid push input"* ]]
}

@test "missing podbox fails with a clear message" {
  PATH="/usr/bin:/bin" run bash -c 'PATH=/nonexistent:/usr/bin:/bin; "$1"' _ "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"podbox"* ]]
}
