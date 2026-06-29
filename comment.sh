#!/usr/bin/env bash
# comment.sh — Add, edit, or remove comments on a ticket
#
# Usage:
#   atoshell comment <id> [text]
#   atoshell comment <id> edit <comm_id> [text]
#   atoshell comment <id> delete <comm_id>
#
# Aliases: kaku, mark, note
#
# Options:
#   --as <agent-N|number>  Attribute a new comment to a numbered agent in non-interactive mode
# Options (Output):
#   --json|-j              Output changed ticket as JSON
#   --help|-h              Show 'comment' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup

# ── Parse args ────────────────────────────────────────────────────────────────
action="add"
as=""
id="" text="" comment_id=""
json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
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
      if [[ -z "$id" ]]; then
        id="$1"
      elif [[ "$action" == "add" && -z "$text" && \
              ("$1" == "delete" || "$1" == "edit" || "$1" == "add") ]]; then
        case "$1" in
          add)    action="add"    ;;
          edit)   action="update" ;;
          delete) action="delete" ;;
        esac
      elif [[ ("$action" == "delete" || "$action" == "update") && -z "$comment_id" ]]; then
        comment_id="$1"
      else
        text="${text:+$text }$1"
      fi
      shift ;;
  esac
done

# ── Resolve ticket ────────────────────────────────────────────────────────────
[[ -z "$id" ]] && _cli_error "$json" "MISSING_ARGUMENT" "missing ticket ID. Usage: atoshell comment <id> [text]." "argument" "id"
[[ ! "$id" =~ ^[0-9]+$ ]] && _cli_error "$json" "INVALID_TICKET_ID" "ticket ID must be a number." "got" "$id"
if [[ "$action" == "delete" || "$action" == "update" ]]; then
  [[ -z "$comment_id" ]] && _cli_error "$json" "MISSING_ARGUMENT" "$action requires a comment number." "argument" "comment_id"
  [[ "$comment_id" =~ ^[0-9]+$ ]] || _cli_error "$json" "INVALID_ARGUMENT" "comment number must be a positive integer." "got" "$comment_id"
fi
if [[ -n "$as" && "$action" != "add" ]]; then
  _cli_error "$json" "INVALID_ARGUMENT" "--as only applies when adding a new comment." "option" "--as"
fi

src_file=$(_find_ticket_file "$id" 2>/dev/null) || _cli_error "$json" "TICKET_NOT_FOUND" "ticket #$id not found." "id" "$id"

# ── Delete ────────────────────────────────────────────────────────────────────
if [[ "$action" == "delete" ]]; then
  idx=$(( comment_id - 1 ))
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")

  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    _cli_error "$json" "COMMENT_NOT_FOUND" "comment #$comment_id does not exist on ticket #$id." "id" "$id" "comment" "$comment_id"
  fi

  _state_lock_acquire
  src_file=$(_find_ticket_file "$id")
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")
  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    _cli_error "$json" "COMMENT_NOT_FOUND" "comment #$comment_id does not exist on ticket #$id." "id" "$id" "comment" "$comment_id"
  fi

  # Remove by index - rebuild the array excluding the target entry
  _state_transaction_begin
  jq_inplace "$src_file" \
    --arg     id  "$id" \
    --argjson idx "$idx" \
    '(.tickets[] | select(.id | tostring == $id) | .comments) |=
      [to_entries[] | select(.key != $idx) | .value]'
  _state_transaction_commit

  if $json; then
    jq --arg id "$id" '.tickets[] | select(.id | tostring == $id)' "$src_file"
    exit 0
  fi

  _outf '\n  Comment #%s deleted from #%s.\n\n' "$comment_id" "$id"
  exit 0
fi

# ── Change ────────────────────────────────────────────────────────────────────
if [[ "$action" == "update" ]]; then
  idx=$(( comment_id - 1 ))
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")

  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    _cli_error "$json" "COMMENT_NOT_FOUND" "comment #$comment_id does not exist on ticket #$id." "id" "$id" "comment" "$comment_id"
  fi

  # Text prompt if not set inline
  if [[ -z "$text" ]]; then
    $json && _cli_error "$json" "MISSING_ARGUMENT" "comment text is required in JSON mode." "argument" "text"
    existing=$(_jq_text --arg id "$id" --argjson idx "$idx" \
      '.tickets[] | select(.id | tostring == $id) | .comments[$idx].text' "$src_file")
    _tty_read_with_initial text '  Edit comment: ' "$(_terminal_safe_text "$existing")"
    [[ -z "$text" ]] && _cli_error "$json" "MISSING_ARGUMENT" "comment text is required." "argument" "text"
  fi

  text="$(_sanitize_text "$text")"
  _state_lock_acquire
  src_file=$(_find_ticket_file "$id")
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")
  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    _cli_error "$json" "COMMENT_NOT_FOUND" "comment #$comment_id does not exist on ticket #$id." "id" "$id" "comment" "$comment_id"
  fi

  _state_transaction_begin
  jq_inplace "$src_file" \
    --arg     id   "$id" \
    --argjson idx  "$idx" \
    --arg     text "$text" \
    --arg     ts   "$(_timestamp)" \
    '(.tickets[] | select(.id | tostring == $id) | .comments[$idx]) |= . + {text: $text, updated_at: $ts}'
  _state_transaction_commit

  if $json; then
    jq --arg id "$id" '.tickets[] | select(.id | tostring == $id)' "$src_file"
    exit 0
  fi

  _outf '\n  Comment #%s updated on #%s.\n\n' "$comment_id" "$id"
  exit 0
fi

# ── Add ───────────────────────────────────────────────────────────────────────
if [[ -z "$text" ]]; then
  $json && _cli_error "$json" "MISSING_ARGUMENT" "comment text is required in JSON mode." "argument" "text"
  printf '\n'
  _tty_read_multiline text 'Comment (press Enter on a blank line to finish):'
  [[ -z "$text" ]] && _cli_error "$json" "MISSING_ARGUMENT" "comment text is required." "argument" "text"
fi

text="$(_sanitize_text "$text")"
author="$(_resolve_actor "$as" "$json")"
_state_lock_acquire
src_file=$(_find_ticket_file "$id")
_state_transaction_begin
jq_inplace "$src_file" \
  --arg id     "$id" \
  --arg text   "$text" \
  --arg author "$author" \
  --arg ts     "$(_timestamp)" \
  '(.tickets[] | select(.id | tostring == $id) | .comments) += [{
     author: $author, text: $text, created_at: $ts
   }]'
_state_transaction_commit

if $json; then
  jq --arg id "$id" '.tickets[] | select(.id | tostring == $id)' "$src_file"
  exit 0
fi

_outf '\n  Comment added to #%s by %s.\n\n' "$id" "$(_terminal_safe_line "$author")"
