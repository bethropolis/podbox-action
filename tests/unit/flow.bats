load ../helpers

# End-to-end across scripts, the way action.yml chains them.

setup() {
  setup_env
  export FAKE_PODBOX_EVENTS="$FIX/events-multi.ndjson"
}

@test "pull_request flow: preflight says no push, publish passes --no-push" {
  GITHUB_EVENT_NAME=pull_request run "$REPO_ROOT/scripts/preflight.sh"
  [ "$status" -eq 0 ]
  push="$(get_output push)"
  [ "$push" = "false" ]
  PUSH="$push" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  grep -qx -- '--no-push' <<<"$(call_args 3)"
}

@test "push flow: preflight says push, publish passes --push and reports outputs" {
  GITHUB_EVENT_NAME=push run "$REPO_ROOT/scripts/preflight.sh"
  push="$(get_output push)"
  [ "$push" = "true" ]
  PUSH="$push" run "$REPO_ROOT/scripts/publish.sh"
  [ "$status" -eq 0 ]
  grep -qx -- '--push' <<<"$(call_args 3)"
  [ "$(get_output pushed)" = "1" ]
}
