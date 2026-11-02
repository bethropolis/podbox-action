load ../helpers

setup() {
  setup_env
  export PODBOX_API="file://$FIX/fake-api"
  export PODBOX_RAW="file://$FIX/fake-raw"
  export FAKE_PODBOX_SRC="$FIX/fake-podbox/podbox"
  export FAKE_INSTALLER_LOG="$BATS_TEST_TMPDIR/installer.log"
}

@test "installs a pinned version and puts it on PATH" {
  PODBOX_VERSION=v0.10.0 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"podbox 0.10.0"* ]]
  grep -qx "$RUNNER_TEMP/podbox/bin" "$GITHUB_PATH"
  [ -x "$RUNNER_TEMP/podbox/bin/podbox" ]
  [ "$(get_output version)" = "v0.10.0" ]
}

@test "passes the tag, force flag and bindir to the installer" {
  PODBOX_VERSION=v0.10.0 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  grep -q "version=v0.10.0 force=1 bindir=$RUNNER_TEMP/podbox/bin" "$FAKE_INSTALLER_LOG"
}

@test "a version without the leading v is normalized" {
  PODBOX_VERSION=0.10.0 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ "$(get_output version)" = "v0.10.0" ]
}

@test "latest is resolved through the releases API" {
  PODBOX_VERSION=latest run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ "$(get_output version)" = "v0.10.0" ]
}

@test "latest fails clearly when the API is unreachable" {
  PODBOX_API="file://$BATS_TEST_TMPDIR/nowhere" PODBOX_VERSION=latest run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not resolve the latest podbox release"* ]]
}

@test "garbage versions are rejected" {
  PODBOX_VERSION="banana; rm -rf /" run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid podbox-version"* ]]
}

@test "unsupported architectures are rejected" {
  UNAME_M=riscv64 PODBOX_VERSION=v0.10.0 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported architecture"* ]]
}

@test "fails closed when the installer fails (corrupted download)" {
  PODBOX_VERSION=v0.0.1 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"podbox installer failed"* ]]
  [ ! -s "$GITHUB_PATH" ]
  [ ! -e "$RUNNER_TEMP/podbox/bin/podbox" ]
}

@test "fails when the installer for the tag cannot be downloaded" {
  PODBOX_VERSION=v9.9.9 run "$REPO_ROOT/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not download the podbox installer"* ]]
  [ ! -s "$GITHUB_PATH" ]
}
