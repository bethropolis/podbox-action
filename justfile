# Task runner. `just` lists nothing by default; `just check` is the gate.
default: check

# Everything that must pass before a commit.
check: lint test

# Static analysis: shell, workflow syntax, workflow security.
lint:
    shellcheck -x scripts/*.sh tests/fixtures/fake-podbox/podbox tests/fixtures/fake-raw/*/*/*/scripts/*.sh
    actionlint
    zizmor --offline .

# Unit tests (no network, no docker; stub podbox).
test:
    bats tests/unit
