#!/usr/bin/env bash
# init.sh — Initialise .atoshell/ in the current project
#
# Usage:
#   atoshell init [options]
#
# Aliases: kido, boot

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"

project_root="$(pwd)"

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

# ── Already initialised ───────────────────────────────────────────────────────
if [[ -d "$project_root/.atoshell" ]]; then
  exec bash "$ATOSHELL_DIR/update.sh"
fi

# ── Init running ──────────────────────────────────────────────────────────────
print_banner "atoshell — init"
printf '  Project: %s\n\n' "$project_root"

_load_config "$project_root"

[[ -f "$BACKLOG_FILE" ]] && _bl=OK || _bl=CREATED
[[ -f "$QUEUE_FILE" ]]   && _q=OK  || _q=CREATED
[[ -f "$DONE_FILE" ]] && _done=OK || _done=CREATED
[[ -f "$META_FILE" ]]    && _meta=OK || _meta=CREATED
_with_state_lock _ensure_files
printf '  [%s]  .atoshell/backlog.json\n'  "$_bl"
printf '  [%s]  .atoshell/queue.json\n'   "$_q"
printf '  [%s]  .atoshell/done.json\n'    "$_done"
printf '  [%s]  .atoshell/meta.json\n'    "$_meta"

[[ -f "$CONFIG_FILE" ]] && _cfg=OK || _cfg=CREATED
_with_state_lock _ensure_config "$CONFIG_FILE"
printf '  [%s]  .atoshell/config.env\n' "$_cfg"

# ── .gitignore ────────────────────────────────────────────────────────────────
GITIGNORE="$project_root/.gitignore"
_sync_gitignore "$GITIGNORE"
printf '  [OK]  .gitignore\n'

printf '\n  Ready. Use "atoshell add" to create your first ticket.\n\n'
