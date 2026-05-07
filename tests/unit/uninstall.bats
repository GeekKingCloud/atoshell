#!/usr/bin/env bats
# Tests for: atoshell uninstall
#
# Custom setup: uninstall.sh does not use an atoshell project, so no fixtures
# or .atoshell/ are needed. HOME is redirected to a tmpdir for every test.
#
# INSTALL_DIR removal is conservative in non-TTY tests: the prompt is shown and
# the default answer is no.

load '../helpers/setup'

# ── Setup ─────────────────────────────────────────────────────────────────────
setup() {
  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"

  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$ATOSHELL_REPO/atoshell.sh" \
    > "$BATS_TEST_TMPDIR/bin/atoshell"
  chmod +x "$BATS_TEST_TMPDIR/bin/atoshell"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  export HOME="$BATS_TEST_TMPDIR/home"
  export INSTALL_DIR="$HOME/.atoshell"
  export BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
}

# ── 1. Wrapper removal ────────────────────────────────────────────────────────
@test "uninstall --help: exits 0 without removing wrappers" {
  touch "$BIN_DIR/atoshell" "$BIN_DIR/ato" "$BIN_DIR/atoshell.cmd" "$BIN_DIR/ato.cmd"
  run atoshell uninstall --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ -f "$BIN_DIR/atoshell" ]
  [ -f "$BIN_DIR/ato" ]
  [ -f "$BIN_DIR/atoshell.cmd" ]
  [ -f "$BIN_DIR/ato.cmd" ]
}

@test "uninstall: unknown option strips terminal controls from human error" {
  run atoshell uninstall $'--bad\e]52;c;SGVsbG8=\aopt'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--badopt"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "uninstall: exit code 0" {
  run atoshell uninstall
  [ "$status" -eq 0 ]
}
@test "uninstall: removes atoshell wrapper when present" {
  touch "$BIN_DIR/atoshell"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$BIN_DIR/atoshell" ]
}
@test "uninstall: removes ato wrapper when present" {
  touch "$BIN_DIR/ato"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$BIN_DIR/ato" ]
}
@test "uninstall: removes both wrappers when both present" {
  touch "$BIN_DIR/atoshell" "$BIN_DIR/ato"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$BIN_DIR/atoshell" ]
  [ ! -f "$BIN_DIR/ato" ]
}
@test "uninstall: removes Windows cmd wrappers when present" {
  touch "$BIN_DIR/atoshell.cmd" "$BIN_DIR/ato.cmd"
  touch "$BIN_DIR/atom" "$BIN_DIR/atoshell-preview"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$BIN_DIR/atoshell.cmd" ]
  [ ! -f "$BIN_DIR/ato.cmd" ]
  [ -f "$BIN_DIR/atom" ]
  [ -f "$BIN_DIR/atoshell-preview" ]
}

# ── 2. Nothing found ──────────────────────────────────────────────────────────
@test "uninstall: 'SKIPPED' shown for atoshell when absent" {
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"*"atoshell"* ]]
}
@test "uninstall: 'SKIPPED' shown for ato when absent" {
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"*"ato"* ]]
}

# ── 3. Output content ─────────────────────────────────────────────────────────
@test "uninstall: output contains 'REMOVED' for atoshell" {
  touch "$BIN_DIR/atoshell"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"REMOVED"*"atoshell"* ]]
}
@test "uninstall: output contains 'REMOVED' for ato" {
  touch "$BIN_DIR/ato"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"REMOVED"*"ato"* ]]
}
@test "uninstall: output contains 'atoshell uninstalled'" {
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"atoshell uninstalled"* ]]
}
@test "uninstall: output mentions project folders are untouched" {
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *".atoshell/"* ]]
}

# ── 4. INSTALL_DIR handling ───────────────────────────────────────────────────
@test "uninstall: no prompt when INSTALL_DIR does not exist" {
  # INSTALL_DIR was never created — the [[ -d ]] check is false, no prompt printed
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" != *"Remove install directory"* ]]
}
@test "uninstall: prompt shown when INSTALL_DIR exists" {
  mkdir -p "$INSTALL_DIR"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"Remove install directory"* ]]
}
@test "uninstall: INSTALL_DIR kept when no TTY input" {
  mkdir -p "$INSTALL_DIR"
  run atoshell uninstall
  [ "$status" -eq 0 ]
  [ -d "$INSTALL_DIR" ]
  [[ "$output" == *"KEPT"* ]]
}
# ── 5. Command aliases ────────────────────────────────────────────────────────
@test "uninstall: nuku alias works" {
  run atoshell nuku
  [ "$status" -eq 0 ]
}
@test "uninstall: flush alias works" {
  run atoshell flush
  [ "$status" -eq 0 ]
}
@test "uninstall: purge alias works" {
  run atoshell purge
  [ "$status" -eq 0 ]
}
