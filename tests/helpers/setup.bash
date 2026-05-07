#!/usr/bin/env bash
# Shared test setup — sourced by each .bats file via:
#   load '../helpers/setup'

setup_fixture_project() {
  # Temporary project directory — isolated per test
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"

  # Resolve the atoshell repo root (tests/helpers/ → ../..)
  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"

  # Create a wrapper named "atoshell" in the tmp dir so tests call it naturally.
  # A wrapper script (not a symlink) is required so that BASH_SOURCE[0] inside
  # atoshell.sh resolves to the real repo path, letting it find add.sh etc.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$ATOSHELL_REPO/atoshell.sh" \
    > "$BATS_TEST_TMPDIR/bin/atoshell"
  chmod +x "$BATS_TEST_TMPDIR/bin/atoshell"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  # Populate .atoshell/ with fixture data
  mkdir -p "$TEST_PROJECT/.atoshell"
  cp "$BATS_TEST_DIRNAME/../fixtures/queue.json"   "$TEST_PROJECT/.atoshell/queue.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/backlog.json" "$TEST_PROJECT/.atoshell/backlog.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/done.json"    "$TEST_PROJECT/.atoshell/done.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/meta.json"    "$TEST_PROJECT/.atoshell/meta.json"

  # Write a minimal config so status names are predictable
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'USERNAME="testuser"' \
    > "$TEST_PROJECT/.atoshell/config.env"

  # Run every test from inside the project
  cd "$TEST_PROJECT"
}

load_atoshell_helpers() {
  export ATOSHELL_DIR="$ATOSHELL_REPO"
  # shellcheck source=/dev/null
  source "$ATOSHELL_REPO/funcs/helpers.sh"
  _load_config "${1:-$TEST_PROJECT}"
}

load_atoshell_algorithms() {
  # shellcheck source=/dev/null
  source "$ATOSHELL_REPO/funcs/algorithms.sh"
}

run_split() {
  local stdout_file="$BATS_TEST_TMPDIR/stdout"
  local stderr_file="$BATS_TEST_TMPDIR/stderr"
  rm -f "$stdout_file" "$stderr_file"
  run bash -c 'out="$1"; err="$2"; shift 2; "$@" >"$out" 2>"$err"' _ "$stdout_file" "$stderr_file" "$@"
}

assert_json_error_split() {
  local expected="$1"
  local stdout_file="$BATS_TEST_TMPDIR/stdout"
  local stderr_file="$BATS_TEST_TMPDIR/stderr"
  [ "$status" -ne 0 ]
  [ ! -s "$stdout_file" ]
  jq -e --arg code "$expected" '.error == $code' "$stderr_file" >/dev/null
}

setup() {
  setup_fixture_project
}
