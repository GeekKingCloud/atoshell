#!/usr/bin/env bash
# take.sh — Assign yourself to a ticket and move it to In Progress
#
# Usage:
#   atoshell take [id] [options]
#   atoshell take next [options]
#
# Aliases: toru, snatch, grab
#
# Options:
#   --as <agent-N|number>                    Take on behalf of a numbered agent (e.g. agent-1 or 1)
# Options (Filters — next only):
#   --type|--kind|-t <Bug|Feature|Task|0-2>  Filter by type, comma-separated
#   --priority|-p <P0|P1|...|0-3>            Filter by priority, comma-separated
#   --size|-s <XS|S|M|L|XL|0-4>              Filter by size, comma-separated
#   --disciplines|--discipline|--dis|-d <n>  Filter by fixed discipline tags, comma-separated
# Options (Behaviour — id only):
#   --force|-F                               Override done guard and accountable warnings (mutually exclusive with next)
# Options (Output):
#   --json|-j                                Output ticket as JSON after taking
#   --help|-h                                Show 'take' usage help and exit
#
# Valid disciplines (fixed): Frontend, Backend, Database, Cloud, DevOps,
#   Architecture, Automation, QA, Research, Core
# Discipline aliases: fe=Frontend, be=Backend
# Use discipline filters to claim work that matches your capability area.

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
_setup

# ── Parse args ────────────────────────────────────────────────────────────────
scope="" type="" priority="" size="" disciplines="" as=""
force=false json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --as)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--as"
      as="$2"
      shift 2 ;;
    --force|-F)
      force=true
      shift ;;
    --json|-j)
      json=true
      shift ;;
    --type|--kind|-t)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--type"
      type="$(_resolve_type_filter "$2" "$json")" || exit 1
      shift 2 ;;
    --priority|-p)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--priority"
      priority="$(_resolve_priority_filter "$2" "$json")" || exit 1
      shift 2 ;;
    --size|-s)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--size"
      size="$(_resolve_size_filter "$2" "$json")" || exit 1
      shift 2 ;;
    --disciplines|--discipline|--dis|-d)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--disciplines"
      _resolve_discs "$2" "$json"
      shift 2 ;;
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

[[ -z "$scope" ]] && scope="next"
[[ "$scope" == "next" && "$force" == true ]] && {
  _cli_error "$json" "INVALID_ARGUMENT" "--force cannot be used with 'next' — specify a ticket ID instead." "option" "--force"
}

# ── Determine assignee ────────────────────────────────────────────────────────
# Interactive (stdin is TTY) → current user; non-TTY (agent/CI) → "[agent]"
# --as overrides both for numbered agents (e.g. agent-1, agent-2).
# stamp is for updated_by attribution — mirrors assignee: USERNAME in TTY, [agent] otherwise.
assignee="$(_resolve_actor "$as" "$json")"
stamp="$assignee"

_state_lock_acquire

# ── Resolve 'next' via ranking algorithm ──────────────────────────────────────
if [[ "$scope" == "next" ]]; then
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  next_ticket=$(jq -c \
    --argjson n "$topo_count" \
    --arg ft "${type,,}" --arg fp "${priority,,}" \
    --arg fsz "${size,,}" --arg fd "${disciplines,,}" '
    def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
    def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
    .[0:$n] | map(select(
      ml((.type // "") | ascii_downcase; $ft) and
      ml((.priority // "") | ascii_downcase; $fp) and
      ml((.size // "") | ascii_downcase; $fsz) and
      mld((.disciplines // []); $fd)
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
else
  id="$scope"
fi

if [[ ! "$id" =~ ^[0-9]+$ ]]; then
  if $json; then _json_error "INVALID_TICKET_ID" "got" "$id"
  else printf 'Error: ticket ID must be a number, got "%s".\n' "$(_terminal_safe_line "$id")" >&2
  fi
  exit 1
fi

# ── Resolve ticket ────────────────────────────────────────────────────────────
src_file=$(_find_ticket_file "$id" 2>/dev/null) || {
  if $json; then _json_error "TICKET_NOT_FOUND" "id" "$id"
  else printf 'Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
  fi
  exit 1
}
current_status=$(jq -r --arg id "$id" \
  '.tickets[] | select(.id | tostring == $id) | .status' "$src_file")
current_accountable=$(jq -c --arg id "$id" \
  '.tickets[] | select(.id | tostring == $id) | (.accountable // [])' "$src_file")
ts="$(_timestamp)"

# ── Done guard ────────────────────────────────────────────────────────────────
if [[ "$current_status" == "$STATUS_DONE" ]]; then
  if ! $force; then
    if $json; then _json_error "TICKET_CLOSED" "id" "$id" "status" "$current_status"
    else printf 'Error: #%s is already %s — use '\''atoshell move'\'' or '\''atoshell edit'\'' to reopen it, or re-run with --force\n' \
      "$id" "$(_terminal_safe_line "$current_status")" >&2
    fi
    exit 1
  fi
  _status_warn '#%s is already %s — assigning with --force' "$id" "$(_terminal_safe_line "$current_status")"
fi

# ── Accountable warnings ──────────────────────────────────────────────────────
if ! $force; then
  others=$(jq -r --arg a "$assignee" \
    '[.[] | select(. != $a)] | join(", ")' <<< "$current_accountable")
  already_assigned=$(jq -r --arg a "$assignee" \
    'any(. == $a) | tostring' <<< "$current_accountable")

  if [[ -n "$others" ]]; then
    others_display="$(_terminal_safe_line "$others")"
    if [[ "$already_assigned" == "false" ]]; then
      if $json; then _json_error "TICKET_ALREADY_ASSIGNED" "id" "$id" "assignees" "$others"
      else _status_warn '#%s is currently assigned to: %s  (--force to override)' "$id" "$others_display"
      fi
    else
      if $json; then _json_error "TICKET_ALSO_ASSIGNED" "id" "$id" "others" "$others"
      else _status_warn '#%s is also assigned to: %s  (--force to override)' "$id" "$others_display"
      fi
    fi
    exit 1
  fi
fi

# ── Status warning (already In Progress) ──────────────────────────────────────
if ! $force && [[ "$current_status" == "$STATUS_IN_PROGRESS" ]]; then
  _status_warn '#%s is already %s  (--force to override)' "$id" "$(_terminal_safe_line "$STATUS_IN_PROGRESS")"
fi

# ── Determine new status and destination file ─────────────────────────────────
new_status="$current_status"
dest_file="$src_file"

if [[ "$current_status" == "$STATUS_BACKLOG" || "$current_status" == "$STATUS_READY" ]]; then
  new_status="$STATUS_IN_PROGRESS"
  dest_file="$QUEUE_FILE"
fi

# ── Apply changes ─────────────────────────────────────────────────────────────
_state_transaction_begin
if [[ "$src_file" != "$dest_file" ]]; then
  # Cross-file move: update ticket fields, append to dest, remove from src
  ticket=$(jq -c --arg id "$id" --arg s "$new_status" --arg a "$assignee" \
    --arg by "$stamp" --arg ts "$ts" '
    .tickets[] | select(.id | tostring == $id) |
    .status = $s |
    .accountable = ((.accountable // []) | if any(. == $a) then . else . + [$a] end) |
    .updated_by = $by |
    .updated_at = $ts
  ' "$src_file")
  _move_ticket_json "$src_file" "$dest_file" "$id" "$ticket"
else
  jq_inplace "$src_file" --arg id "$id" --arg s "$new_status" --arg a "$assignee" \
    --arg by "$stamp" --arg ts "$ts" '
    (.tickets[] | select(.id | tostring == $id)) |= . + {
      status: $s,
      accountable: ((.accountable // []) | if any(. == $a) then . else . + [$a] end),
      updated_by: $by,
      updated_at: $ts
    }'
fi
_state_transaction_commit

src_file="$dest_file"

# ── Output ────────────────────────────────────────────────────────────────────
if $json; then
  jq --arg id "$id" '.tickets[] | select(.id | tostring == $id)' "$src_file"
  exit 0
fi

_status_ok '#%s taken — %s' "$id" "$(_terminal_safe_line "$new_status")"
_print_ticket "$id" "$src_file"
