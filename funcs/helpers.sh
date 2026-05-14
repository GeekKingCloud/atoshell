#!/usr/bin/env bash
# helpers.sh — compatibility aggregator for atoshell command scripts
#
# Source this file from any command script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"

_ATOSHELL_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_require_modern_bash() {
  local major="${BASH_VERSINFO[0]:-0}"
  local minor="${BASH_VERSINFO[1]:-0}"

  if (( major > 4 || (major == 4 && minor >= 3) )); then
    return 0
  fi

  printf 'Error: Atoshell requires Bash 4.3 or newer; current shell is Bash %s.\n' "${BASH_VERSION:-unknown}" >&2
  printf 'On macOS, the system /bin/bash is usually 3.2. Install a modern Bash with: brew install bash\n' >&2
  printf 'Then put /opt/homebrew/bin or /usr/local/bin before /bin in PATH and rerun Atoshell.\n' >&2
  exit 1
}

_require_modern_bash

# ── Helper modules ────────────────────────────────────────────────────────────
source "$_ATOSHELL_HELPERS_DIR/path.sh"
source "$_ATOSHELL_HELPERS_DIR/terminal.sh"
source "$_ATOSHELL_HELPERS_DIR/config.sh"
source "$_ATOSHELL_HELPERS_DIR/state.sh"
source "$_ATOSHELL_HELPERS_DIR/tickets.sh"
source "$_ATOSHELL_HELPERS_DIR/prints.sh"
