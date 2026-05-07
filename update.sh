#!/usr/bin/env bash
# update.sh — Pull the latest atoshell CLI and sync project files and config
#
# Usage:
#   atoshell update [options]
#
# Aliases: noru, migrate, patch
#
# Options:
#   --walk  Search parent directories for a project to update (default: current dir only)
#   --help|-h  Show 'update' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]-}"
if [[ -z "$SCRIPT_SOURCE" || "$SCRIPT_SOURCE" == "bash" || "$SCRIPT_SOURCE" == "-bash" ]]; then
  SCRIPT_SOURCE="${BASH_ARGV0:-}"
fi
if [[ -z "$SCRIPT_SOURCE" || "$SCRIPT_SOURCE" == "bash" || "$SCRIPT_SOURCE" == "-bash" ]]; then
  SCRIPT_SOURCE="$0"
fi
case "$SCRIPT_SOURCE" in
  */*) SCRIPT_DIR="${SCRIPT_SOURCE%/*}" ;;
  *) SCRIPT_DIR="." ;;
esac
source "$(cd "$SCRIPT_DIR" && pwd)/funcs/helpers.sh"

INSTALL_DIR="$HOME/.atoshell"
INSTALLER_URL="https://raw.githubusercontent.com/GeekKingCloud/atoshell/main/install.sh"

# ── Parse flags ───────────────────────────────────────────────────────────────
walk=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --walk)
      walk=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        printf 'Error: unknown option "%s".\n' "$(_terminal_safe_line "$1")" >&2
      else
        printf 'Error: unexpected argument "%s".\n' "$(_terminal_safe_line "$1")" >&2
      fi
      exit 1 ;;
  esac
done

print_banner "atoshell — update"

# ── Phase 1: CLI self-update ──────────────────────────────────────────────────
printf '  Phase 1: CLI update\n\n'

if [[ -d "$INSTALL_DIR/.git" ]]; then
  before=$(git -C "$INSTALL_DIR" rev-parse HEAD)
  printf '  Pulling latest from remote...\n'
  git -C "$INSTALL_DIR" pull --ff-only
  after=$(git -C "$INSTALL_DIR" rev-parse HEAD)
  if [[ "$before" == "$after" ]]; then
    _status_ok 'CLI already up to date.'
    printf '\n'
  else
    _status_ok 'CLI updated. Changes:'
    printf '\n'
    git -C "$INSTALL_DIR" log --oneline "${before}..${after}" | sed 's/^/    /'
    printf '\n'
  fi
else
  _status_warn 'Automatic CLI update is not available for this install.'
  printf '         atoshell could not update the existing install at %s,\n' "$INSTALL_DIR" >&2
  printf '         because it is not a git checkout.\n' >&2
  printf '         Reinstall manually with:\n' >&2
  printf '         curl -fsSL %s | bash\n\n' "$INSTALLER_URL" >&2
fi

# ── Phase 2: Project setup ────────────────────────────────────────────────────
printf '  Phase 2: Project setup\n\n'

# Find project root — current dir only by default; walk upward if --walk was passed
project_root=$(_resolve_project "$walk" 2>/dev/null) || true

if [[ -z "$project_root" ]]; then
  printf '  [SKIP] Not inside an atoshell project (no .atoshell/ found).\n'
  printf '         Run "atoshell init" in a project directory to set one up.\n\n'
  exit 0
fi

printf '  Project: %s\n\n' "$project_root"

_load_config "$project_root"

# Ensure all data files exist (creates any missing ones)
_with_state_lock _ensure_files
_status_ok '.atoshell/backlog.json'
_status_ok '.atoshell/queue.json'
_status_ok '.atoshell/done.json'
_status_ok '.atoshell/meta.json'

# Ensure all config vars exist (prompts for new empties)
_with_state_lock _ensure_config "$CONFIG_FILE"

_sync_gitignore "$project_root/.gitignore"
_status_ok '.gitignore'

printf '\n  Done.\n\n'
