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
#   --help|-h              Show 'comment' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup

# ── Parse args ────────────────────────────────────────────────────────────────
action="add"
as=""
id="" text="" comment_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --as)
      [[ $# -lt 2 ]] && { printf 'Error: --as requires a value.\n' >&2; exit 1; }
      as="$2"
      shift 2 ;;
    *)
      if [[ "$1" == -* ]]; then
        printf 'Error: unknown option "%s".\n' "$(_terminal_safe_line "$1")" >&2
        exit 1
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
[[ -z "$id" ]] && { printf 'Error: missing ticket ID.\nUsage: atoshell comment <id> [text]\n' >&2; exit 1; }
[[ ! "$id" =~ ^[0-9]+$ ]] && { printf 'Error: ticket ID must be a number, got "%s".\n' "$(_terminal_safe_line "$id")" >&2; exit 1; }
if [[ "$action" == "delete" || "$action" == "update" ]]; then
  [[ -z "$comment_id" ]] && { printf 'Error: %s requires a comment number.\n' "$action" >&2; exit 1; }
  [[ "$comment_id" =~ ^[0-9]+$ ]] || { printf 'Error: comment number must be a positive integer, got "%s".\n' "$(_terminal_safe_line "$comment_id")" >&2; exit 1; }
fi
if [[ -n "$as" && "$action" != "add" ]]; then
  printf 'Error: --as only applies when adding a new comment.\n' >&2
  exit 1
fi

_state_lock_acquire
src_file=$(_find_ticket_file "$id")

# ── Delete ────────────────────────────────────────────────────────────────────
if [[ "$action" == "delete" ]]; then
  idx=$(( comment_id - 1 ))
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")

  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    printf 'Error: comment #%s does not exist on ticket #%s.\n' "$(_terminal_safe_line "$comment_id")" "$(_terminal_safe_line "$id")" >&2; exit 1
  fi

  # Remove by index - rebuild the array excluding the target entry
  _state_transaction_begin
  jq_inplace "$src_file" \
    --arg     id  "$id" \
    --argjson idx "$idx" \
    '(.tickets[] | select(.id | tostring == $id) | .comments) |=
      [to_entries[] | select(.key != $idx) | .value]'
  _state_transaction_commit

  _outf '\n  Comment #%s deleted from #%s.\n\n' "$comment_id" "$id"
  exit 0
fi

# ── Change ────────────────────────────────────────────────────────────────────
if [[ "$action" == "update" ]]; then
  idx=$(( comment_id - 1 ))
  cmt_count=$(jq --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .comments | length' "$src_file")

  if [[ "$idx" -lt 0 || "$idx" -ge "$cmt_count" ]]; then
    printf 'Error: comment #%s does not exist on ticket #%s.\n' "$(_terminal_safe_line "$comment_id")" "$(_terminal_safe_line "$id")" >&2; exit 1
  fi

  # Text prompt if not set inline
  if [[ -z "$text" ]]; then
    existing=$(_jq_text --arg id "$id" --argjson idx "$idx" \
      '.tickets[] | select(.id | tostring == $id) | .comments[$idx].text' "$src_file")
    _tty_read_with_initial text '  Edit comment: ' "$(_terminal_safe_text "$existing")"
    [[ -z "$text" ]] && { printf 'Error: comment text is required.\n' >&2; exit 1; }
  fi

  text="$(_sanitize_text "$text")"
  _state_transaction_begin
  jq_inplace "$src_file" \
    --arg     id   "$id" \
    --argjson idx  "$idx" \
    --arg     text "$text" \
    --arg     ts   "$(_timestamp)" \
    '(.tickets[] | select(.id | tostring == $id) | .comments[$idx]) |= . + {text: $text, updated_at: $ts}'
  _state_transaction_commit

  _outf '\n  Comment #%s updated on #%s.\n\n' "$comment_id" "$id"
  exit 0
fi

# ── Add ───────────────────────────────────────────────────────────────────────
if [[ -z "$text" ]]; then
  printf '\n'
  _tty_read_multiline text 'Comment (press Enter on a blank line to finish):'
  [[ -z "$text" ]] && { printf 'Error: comment text is required.\n' >&2; exit 1; }
fi

text="$(_sanitize_text "$text")"
author="$(_resolve_actor "$as")"
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

_outf '\n  Comment added to #%s by %s.\n\n' "$id" "$(_terminal_safe_line "$author")"
