#!/usr/bin/env bash
# move.sh — Move ticket(s) to a new status (workflow transition)
#
# Usage:
#   atoshell move <id[,id,...]> <status|column_number>
#
# Aliases: ido, shift
#
# Examples:
#   atoshell move 8 ready
#   atoshell move 3,7 in progress
#   atoshell move 8 3
#
# Options:
#   --as <agent-N|number>  Attribute updated_by to a numbered agent in non-interactive mode
# Options (Output):
#   --json|-j              Output moved tickets as a JSON array
#   --help|-h              Show 'move' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup_readonly

# ── Parse args ────────────────────────────────────────────────────────────────
ids_raw=""
as=""
json=false
status_parts=()
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      _show_help "${BASH_SOURCE[0]}"
      exit 0 ;;
    --as)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--as"
      as="$2"
      shift 2 ;;
    --json|-j)
      json=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        _cli_error "$json" "UNKNOWN_OPTION" "unknown option \"$1\"." "option" "$1"
      fi
      if [[ -z "$ids_raw" ]]; then
        ids_raw="$1"
      else
        status_parts+=("$1")
      fi
      shift ;;
  esac
done

[[ -z "$ids_raw" ]] && {
  _cli_error "$json" "MISSING_ARGUMENT" "missing ticket ID(s). Usage: atoshell move <id[,id,...]> <status|column_number>." "argument" "id"
}

[[ "${#status_parts[@]}" -eq 0 ]] && {
  _cli_error "$json" "MISSING_ARGUMENT" "status is required. Usage: atoshell move <id[,id,...]> <status|column_number>." "argument" "status"
}

# Remaining args = status (supports multi-word without quotes, e.g. move 3 in progress)
raw_status="${status_parts[*]}"
actor="$(_resolve_actor "$as" "$json")"

status_val="$(_resolve_status "$raw_status" "$json")"
dest_file="$(_status_to_file "$status_val")"
ts="$(_timestamp)"

# ── Process each ID ───────────────────────────────────────────────────────────
if [[ "$ids_raw" == *,* && ( "$ids_raw" == ,* || "$ids_raw" == *, || "$ids_raw" == *,,* ) ]]; then
  _cli_error "$json" "INVALID_TICKET_ID" "empty ticket ID in \"$ids_raw\"." "got" "$ids_raw"
fi

IFS=',' read -ra ids <<< "$ids_raw"
declare -a move_messages=()
declare -a moved_tickets=()
seen_ids=","

for ticket_id in "${ids[@]}"; do
  ticket_id="${ticket_id// /}"
  if [[ -z "$ticket_id" ]]; then
    _cli_error "$json" "INVALID_TICKET_ID" "empty ticket ID in \"$ids_raw\"." "got" "$ids_raw"
  fi
  if [[ ! "$ticket_id" =~ ^[0-9]+$ ]]; then
    _cli_error "$json" "INVALID_TICKET_ID" "ticket ID must be a number." "got" "$ticket_id"
  fi
  if [[ "$seen_ids" == *",$ticket_id,"* ]]; then
    _cli_error "$json" "INVALID_ARGUMENT" "duplicate ticket ID #$ticket_id." "id" "$ticket_id"
  fi
  seen_ids+="$ticket_id,"
done

_state_lock_acquire
for ticket_id in "${ids[@]}"; do
  ticket_id="${ticket_id// /}"
  jq -s -e --arg id "$ticket_id" '
    any(.[]; any(.tickets[]?; (.id | tostring) == $id))
  ' "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE" >/dev/null 2>&1 ||
    _cli_error "$json" "TICKET_NOT_FOUND" "ticket #$ticket_id not found." "id" "$ticket_id"
done

_state_transaction_begin
for ticket_id in "${ids[@]}"; do
  ticket_id="${ticket_id// /}"

  move_lookup=$(jq -n -r \
    --arg id "$ticket_id" --arg s "$status_val" --arg by "$actor" --arg ts "$ts" \
    --slurpfile queue "$(_state_transaction_current_file "$QUEUE_FILE")" \
    --slurpfile backlog "$(_state_transaction_current_file "$BACKLOG_FILE")" \
    --slurpfile done "$(_state_transaction_current_file "$DONE_FILE")" '
    def hit($source; $data):
      $data[0].tickets[]? |
      select(.id | tostring == $id) |
      [$source, (. + {status: $s, updated_by: $by, updated_at: $ts} | tojson)] |
      @tsv;
    first(
      hit("queue"; $queue),
      hit("backlog"; $backlog),
      hit("done"; $done)
    ) // empty')

  if [[ -z "$move_lookup" ]]; then
    _cli_error "$json" "TICKET_NOT_FOUND" "ticket #$ticket_id not found." "id" "$ticket_id"
  fi

  IFS=$'\t' read -r src_key ticket <<< "$move_lookup"
  case "$src_key" in
    queue)    src_file="$QUEUE_FILE" ;;
    backlog)  src_file="$BACKLOG_FILE" ;;
    done)     src_file="$DONE_FILE" ;;
    *)
      _cli_error "$json" "TICKET_NOT_FOUND" "ticket #$ticket_id not found." "id" "$ticket_id" ;;
  esac
  if [[ "$ATOSHELL_QUIET" != "1" && "$json" != true ]]; then
    title=$(_jq_text '.title' <<< "$ticket")
    title_display="$(_terminal_safe_line "$title")"
  fi

  if [[ "$src_file" != "$dest_file" ]]; then
    _move_ticket_json "$src_file" "$dest_file" "$ticket_id" "$ticket"
  else
    jq_inplace "$src_file" --arg id "$ticket_id" --arg s "$status_val" \
      --arg by "$actor" --arg ts "$ts" \
      '(.tickets[] | select(.id | tostring == $id)) |=
        . + {status: $s, updated_by: $by, updated_at: $ts}'
  fi
  moved_tickets+=("$ticket")

  if [[ "$ATOSHELL_QUIET" != "1" && "$json" != true ]]; then
    status_display="$(_terminal_safe_line "$status_val")"
    move_messages+=("$(printf '  [OK] #%s %s → %s' "$ticket_id" "$title_display" "$status_display")")
  fi
done
_state_transaction_commit

if $json; then
  printf '%s\n' "${moved_tickets[@]}" | jq -s '.'
  exit 0
fi

for msg in "${move_messages[@]+"${move_messages[@]}"}"; do
  _outln "$msg"
done
_outf '\n'
