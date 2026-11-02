# Shared bats helpers. Load with: load ../helpers
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
FIX="$REPO_ROOT/tests/fixtures"
export REPO_ROOT FIX

# Isolated environment for every test: stub podbox on PATH, runner files in a
# per-test temp dir, and no leaked action inputs.
setup_env() {
  unset INPUT_PUSH INPUT_ONLY INPUT_IMAGES INPUT_REGISTRY INPUT_FORCE INPUT_WORKDIR \
    PUSH PODBOX_VERSION PODBOX_API PODBOX_RAW UNAME_M GITHUB_EVENT_NAME \
    FAKE_PODBOX_FEATURES FAKE_PODBOX_SCHEMA FAKE_PODBOX_EXTRA FAKE_PODBOX_PLAN \
    FAKE_PODBOX_EVENTS FAKE_PODBOX_EXIT FAKE_INSTALLER_LOG GITHUB_TOKEN
  export PATH="$FIX/fake-podbox:$PATH"
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output"
  export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md"
  export GITHUB_PATH="$BATS_TEST_TMPDIR/path"
  export RUNNER_TEMP="$BATS_TEST_TMPDIR/runner"
  export FAKE_PODBOX_ARGS_LOG="$BATS_TEST_TMPDIR/args.log"
  mkdir -p "$RUNNER_TEMP"
  : >"$GITHUB_OUTPUT"
  : >"$GITHUB_STEP_SUMMARY"
  : >"$GITHUB_PATH"
  : >"$FAKE_PODBOX_ARGS_LOG"
}

# Value of a single-line step output.
get_output() {
  grep -m1 "^$1=" "$GITHUB_OUTPUT" | cut -d= -f2-
}

# Value of a multi-line step output written with a heredoc delimiter.
get_multiline_output() {
  awk -v name="$1" '
    $0 ~ "^" name "<<" { delim = substr($0, length(name) + 3); inside = 1; next }
    inside && $0 == delim { exit }
    inside { print }
  ' "$GITHUB_OUTPUT"
}

# Lines of argv recorded for the Nth (1-based) stub podbox call.
call_args() {
  awk -v n="$1" '/^CALL$/ { c++; next } c == n { print }' "$FAKE_PODBOX_ARGS_LOG"
}
