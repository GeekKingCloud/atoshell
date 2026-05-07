#!/usr/bin/env bash
# show.sh — Show a ticket, the next ready ticket, or the kanban board
#
# Usage:
#   atoshell show <id> [options]
#   atoshell show next [options]
#   atoshell show board [options]
#
# Aliases: yomu, read
#
# Options (Output):
#   --details        Show created/edited timestamps for ticket and comments (id view)
#   --done           Include Done column (board view)
#   --full|--all|-f  Include Done and show all tickets per column (board view)
#   --json|-j        Output ticket as JSON (agent-friendly)
#   --help|-h        Show 'show' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
_setup_readonly

# ── Parse flags ───────────────────────────────────────────────────────────────
scope=""
details=false done=false full=false json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --details)
      details=true
      shift ;;
    --done)
      done=true
      shift ;;
    --full|--all|-f)
      full=true
      shift ;;
    --json|-j)
      json=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        _cli_error "$json" "UNKNOWN_OPTION" "unknown option \"$1\"." "option" "$1"
      fi
      if [[ -z "$scope" ]]; then
        scope="$1"
      else
        _cli_error "$json" "UNEXPECTED_ARGUMENT" "unexpected argument \"$1\"." "got" "$1"
      fi
      shift ;;
  esac
done

# ── Board view ────────────────────────────────────────────────────────────────
# I make this typo far too often...
if [[ "$scope" == "board" || "$scope" == "baord" ]]; then
  $full && done=true
  $done && full=true
  _print_board "$done" "$full"
  exit 0
fi

# ── Next view ─────────────────────────────────────────────────────────────────
# Best unblocked ready ticket with no assignee or assigned to the current user.
if [[ "$scope" == "next" ]]; then
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  next_ticket=$(jq -c --argjson n "$topo_count" --arg u "$USERNAME" '
    .[0:$n] | map(select(
      ((.accountable // []) | length == 0) or
      ((.accountable // []) | any(. == $u))
    )) | .[0] // empty
  ' <<< "$ranked_ready_json")
  if [[ -z "$next_ticket" ]]; then
    if $json; then _json_error "NO_READY_TICKETS"
    else
      _status_warn 'no ready tickets available.'
      printf 'Error: no ready tickets available.\n' >&2
    fi
    exit 1
  fi
  id=$(jq -r '.id' <<< "$next_ticket")
fi

# ── Resolve ticket ────────────────────────────────────────────────────────────
[[ -z "$scope" ]] && _cli_error "$json" "MISSING_ARGUMENT" "missing argument. Usage: atoshell show <id|next|board> [flags]." "argument" "id"
[[ -z "${id:-}" ]] && id="$scope"
if [[ ! "$id" =~ ^[0-9]+$ ]]; then
  if $json; then _json_error "INVALID_TICKET_ID" "got" "$id"
  else printf 'Error: ticket ID must be a number, got "%s".\n' "$(_terminal_safe_line "$id")" >&2
  fi
  exit 1
fi

src_file=$(_find_ticket_file "$id" 2>/dev/null) || {
  if $json; then _json_error "TICKET_NOT_FOUND" "id" "$id"
  else printf 'Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
  fi
  exit 1
}

# ── Dependency context ────────────────────────────────────────────────────────
dep_ctx=$(_ticket_dep_context "$id" "$src_file")
blocked_by_json=$(printf '%s' "$dep_ctx" | jq -c '.blocked_by')
blocking_json=$(printf '%s' "$dep_ctx"   | jq -c '.blocking')

# ── JSON output ───────────────────────────────────────────────────────────────
if $json; then
  jq --arg id "$id" \
     --argjson blocked_by "$blocked_by_json" \
     --argjson blocking   "$blocking_json" \
     '.tickets[] | select(.id | tostring == $id) |
      . + {
        blocked:    ($blocked_by | length > 0),
        blocked_by: $blocked_by,
        blocking:   $blocking
      }' "$src_file"
  exit 0
fi

# ── Human output ──────────────────────────────────────────────────────────────
blocked_count=$(jq -r 'length' <<< "$blocked_by_json")
if (( blocked_count > 0 )); then
  _status_warn '#%s is currently blocked.' "$id"
elif [[ "$scope" == "next" ]]; then
  _status_ok 'next ready ticket — #%s' "$id"
else
  _status_ok 'showing #%s' "$id"
fi
_print_ticket "$id" "$src_file" "$details" "$blocked_by_json" "$blocking_json"
