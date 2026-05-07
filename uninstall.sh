#!/usr/bin/env bash
# uninstall.sh — atoshell uninstaller
#
# Usage:
#   atoshell uninstall
#
# Aliases: nuku, flush, purge

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"

INSTALL_DIR="$HOME/.atoshell"
BIN_DIR="$HOME/.local/bin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    *)
      if [[ "$1" == -* ]]; then
        printf 'Error: unknown option "%s".\n' "$(_terminal_safe_line "$1")" >&2
      else
        printf 'Error: unexpected argument "%s".\n' "$(_terminal_safe_line "$1")" >&2
      fi
      exit 1 ;;
  esac
done

printf '\n'
printf '+--------------------------------------------------+\n'
printf '|          atoshell — uninstall                    |\n'
printf '+--------------------------------------------------+\n'
printf '\n'

# ── Remove bin entries ────────────────────────────────────────────────────────
for _bin in atoshell ato atoshell.cmd ato.cmd; do
  if [[ -e "$BIN_DIR/$_bin" ]]; then
    rm "$BIN_DIR/$_bin"
    printf '  [REMOVED]  %s/%s\n' "$BIN_DIR" "$_bin"
  else
    printf '  [SKIPPED]  %s/%s (not found)\n' "$BIN_DIR" "$_bin"
  fi
done

# ── Remove directory ──────────────────────────────────────────────────────────
# Optional
if [[ -d "$INSTALL_DIR" ]]; then
  printf '\n  Remove install directory %s? [y/N] ' "$INSTALL_DIR"
  if _stdin_is_tty; then
    _tty_read ans '' 'n'
  else
    ans="n"
  fi
  printf '\n'
  if [[ "${ans,,}" == "y" ]]; then
    rm -rf "$INSTALL_DIR"
    printf '  [REMOVED]  %s\n' "$INSTALL_DIR"
  else
    printf '  [KEPT]     %s\n' "$INSTALL_DIR"
  fi
fi

printf '\n  atoshell uninstalled.\n'
printf '  Your .atoshell/ project folders are untouched.\n\n'
