#!/usr/bin/env bats
# Tests for: atoshell init
#
# Custom setup: starts from a bare empty project dir with NO .atoshell/.
# The shared helper is not loaded here because it pre-populates fixtures.
#
# "Already initialized" tests use local fakes so update.sh stays offline
# while Phase 2 syncs files and config.

# ── Setup ─────────────────────────────────────────────────────────────────────
setup() {
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"

  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"

  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$ATOSHELL_REPO/atoshell.sh" \
    > "$BATS_TEST_TMPDIR/bin/atoshell"
  chmod +x "$BATS_TEST_TMPDIR/bin/atoshell"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  cd "$TEST_PROJECT"
}

# ── 1. Fresh init — files created ─────────────────────────────────────────────
@test "init --help: exits 0 without creating project state" {
  run atoshell init --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ ! -e ".atoshell" ]
}

@test "init: exit code 0 on fresh project" {
  run atoshell init
  [ "$status" -eq 0 ]
}
@test "init: .atoshell/ directory created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -d ".atoshell" ]
}
@test "init: queue.json created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".atoshell/queue.json" ]
}
@test "init: backlog.json created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".atoshell/backlog.json" ]
}
@test "init: done.json created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".atoshell/done.json" ]
}
@test "init: meta.json created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".atoshell/meta.json" ]
}
@test "init: meta.json has next_id field" {
  run atoshell init
  [ "$status" -eq 0 ]
  val=$(jq '.next_id' .atoshell/meta.json)
  [ "$val" != "null" ]
}
@test "init: config.env created" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".atoshell/config.env" ]
}

# ── 2. Fresh init — file contents ─────────────────────────────────────────────
@test "init: queue.json has valid .tickets array" {
  run atoshell init
  [ "$status" -eq 0 ]
  len=$(jq '.tickets | length' .atoshell/queue.json)
  [ "$len" -eq 0 ]
}
@test "init: backlog.json has valid .tickets array" {
  run atoshell init
  [ "$status" -eq 0 ]
  len=$(jq '.tickets | length' .atoshell/backlog.json)
  [ "$len" -eq 0 ]
}
@test "init: done.json has valid .tickets array" {
  run atoshell init
  [ "$status" -eq 0 ]
  len=$(jq '.tickets | length' .atoshell/done.json)
  [ "$len" -eq 0 ]
}
@test "init: next_id starts at 1 on empty project" {
  run atoshell init
  [ "$status" -eq 0 ]
  val=$(jq '.next_id' .atoshell/meta.json)
  [ "$val" -eq 1 ]
}

# ── 3. Fresh init — .gitignore ────────────────────────────────────────────────
@test "init: .gitignore created when absent" {
  run atoshell init
  [ "$status" -eq 0 ]
  [ -f ".gitignore" ]
}
@test "init: .gitignore contains .atoshell/*.env" {
  run atoshell init
  [ "$status" -eq 0 ]
  grep -qF '.atoshell/*.env' .gitignore
}
@test "init: .gitignore contains .atoshell/meta.json" {
  run atoshell init
  [ "$status" -eq 0 ]
  grep -qF '.atoshell/meta.json' .gitignore
}
@test "init: pre-existing .gitignore gets both entries appended" {
  printf 'node_modules/\n' > .gitignore
  run atoshell init
  [ "$status" -eq 0 ]
  grep -qF '.atoshell/*.env'        .gitignore
  grep -qF '.atoshell/meta.json' .gitignore
}
@test "init: .atoshell/*.env not duplicated when already present" {
  printf '.atoshell/*.env\n' > .gitignore
  run atoshell init
  [ "$status" -eq 0 ]
  count=$(grep -cF '.atoshell/*.env' .gitignore)
  [ "$count" -eq 1 ]
}
@test "init: .atoshell/meta.json not duplicated when already present" {
  printf '.atoshell/meta.json\n' > .gitignore
  run atoshell init
  [ "$status" -eq 0 ]
  count=$(grep -cF '.atoshell/meta.json' .gitignore)
  [ "$count" -eq 1 ]
}
@test "init: neither entry duplicated when both already present" {
  printf '.atoshell/*.env\n.atoshell/meta.json\n' > .gitignore
  run atoshell init
  [ "$status" -eq 0 ]
  env_count=$(grep -cF '.atoshell/*.env' .gitignore)
  arc_count=$(grep -cF '.atoshell/meta.json' .gitignore)
  [ "$env_count" -eq 1 ]
  [ "$arc_count" -eq 1 ]
}
@test "init: removes legacy .atoshell/archive.json ignore entry" {
  printf '.atoshell/archive.json\n' > .gitignore
  run atoshell init
  [ "$status" -eq 0 ]
  ! grep -qF '.atoshell/archive.json' .gitignore
}

# ── 4. Fresh init — output ────────────────────────────────────────────────────
@test "init: output contains 'Ready'" {
  run atoshell init
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ready"* ]]
}
@test "init: output contains project path" {
  run atoshell init
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_PROJECT"* ]]
}

# ── 5. Command aliases ────────────────────────────────────────────────────────
@test "init: kido alias works" {
  run atoshell kido
  [ "$status" -eq 0 ]
  [ -d ".atoshell" ]
}
@test "init: boot alias works" {
  run atoshell boot
  [ "$status" -eq 0 ]
  [ -d ".atoshell" ]
}

# ── 6. Already initialized — delegates to update ──────────────────────────────
# Provides a fake curl to prove update.sh does not call the old installer fallback.
# Phase 2 finds the existing project and syncs files and config; exits 0.
_stub_curl() {
  printf '#!/usr/bin/env bash\nprintf "curl should not be called during init/update tests.\\n" >&2\nexit 99\n' > "$BATS_TEST_TMPDIR/bin/curl"
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}
@test "init: already initialized exits 0" {
  _stub_curl
  atoshell init
  run atoshell init
  [ "$status" -eq 0 ]
}
@test "init: already initialized does not overwrite existing tickets" {
  _stub_curl
  atoshell init
  atoshell add "Sentinel" --body "should survive re-init"
  atoshell init
  count=$(jq '[.tickets[] | select(.title=="Sentinel")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
