#!/usr/bin/env bats
# Tests for: atoshell install
#
# Custom setup: no .atoshell/ pre-population; HOME is redirected to a tmpdir so
# the default install paths stay isolated.
#
# Fake git: clone creates $INSTALL_DIR/.git + atoshell.sh stub so chmod succeeds;
#           all other git sub-commands (pull, sparse-checkout, -C …) exit 0.
#
# Dependency-guard tests use env -i + a tools_dir containing symlinks to only the
# tools that should be visible, so command -v genuinely fails for the missing tool.

# ── Setup ─────────────────────────────────────────────────────────────────────
setup() {
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"

  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"

  # atoshell wrapper (bin/) and fake git (git_bin/) are in separate dirs so
  # PATH-manipulation tests can include one without the other.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$ATOSHELL_REPO/atoshell.sh" \
    > "$BATS_TEST_TMPDIR/bin/atoshell"
  chmod +x "$BATS_TEST_TMPDIR/bin/atoshell"

  # Fake git: clone → creates .git + stub atoshell.sh; everything else → exit 0
  mkdir -p "$BATS_TEST_TMPDIR/git_bin"
  cat > "$BATS_TEST_TMPDIR/git_bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == clone ]]; then
  dest="${@: -1}"
  if [[ -d "$dest" && -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" && ! -d "$dest/.git" ]]; then
    printf 'fatal: destination path already exists and is not an empty git repo\n' >&2
    exit 1
  fi
  mkdir -p "$dest/.git"
  touch "$dest/atoshell.sh"
fi
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/git_bin/git"

  cat > "$BATS_TEST_TMPDIR/git_bin/cygpath" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-w" ]]; then
  printf '%s\n' "${2:-}"
else
  printf '%s\n' "${1:-}"
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/git_bin/cygpath"

  export PATH="$BATS_TEST_TMPDIR/bin:$BATS_TEST_TMPDIR/git_bin:$PATH"

  export HOME="$BATS_TEST_TMPDIR/home"
  export INSTALL_DIR="$HOME/.atoshell"
  export BIN_DIR="$HOME/.local/bin"
  mkdir -p "$HOME"

  cd "$TEST_PROJECT"
}

@test "install --help: exits 0 without installing" {
  run atoshell install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ ! -e "$INSTALL_DIR" ]
  [ ! -e "$BIN_DIR/atoshell" ]
}

@test "install: unknown option strips terminal controls from human error" {
  run atoshell install $'--bad\e]52;c;SGVsbG8=\aopt'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--badopt"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

# Build a minimal PATH for dependency-guard tests (env -i style).
# Tools are symlinked from their real system locations when possible, with a
# copy fallback for environments where symlink creation is unavailable.
# git is always our fake (to avoid network); pass skip=git|jq to omit a tool.
_stage_tool() {
  local real="$1" dest="$2"
  if ! ln -sf "$real" "$dest" 2>/dev/null; then
    cp "$real" "$dest"
    chmod +x "$dest"
  fi
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

_tools_dir() {
  local skip="${1:-}"
  local dir="$BATS_TEST_TMPDIR/tools_${skip:-all}"
  mkdir -p "$dir"
  [[ "$skip" != "bash" ]] && _stage_bash "$dir"
  for tool in jq chmod mkdir touch; do
    [[ "$tool" == "$skip" ]] && continue
    local real; real="$(type -P "$tool" 2>/dev/null || true)"
    [[ -n "$real" ]] && _stage_tool "$real" "$dir/$tool"
  done
  if [[ "$skip" != "git" ]]; then
    cp "$BATS_TEST_TMPDIR/git_bin/git" "$dir/git"
  fi
  printf '%s' "$dir"
}

# ── 1. Fresh install ──────────────────────────────────────────────────────────
@test "install: exit code 0 on fresh install" {
  run atoshell install
  [ "$status" -eq 0 ]
}
@test "install: atoshell wrapper created in BIN_DIR" {
  run atoshell install
  [ "$status" -eq 0 ]
  [ -f "$BIN_DIR/atoshell" ]
  [ -f "$BIN_DIR/atoshell.cmd" ]
}
@test "install: ato wrapper created in BIN_DIR" {
  run atoshell install
  [ "$status" -eq 0 ]
  [ -f "$BIN_DIR/ato" ]
  [ -f "$BIN_DIR/ato.cmd" ]
}
@test "install: atoshell wrapper is executable" {
  run atoshell install
  [ "$status" -eq 0 ]
  [ -x "$BIN_DIR/atoshell" ]
}
@test "install: ato wrapper is executable" {
  run atoshell install
  [ "$status" -eq 0 ]
  [ -x "$BIN_DIR/ato" ]
}
@test "install: atoshell wrapper exec path points to INSTALL_DIR" {
  run atoshell install
  [ "$status" -eq 0 ]
  grep -q "$INSTALL_DIR" "$BIN_DIR/atoshell"
  grep -q "$INSTALL_DIR" "$BIN_DIR/atoshell.cmd"
}
@test "install: ato wrapper exec path points to INSTALL_DIR" {
  run atoshell install
  [ "$status" -eq 0 ]
  grep -q "$INSTALL_DIR" "$BIN_DIR/ato"
  grep -q "$INSTALL_DIR" "$BIN_DIR/ato.cmd"
}
@test "install: output contains 'atoshell installed'" {
  run atoshell install
  [ "$status" -eq 0 ]
  [[ "$output" == *"atoshell installed"* ]]
}
@test "install: output contains 'ato init'" {
  run atoshell install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ato init"* ]]
}

# ── 2. Update (already installed) ─────────────────────────────────────────────
@test "install: exit code 0 when updating existing install" {
  mkdir -p "$INSTALL_DIR/.git"
  touch "$INSTALL_DIR/atoshell.sh"
  run atoshell install
  [ "$status" -eq 0 ]
}
@test "install: output contains 'atoshell updated' when .git exists" {
  mkdir -p "$INSTALL_DIR/.git"
  touch "$INSTALL_DIR/atoshell.sh"
  run atoshell install
  [ "$status" -eq 0 ]
  [[ "$output" == *"atoshell updated"* ]]
}

# ── 3. PATH advisory ──────────────────────────────────────────────────────────
@test "install: no PATH advisory when atoshell already in PATH" {
  # Our setup puts the atoshell wrapper in PATH, so command -v atoshell succeeds
  run atoshell install
  [ "$status" -eq 0 ]
  [[ "$output" != *"not in your PATH"* ]]
}
@test "install: shows PATH advisory when BIN_DIR not in PATH" {
  # env -i with a controlled PATH: fake git + system utilities, but no atoshell.
  # BIN_DIR is under the temp HOME and not in this PATH, so
  # command -v atoshell fails inside install.sh → advisory is printed.
  local tdir; tdir="$(_tools_dir)"
  run env -i \
    HOME="$HOME" \
    LC_ALL=C \
    PATH="$tdir:/usr/bin:/bin" \
    bash "$ATOSHELL_REPO/install.sh" 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"not in your PATH"* ]]
}

# ── 4. Dependency guards ──────────────────────────────────────────────────────
@test "install: missing git exits 1" {
  local tdir; tdir="$(_tools_dir git)"
  local bash_path; bash_path="$(_real_bash)"
  run env -i \
    HOME="$HOME" \
    PATH="$tdir" \
    "$bash_path" "$ATOSHELL_REPO/install.sh" 2>&1
  [ "$status" -eq 1 ]
  [[ "$output" == *"git"* ]]
}
@test "install: missing bash exits 1" {
  local tdir; tdir="$(_tools_dir bash)"
  local bash_path; bash_path="$(_real_bash)"
  run env -i \
    HOME="$HOME" \
    PATH="$tdir" \
    "$bash_path" "$ATOSHELL_REPO/install.sh" 2>&1
  [ "$status" -eq 1 ]
  [[ "$output" == *"bash"* ]]
}
@test "install: missing jq exits 1" {
  local tdir; tdir="$(_tools_dir jq)"
  local bash_path; bash_path="$(_real_bash)"
  run env -i \
    HOME="$HOME" \
    PATH="$tdir" \
    "$bash_path" "$ATOSHELL_REPO/install.sh" 2>&1
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq"* ]]
}
@test "install: direct install works without curl when git and jq are present" {
  local tdir; tdir="$(_tools_dir)"
  local bash_path; bash_path="$(_real_bash)"
  cat > "$tdir/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl should not be called during direct install.\n' >&2
exit 99
EOF
  chmod +x "$tdir/curl"
  run env -i \
    HOME="$HOME" \
    PATH="$tdir:$PATH" \
    "$bash_path" "$ATOSHELL_REPO/install.sh" 2>&1
  [ "$status" -eq 0 ]
  [ -f "$BIN_DIR/atoshell" ]
}

# ── 5. Existing directories and wrapper overwrite ─────────────────────────────
@test "install: non-empty non-git install directory exits non-zero" {
  mkdir -p "$INSTALL_DIR"
  printf 'sentinel\n' > "$INSTALL_DIR/existing.txt"
  run atoshell install
  [ "$status" -ne 0 ]
}
@test "install: rerun overwrites stale wrappers in BIN_DIR" {
  mkdir -p "$BIN_DIR"
  printf '#!/usr/bin/env bash\necho stale\n' > "$BIN_DIR/atoshell"
  printf '#!/usr/bin/env bash\necho stale\n' > "$BIN_DIR/ato"
  printf 'old wrapper\n' > "$BIN_DIR/atoshell.cmd"
  printf 'old wrapper\n' > "$BIN_DIR/ato.cmd"
  chmod +x "$BIN_DIR/atoshell" "$BIN_DIR/ato"
  run atoshell install
  [ "$status" -eq 0 ]
  grep -q "$INSTALL_DIR" "$BIN_DIR/atoshell"
  grep -q "$INSTALL_DIR" "$BIN_DIR/ato"
  grep -q "$INSTALL_DIR" "$BIN_DIR/atoshell.cmd"
  grep -q "$INSTALL_DIR" "$BIN_DIR/ato.cmd"
}
