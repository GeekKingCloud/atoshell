#!/usr/bin/env bash
# atoshell — Terminal ticket tracker
#
# Usage:
#   atoshell <command> [options]  Issues command
#   atoshell                      Shows interactive menu
#
# Commands (simple, japanese, cyberpunk):
# Setup:
#   install                                            — Install atoshell on this machine
#   uninstall  | nuku      | flush    | purge          — Remove atoshell and (optionally) directory
#   init       | kido      | boot                      — Initialise .atoshell/ in current directory
#   update     | noru      | migrate  | patch          — Update atoshell to the latest version
# Usage:
#   add        | tasu      | fab      | new    | open  — Create a new ticket
#   show       | yomu      | read                      — Show a ticket, next ready ticket, or kanban board
#   edit       | henshu    | mod                       — Update ticket properties
#   delete     | kesu      | wipe                      — Delete a ticket
#   move       | ido       | shift                     — Move ticket(s) to a new status (workflow transition)
#   take       | toru      | snatch   | grab           — Assign yourself to a ticket and move it to In Progress
#   comment    | kaku      | mark     | note           — Add, edit, or remove comments
#   list       | rekki     | draw                      — List tickets with optional filters
#   search     | hiku      | crawl    | find           — Search ticket content
# Help:
#   help       | --help    | -h                        — Print the command menu
#   version    | --version | -v                        — Print the atoshell version
#
# Global flags:
#   --quiet    | -q                                    — Suppress decorative output; auto-enabled on non-TTY stdout
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/GeekKingCloud/atoshell/main/install.sh | bash

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

ATOSHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ATOSHELL_DIR/funcs/helpers.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────
print_version() {
  local version=''
  IFS= read -r version < "$ATOSHELL_DIR/VERSION"
  printf 'atoshell %s\n' "$version"
}

show_menu() {
  if ! _stdin_is_tty; then
    printf 'Error: a command is required in non-interactive mode.\n' >&2
    printf 'Run "atoshell help" for available commands.\n' >&2
    exit 1
  fi
  printf '\n'
  printf '+--------------------------------------------------+\n'
  printf '|            atoshell — Menu                       |\n'
  printf '+--------------------------------------------------+\n'
  printf '\n'
  printf '  0) init       — Initialise .atoshell/ in current directory\n'
  printf '  1) add        — Create a new ticket\n'
  printf '  2) show       — Show a ticket, next ready ticket, or kanban board\n'
  printf '  3) edit       — Edit ticket properties\n'
  printf '  4) delete     — Delete a ticket\n'
  printf '  5) list       — List tickets with optional filters\n'
  printf '  6) move       — Move ticket(s) to a new status (workflow transition)\n'
  printf '  7) take       — Assign yourself to a ticket and move it to In Progress\n'
  printf '  8) comment    — Add a comment to a ticket\n'
  printf '  9) search     — Search ticket content\n'
  printf ' 10) update     — Update atoshell\n'
  printf ' 11) uninstall  — Remove atoshell\n'
  printf ' 12) install    — Install atoshell on this machine\n'
  printf ' 13) version    — Print the atoshell version\n'
  printf '\n'
  local choice
  _tty_read choice 'Choose a command [0-13]: '
  printf '\n'
  case "$choice" in
    0|init|kido|boot)              CMD="init"       ;;
    1|add|tasu|fab|new|open)       CMD="add"        ;;
    2|show|yomu|read)              CMD="show"       ;;
    3|edit|henshu|mod)             CMD="edit"       ;;
    4|delete|kesu|wipe)            CMD="delete"     ;;
    5|list|rekki|draw)             CMD="list"       ;;
    6|move|ido|shift)              CMD="move"       ;;
    7|take|toru|snatch|grab)       CMD="take"       ;;
    8|comment|kaku|mark|note)      CMD="comment"    ;;
    9|search|hiku|crawl|find)      CMD="search"     ;;
   10|update|noru|migrate|patch)   CMD="update"     ;;
   11|uninstall|nuku|flush|purge)  CMD="uninstall"  ;;
   12|install)                     CMD="install"    ;;
   13|version)                     CMD="version"    ;;
    *)
      printf 'Error: unknown choice: %s\n' "$(_terminal_safe_line "$choice")" >&2
      exit 1
      ;;
  esac
}

# ── Global flags (strip before command dispatch) ──────────────────────────────
export ATOSHELL_QUIET="${ATOSHELL_QUIET:-0}"
_remaining=()
for _arg in "$@"; do
  case "$_arg" in
    --quiet|-q) ATOSHELL_QUIET=1 ;;
    *)          _remaining+=("$_arg") ;;
  esac
done
set -- "${_remaining[@]+"${_remaining[@]}"}"

# ── Normalise command ─────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  install)                     CMD="install"    ;;
  uninstall|nuku|flush|purge)  CMD="uninstall"  ;;
  init|kido|boot)              CMD="init"       ;;
  update|noru|migrate|patch)   CMD="update"     ;;
  add|tasu|fab|new|open)       CMD="add"        ;;
  show|yomu|read)              CMD="show"       ;;
  edit|henshu|mod)             CMD="edit"       ;;
  delete|kesu|wipe)            CMD="delete"     ;;
  move|ido|shift)              CMD="move"       ;;
  take|toru|snatch|grab)       CMD="take"       ;;
  comment|kaku|mark|note)      CMD="comment"    ;;
  list|rekki|draw)             CMD="list"       ;;
  search|hiku|crawl|find)      CMD="search"     ;;
  help|--help|-h)
    printf 'Usage: atoshell <command> [options]\n\n'
    printf 'Commands:\n'
    printf '  init       | kido    | boot                      — Initialise .atoshell/ in current directory\n'
    printf '  add        | tasu    | fab      | new    | open  — Create a new ticket\n'
    printf '  show       | yomu    | read                      — Show a ticket, next ready ticket, or kanban board\n'
    printf '  edit       | henshu  | mod                       — Edit ticket properties\n'
    printf '  delete     | kesu    | wipe                      — Delete a ticket\n'
    printf '  list       | rekki   | draw                      — List tickets with optional filters\n'
    printf '  move       | ido     | shift                     — Move ticket(s) to a new status (by name or column 1-4)\n'
    printf '  take       | toru    | snatch   | grab           — Assign yourself to a ticket and move it to In Progress\n'
    printf '  comment    | kaku    | mark     | note           — Add, edit, or remove comments\n'
    printf '  search     | hiku    | crawl    | find           — Search ticket content\n'
    printf '  update     | noru    | migrate  | patch          — Update atoshell\n'
    printf '  uninstall  | nuku    | flush    | purge          — Remove atoshell\n'
    printf '  install                                          — Install atoshell on this machine\n'
    printf '  version    | --version | -v                      — Print the atoshell version\n'
    printf '\nGlobal flags:\n'
    printf '  --quiet  | -q  — Suppress decorative output (auto on non-TTY stdout)\n'
    printf '\nRun without arguments for an interactive menu.\n'
    exit 0
    ;;
  version|--version|-v)
    print_version
    exit 0
    ;;
  "")
    show_menu
    ;;
  *)
    printf 'Error: unknown command: %s\n' "$(_terminal_safe_line "$CMD")" >&2
    printf 'Run "atoshell help" for available commands.\n' >&2
    exit 1
    ;;
esac

# ── Dispatch command ──────────────────────────────────────────────────────────
exec bash "$ATOSHELL_DIR/${CMD}.sh" "$@"
