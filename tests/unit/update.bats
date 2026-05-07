#!/usr/bin/env bats
# Tests for: atoshell update
#
# Phase 1 (CLI self-update) branches:
#   a) INSTALL_DIR/.git exists → git pull (fake git, no network)
#   b) no .git                 → [WARN] with manual reinstall command, continues
#
# Phase 2 (project setup) branches:
#   a) .atoshell/ in cwd       → sync files and config
#   b) not found + --walk      → walk up to parent
#   c) not found               → [SKIP], exit 0
#
# Fake git uses $BATS_TEST_TMPDIR/git_pull_done to simulate a hash change:
#   FAKE_GIT_MODE=updated → rev-parse returns different hash after pull.

# ── Setup ─────────────────────────────────────────────────────────────────────
setup() {
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"
  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"

  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$ATOSHELL_REPO/atoshell.sh" \
    > "$BATS_TEST_TMPDIR/bin/atoshell"
  chmod +x "$BATS_TEST_TMPDIR/bin/atoshell"

  # Fake git — in its own dir so Phase 1 minimal-PATH tests can strip it separately.
  mkdir -p "$BATS_TEST_TMPDIR/git_bin"
  cat > "$BATS_TEST_TMPDIR/git_bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BATS_TEST_TMPDIR/git_calls.log"
args=("$@")
[[ "${args[0]}" == "-C" ]] && args=("${args[@]:2}")
case "${args[0]}" in
  rev-parse)
    if [[ "${FAKE_GIT_MODE:-}" == "updated" && -f "$BATS_TEST_TMPDIR/git_pull_done" ]]; then
      echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    else
      echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    fi ;;
  pull) touch "$BATS_TEST_TMPDIR/git_pull_done" ;;
  log)  echo "    abc1234 Add new feature" ;;
esac
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/git_bin/git"

  # Fake curl exists to prove update does not execute the remote installer fallback.
  cat > "$BATS_TEST_TMPDIR/git_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl should not be called during atoshell update.\n' >&2
exit 99
EOF
  chmod +x "$BATS_TEST_TMPDIR/git_bin/curl"

  export PATH="$BATS_TEST_TMPDIR/bin:$BATS_TEST_TMPDIR/git_bin:$PATH"

  export HOME="$BATS_TEST_TMPDIR/home"
  export INSTALL_DIR="$HOME/.atoshell"
  mkdir -p "$INSTALL_DIR"

  # Fixture project for Phase 2 tests
  mkdir -p "$TEST_PROJECT/.atoshell"
  cp "$BATS_TEST_DIRNAME/../fixtures/queue.json"   "$TEST_PROJECT/.atoshell/queue.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/backlog.json" "$TEST_PROJECT/.atoshell/backlog.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/done.json" "$TEST_PROJECT/.atoshell/done.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/meta.json"    "$TEST_PROJECT/.atoshell/meta.json"
  # Use the full template so _sync_config_vars finds all vars already present
  # (added=0) and doesn't return exit 1 via `[[ added -eq 0 ]] && printf`.
  cp "$ATOSHELL_REPO/.atoshell.example/config.env" \
     "$TEST_PROJECT/.atoshell/config.env"
  printf '\nUSERNAME="testuser"\n' \
    >> "$TEST_PROJECT/.atoshell/config.env"

  cd "$TEST_PROJECT"
}

# Build a minimal PATH with only the tools update.sh needs for Phase 2,
# but no git — forces the Phase 1 [WARN] branch.
_stage_tool() {
  local real="$1" dest="$2"
  cat > "$dest" <<EOF
#!/usr/bin/env bash
exec "$real" "\$@"
EOF
  chmod +x "$dest"
}

_real_bash() {
  type -P bash
}

_stage_bash() {
  local dir="$1"
  local real; real="$(_real_bash)"
  cat > "$dir/bash" <<EOF
#!$real
exec "$real" "\$@"
EOF
  chmod +x "$dir/bash"
}

_minimal_update_path() {
  local dir="$BATS_TEST_TMPDIR/minimal_update_bin"
  mkdir -p "$dir"
  _stage_bash "$dir"
  for tool in jq grep mkdir dirname cat mv mktemp pwd touch date sed head sleep cp rm wc; do
    local real; real="$(type -P "$tool" 2>/dev/null || true)"
    [[ -n "$real" ]] && _stage_tool "$real" "$dir/$tool"
  done
  printf '%s' "$dir"
}

# ── 1. Phase 1 — git pull, up to date ─────────────────────────────────────────
@test "update: Phase 1 git — exit 0 when up to date" {
  mkdir -p "$INSTALL_DIR/.git"
  run atoshell update
  [ "$status" -eq 0 ]
}
@test "update: Phase 1 git — output contains 'Pulling latest'" {
  mkdir -p "$INSTALL_DIR/.git"
  run atoshell update
  [[ "$output" == *"Pulling latest"* ]]
}
@test "update: Phase 1 git — output contains 'already up to date'" {
  mkdir -p "$INSTALL_DIR/.git"
  run atoshell update
  [[ "$output" == *"already up to date"* ]]
}
@test "update: Phase 1 git — pulls install dir with fast-forward only" {
  mkdir -p "$INSTALL_DIR/.git"
  run atoshell update
  [ "$status" -eq 0 ]
  grep -qxF -- "-C $INSTALL_DIR pull --ff-only" "$BATS_TEST_TMPDIR/git_calls.log"
}

# ── 2. Phase 1 — git pull, repo updated ───────────────────────────────────────
@test "update: Phase 1 git — output contains 'CLI updated' when hash changes" {
  mkdir -p "$INSTALL_DIR/.git"
  run env FAKE_GIT_MODE=updated atoshell update
  [[ "$output" == *"CLI updated"* ]]
}
@test "update: Phase 1 git — output contains commit log when updated" {
  mkdir -p "$INSTALL_DIR/.git"
  run env FAKE_GIT_MODE=updated atoshell update
  [[ "$output" == *"abc1234"* ]]
}

# ── 3. Phase 1 — no .git, manual reinstall ────────────────────────────────────
@test "update: Phase 1 manual reinstall — exit 0 when no .git" {
  run atoshell update
  [ "$status" -eq 0 ]
}
@test "update: Phase 1 manual reinstall — does not run curl fallback" {
  run atoshell update
  [[ "$output" != *"curl should not be called"* ]]
}
@test "update: Phase 1 manual reinstall — output shows reinstall command" {
  run atoshell update
  [[ "$output" == *"Reinstall manually with"* ]]
  [[ "$output" == *"curl -fsSL https://raw.githubusercontent.com/GeekKingCloud/atoshell/main/install.sh | bash"* ]]
}

# ── 4. Phase 1 — no .git, minimal PATH ─────────────────────────────────────────
# env -i with a tools dir containing only bash/jq/grep/mkdir (no git)
# forces the else-[WARN] branch. 2>&1 captures stderr so we can assert on it.
@test "update: Phase 1 warn — exit 0 when no git repo" {
  local tdir; tdir="$(_minimal_update_path)"
  local bash_path; bash_path="$(_real_bash)"
  cd "$ATOSHELL_REPO"
  run env -i \
    HOME="$HOME" USER="$USER" LC_ALL=C \
    BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" \
    ATOSHELL_DIR="$ATOSHELL_REPO" \
    PATH="$tdir" \
    "$bash_path" update.sh 2>&1
  [ "$status" -eq 0 ]
}
@test "update: Phase 1 warn — output contains [WARN] when no git repo" {
  local tdir; tdir="$(_minimal_update_path)"
  local bash_path; bash_path="$(_real_bash)"
  cd "$ATOSHELL_REPO"
  run env -i \
    HOME="$HOME" USER="$USER" LC_ALL=C \
    BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" \
    ATOSHELL_DIR="$ATOSHELL_REPO" \
    PATH="$tdir" \
    "$bash_path" update.sh 2>&1
  [[ "$output" == *"WARN"* ]]
}
@test "update: Phase 1 warn — output explains automatic update is unavailable" {
  local tdir; tdir="$(_minimal_update_path)"
  local bash_path; bash_path="$(_real_bash)"
  cd "$ATOSHELL_REPO"
  run env -i \
    HOME="$HOME" USER="$USER" LC_ALL=C \
    BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" \
    ATOSHELL_DIR="$ATOSHELL_REPO" \
    PATH="$tdir" \
    "$bash_path" update.sh 2>&1
  [[ "$output" == *"Automatic CLI update is not available for this install"* ]]
}

# ── 5. Phase 2 — no project found ─────────────────────────────────────────────
@test "update: Phase 2 no project — exit 0" {
  cd "$BATS_TEST_TMPDIR"
  run atoshell update
  [ "$status" -eq 0 ]
}
@test "update: Phase 2 no project — output contains '[SKIP]'" {
  cd "$BATS_TEST_TMPDIR"
  run atoshell update
  [[ "$output" == *"[SKIP]"* ]]
}

# ── 6. Phase 2 — project found in cwd ─────────────────────────────────────────
@test "update: Phase 2 project — exit 0" {
  run atoshell update
  [ "$status" -eq 0 ]
}
@test "update: Phase 2 project — output contains 'Phase 2'" {
  run atoshell update
  [[ "$output" == *"Phase 2"* ]]
}
@test "update: Phase 2 project — output contains '[OK]' for files" {
  run atoshell update
  [[ "$output" == *"[OK]"* ]]
}
@test "update: Phase 2 project — output contains 'Done.'" {
  run atoshell update
  [[ "$output" == *"Done."* ]]
}
@test "update: Phase 2 project — existing tickets preserved" {
  run atoshell update
  [ "$status" -eq 0 ]
  count=$(jq '.tickets | length' "$TEST_PROJECT/.atoshell/queue.json")
  [ "$count" -gt 0 ]
}

# ── 7. Phase 2 — --walk ───────────────────────────────────────────────────────
@test "update: --walk finds project in parent directory" {
  mkdir -p "$TEST_PROJECT/subdir"
  cd "$TEST_PROJECT/subdir"
  run atoshell update --walk
  [ "$status" -eq 0 ]
  [[ "$output" != *"[SKIP]"* ]]
  [[ "$output" == *"Phase 2"* ]]
}
@test "update: without --walk skips project in parent directory" {
  mkdir -p "$TEST_PROJECT/subdir"
  cd "$TEST_PROJECT/subdir"
  run atoshell update
  [[ "$output" == *"[SKIP]"* ]]
}

# ── 8. Phase 2 — creates missing files ────────────────────────────────────────
@test "update: Phase 2 recreates missing queue.json" {
  rm "$TEST_PROJECT/.atoshell/queue.json"
  run atoshell update
  [ "$status" -eq 0 ]
  [ -f "$TEST_PROJECT/.atoshell/queue.json" ]
}
@test "update: Phase 2 recreates missing backlog.json" {
  rm "$TEST_PROJECT/.atoshell/backlog.json"
  run atoshell update
  [ "$status" -eq 0 ]
  [ -f "$TEST_PROJECT/.atoshell/backlog.json" ]
}
@test "update: Phase 2 recreates missing done.json" {
  rm "$TEST_PROJECT/.atoshell/done.json"
  run atoshell update
  [ "$status" -eq 0 ]
  [ -f "$TEST_PROJECT/.atoshell/done.json" ]
}
@test "update: Phase 2 recreates missing meta.json" {
  rm "$TEST_PROJECT/.atoshell/meta.json"
  run atoshell update
  [ "$status" -eq 0 ]
  [ -f "$TEST_PROJECT/.atoshell/meta.json" ]
}
@test "update: Phase 2 removes legacy archive ignore and adds meta ignore" {
  printf '.atoshell/archive.json\n' > "$TEST_PROJECT/.gitignore"
  run atoshell update
  [ "$status" -eq 0 ]
  ! grep -qF '.atoshell/archive.json' "$TEST_PROJECT/.gitignore"
  grep -qF '.atoshell/meta.json' "$TEST_PROJECT/.gitignore"
}
@test "update: Phase 2 appends missing config vars" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'DISCIPLINES="Frontend,Backend"' \
    > "$TEST_PROJECT/.atoshell/config.env"
  run atoshell update
  [ "$status" -eq 0 ]
  grep -qF 'TYPE_2="Task"' "$TEST_PROJECT/.atoshell/config.env"
  grep -qF 'UNBLOCK_P1_BUDGET="3"' "$TEST_PROJECT/.atoshell/config.env"
  ! grep -q 'DISCIPLINES=' "$TEST_PROJECT/.atoshell/config.env"
}
@test "update: Phase 2 config sync is idempotent across reruns" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'DISCIPLINES="Frontend,Backend"' \
    > "$TEST_PROJECT/.atoshell/config.env"
  atoshell update
  run atoshell update
  [ "$status" -eq 0 ]
  [ "$(grep -c '^TYPE_2=' "$TEST_PROJECT/.atoshell/config.env")" -eq 1 ]
  [ "$(grep -c '^UNBLOCK_P1_BUDGET=' "$TEST_PROJECT/.atoshell/config.env")" -eq 1 ]
  ! grep -q 'DISCIPLINES=' "$TEST_PROJECT/.atoshell/config.env"
}
@test "update: Phase 2 falls back to generated config defaults when the local template is unavailable" {
  local tdir; tdir="$(_minimal_update_path)"
  local bash_path; bash_path="$(_real_bash)"
  local fake_root="$BATS_TEST_TMPDIR/fake_root"
  mkdir -p "$fake_root/.atoshell.example"
  rm -f "$TEST_PROJECT/.atoshell/config.env"
  cd "$TEST_PROJECT"
  run env -i \
    HOME="$HOME" USER="$USER" LC_ALL=C \
    BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" \
    ATOSHELL_DIR="$fake_root" \
    PATH="$tdir" \
    "$bash_path" "$ATOSHELL_REPO/update.sh" 2>&1
  [ "$status" -eq 0 ]
  grep -qF '# .atoshell/config.env' "$TEST_PROJECT/.atoshell/config.env"
  grep -qF '# Controls created_at, updated_at, and ticket comment timestamps.' "$TEST_PROJECT/.atoshell/config.env"
  grep -qF '# Use an IANA name such as "America/Mexico_City"' "$TEST_PROJECT/.atoshell/config.env"
  grep -qF 'STATUS_READY="Ready"' "$TEST_PROJECT/.atoshell/config.env"
}

# ── 9. --help flag ────────────────────────────────────────────────────────────
@test "update --help: exits 0" {
  run atoshell update --help
  [ "$status" -eq 0 ]
}
@test "update --help: output contains Usage" {
  run atoshell update --help
  [[ "$output" == *"Usage:"* ]]
}
@test "update --help: output documents --walk" {
  run atoshell update --help
  [[ "$output" == *"--walk"* ]]
}

# ── 10. Command aliases ───────────────────────────────────────────────────────
@test "update: noru alias works" {
  run atoshell noru
  [ "$status" -eq 0 ]
}
@test "update: migrate alias works" {
  run atoshell migrate
  [ "$status" -eq 0 ]
}
@test "update: patch alias works" {
  run atoshell patch
  [ "$status" -eq 0 ]
}
