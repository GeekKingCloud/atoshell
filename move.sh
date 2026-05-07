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
#   --help|-h              Show 'move' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup_readonly

# ── Parse args ────────────────────────────────────────────────────────────────
ids_raw=""
as=""
status_parts=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      _show_help "${BASH_SOURCE[0]}"
      exit 0 ;;
    --as)
      [[ $# -lt 2 ]] && { printf 'Error: --as requires a value.\n' >&2; exit 1; }
      as="$2"
      shift 2 ;;
    *)
      if [[ "$1" == -* ]]; then
        printf 'Error: unknown option "%s".\n' "$(_terminal_safe_line "$1")" >&2
        exit 1
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
  printf 'Error: missing ticket ID(s).\nUsage: atoshell move <id[,id,...]> <status|column_number>\n' >&2
  printf '\nColumn numbers: 1=Backlog  2=Ready  3=In Progress  4=Done\n' >&2
  exit 1
}

[[ "${#status_parts[@]}" -eq 0 ]] && {
  printf 'Error: status is required.\nUsage: atoshell move <id[,id,...]> <status|column_number>\n' >&2
  exit 1
}

# Remaining args = status (supports multi-word without quotes, e.g. move 3 in progress)
raw_status="${status_parts[*]}"
actor="$(_resolve_actor "$as")"

status_val="$(_resolve_status "$raw_status")"
dest_file="$(_status_to_file "$status_val")"
ts="$(_timestamp)"

# ── Process each ID ───────────────────────────────────────────────────────────
if [[ "$ids_raw" == *,* && ( "$ids_raw" == ,* || "$ids_raw" == *, || "$ids_raw" == *,,* ) ]]; then
  printf 'Error: empty ticket ID in "%s".\n' "$(_terminal_safe_line "$ids_raw")" >&2
  exit 1
fi

IFS=',' read -ra ids <<< "$ids_raw"
move_messages=()
seen_ids=","

for ticket_id in "${ids[@]}"; do
  ticket_id="${ticket_id// /}"
  if [[ -z "$ticket_id" ]]; then
    printf 'Error: empty ticket ID in "%s".\n' "$(_terminal_safe_line "$ids_raw")" >&2
    exit 1
  fi
  if [[ "$seen_ids" == *",$ticket_id,"* ]]; then
    printf 'Error: duplicate ticket ID #%s.\n' "$(_terminal_safe_line "$ticket_id")" >&2
    exit 1
  fi
  seen_ids+="$ticket_id,"
done

_state_lock_acquire
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
    printf 'Error: ticket #%s not found.\n' "$(_terminal_safe_line "$ticket_id")" >&2
    exit 2
  fi

  IFS=$'\t' read -r src_key ticket <<< "$move_lookup"
  case "$src_key" in
    queue)    src_file="$QUEUE_FILE" ;;
    backlog)  src_file="$BACKLOG_FILE" ;;
    done)     src_file="$DONE_FILE" ;;
    *)
      printf 'Error: ticket #%s not found.\n' "$(_terminal_safe_line "$ticket_id")" >&2
      exit 2 ;;
  esac
  if [[ "$ATOSHELL_QUIET" != "1" ]]; then
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
  if [[ "$ATOSHELL_QUIET" != "1" ]]; then
    status_display="$(_terminal_safe_line "$status_val")"
    move_messages+=("$(printf '  [OK] #%s %s → %s' "$ticket_id" "$title_display" "$status_display")")
  fi
done
_state_transaction_commit
for msg in "${move_messages[@]}"; do
  _outf '%s\n' "$msg"
done
_outf '\n'
