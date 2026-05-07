#!/usr/bin/env bash
# install.sh — atoshell installer
#
# Usage:
#   atoshell install [options]
#   bash install.sh [options]
#   curl -fsSL https://raw.githubusercontent.com/GeekKingCloud/atoshell/main/install.sh | bash
#
# Or run directly after cloning:
#   bash install.sh
#
# Options:
#   --help|-h   Show install usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="https://github.com/GeekKingCloud/atoshell.git"
INSTALL_DIR="$HOME/.atoshell"
BIN_DIR="$HOME/.local/bin"

show_help() {
  awk 'NR==1{next} /^# ── /{exit} /^#/{sub(/^# ?/,""); print; next} /^[^#]/{exit}' "$0"
}
# install.sh runs before the normal helper stack is installed, so keep this
# bootstrap-local copy aligned with _terminal_safe_line.
safe_arg() {
  printf '%s' "$1" |
    LC_ALL=C sed -E $'s/\x1B\\][^\x07\x1B]*(\x07|\x1B\\\\)//g; s/\x1B[P_^X][^\x1B]*(\x1B\\\\)//g; s/\x1B\\[[0-?]*[ -/]*[@-~]//g; s/\x1B\\].*//g; s/\x1B[P_^X].*//g; s/\x1B[@-Z\\\\-_]//g; s/\x1B//g' |
    LC_ALL=C tr '\n\t' '  ' |
    LC_ALL=C tr -d '\000-\010\013\014\015-\037\177'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) show_help; exit 0 ;;
    *)
      if [[ "$1" == -* ]]; then
        printf 'Error: unknown option "%s".\n' "$(safe_arg "$1")" >&2
      else
        printf 'Error: unexpected argument "%s".\n' "$(safe_arg "$1")" >&2
      fi
      exit 1 ;;
  esac
done

write_windows_cmd_wrapper() {
  local command_name="$1"
  local target_script="$2"
  local bash_path=''
  local target_path=''
  local git_root=''
  local git_bash_path=''
  local git_bash_unix=''

  if ! command -v cygpath > /dev/null 2>&1; then
    return 0
  fi

  git_root="$(cygpath -w /)"
  git_bash_path="${git_root}\\bin\\bash.exe"
  git_bash_unix="$(cygpath -u "$git_bash_path" 2>/dev/null || true)"
  if [[ -n "$git_bash_unix" && -x "$git_bash_unix" ]]; then
    bash_path="$git_bash_path"
  else
    bash_path="$(cygpath -w "$(command -v bash)")"
  fi
  target_path="$(cygpath -w "$target_script")"
  printf '@echo off\r\nsetlocal\r\n"%s" "%s" %%*\r\n' "$bash_path" "$target_path" > "$BIN_DIR/$command_name.cmd"
}

printf '\n'
printf '+--------------------------------------------------+\n'
printf '|          atoshell — installer                    |\n'
printf '+--------------------------------------------------+\n'
printf '\n'

# ── Dependencies ──────────────────────────────────────────────────────────────
for _dep in bash git jq; do
  if ! command -v "$_dep" > /dev/null 2>&1; then
    printf 'Error: %s is required but not installed.\n' "$_dep" >&2
    case "$_dep" in
      bash) printf '       On Windows, use Git Bash.\n'               >&2 ;;
      git)  printf '       https://git-scm.com/downloads\n'           >&2 ;;
      jq)   printf '       https://jqlang.github.io/jq/download/\n'   >&2 ;;
    esac
    exit 1
  fi
done

# ── Install or update ─────────────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR/.git" ]]; then
  printf 'Updating existing install at %s...\n' "$INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only
  printf '\n  [OK] atoshell updated.\n'
else
  printf 'Installing to %s...\n' "$INSTALL_DIR"
  git clone --filter=blob:none --sparse "$REPO" "$INSTALL_DIR"
  git -C "$INSTALL_DIR" sparse-checkout set --no-cone \
    '/*' '!tests' '!.github' '!CHANGELOG.md' '!README.md'
  printf '\n  [OK] atoshell installed.\n'
fi

# ── Create bin wrappers ───────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
chmod +x "$INSTALL_DIR/atoshell.sh"
for _cmd in atoshell ato; do
  printf '#!/usr/bin/env bash\nexec "%s/atoshell.sh" "$@"\n' "$INSTALL_DIR" > "$BIN_DIR/$_cmd"
  chmod +x "$BIN_DIR/$_cmd"
  write_windows_cmd_wrapper "$_cmd" "$INSTALL_DIR/atoshell.sh"
done
printf '  [OK] Installed → %s/{atoshell,ato}\n' "$BIN_DIR"
if [[ -f "$BIN_DIR/atoshell.cmd" || -f "$BIN_DIR/ato.cmd" ]]; then
  printf '  [OK] Installed → %s/{atoshell.cmd,ato.cmd}\n' "$BIN_DIR"
fi

# ── PATH test ─────────────────────────────────────────────────────────────────
if ! command -v atoshell > /dev/null 2>&1; then
  printf '\n  Note: %s is not in your PATH.\n' "$BIN_DIR"
  printf '  Add it to your shell config:\n\n'
  printf '    echo '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> ~/.bashrc && source ~/.bashrc\n'
  printf '  or:\n'
  printf '    echo '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> ~/.zshrc  && source ~/.zshrc\n'
fi

printf '\n  Run "ato init" in a project to get started.\n\n'
