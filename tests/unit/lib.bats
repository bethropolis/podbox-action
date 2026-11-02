load ../helpers

setup() {
  setup_env
  # shellcheck disable=SC1091
  source "$REPO_ROOT/scripts/lib.sh"
}

@test "die exits with the given code and annotates the error" {
  run bash -c 'source "$1"; die "boom" 7' _ "$REPO_ROOT/scripts/lib.sh"
  [ "$status" -eq 7 ]
  [[ "$output" == *"::error::boom"* ]]
}

@test "die defaults to exit code 1" {
  run bash -c 'source "$1"; die "boom"' _ "$REPO_ROOT/scripts/lib.sh"
  [ "$status" -eq 1 ]
}

@test "require succeeds for an existing command" {
  run require bash
  [ "$status" -eq 0 ]
}

@test "require names a missing command" {
  run bash -c 'source "$1"; require definitely-not-a-command' _ "$REPO_ROOT/scripts/lib.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"definitely-not-a-command"* ]]
}

@test "set_output appends name=value" {
  set_output foo bar
  [ "$(get_output foo)" = "bar" ]
}

@test "set_output_multiline round-trips content containing newlines and equals signs" {
  value=$'line one\nkey=value\n{"a":1}'
  set_output_multiline blob "$value"
  [ "$(get_multiline_output blob)" = "$value" ]
}

@test "log_group and log_endgroup emit workflow commands" {
  run log_group "hello"
  [ "$output" = "::group::hello" ]
  run log_endgroup
  [ "$output" = "::endgroup::" ]
}
