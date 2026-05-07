#!/usr/bin/env bash
# delete.sh — Delete one or more tickets
#
# Usage:
#   atoshell delete <id[,id,...]> [options]
#
# Aliases: kesu, wipe
#
# Options:
#   --yes|-y   Skip confirmation prompts (also auto-removes dangling dependencies)
# Options (Output):
#   --help|-h  Show 'delete' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup

# ── Parse flags ───────────────────────────────────────────────────────────────
yes=false
ids=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --yes|-y)
      yes=true
      shift ;;
    -*)
      printf 'Error: unknown option "%s".\n' "$(_terminal_safe_line "$1")" >&2; exit 1 ;;
    *)
      # Splits id list using commas to save to a list
      IFS=',' read -ra _ids <<< "$1"
      for _id in "${_ids[@]}"; do
        _id="${_id// /}"
        [[ ! "$_id" =~ ^[0-9]+$ ]] && { printf 'Error: ticket ID must be a number, got "%s".\n' "$(_terminal_safe_line "$_id")" >&2; exit 1; }
        ids+=("$_id")
      done
      shift ;;
  esac
done

# ── Empty check ───────────────────────────────────────────────────────────────
[[ "${#ids[@]}" -eq 0 ]] && { printf 'Error: missing ticket ID(s).\nUsage: atoshell delete <id[,id,...]> [--yes]\n' >&2; exit 1; }

# ── Delete ────────────────────────────────────────────────────────────────────
_outf '\n'
failed=false
delete_messages=()
_state_lock_acquire
_state_transaction_begin
for id in "${ids[@]}"; do
  if ! src_file=$(_find_ticket_file "$id" 2>/dev/null); then
    _outf '  Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
    failed=true
    continue
  fi
  title=$(_jq_text --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .title' "$src_file" 2>/dev/null)
  title_display="$(_terminal_safe_line "$title")"

  if ! $yes; then
    ask_yn "Delete #$id: \"$title_display\"?" "n" || { delete_messages+=("$(printf '  Skipped #%s.' "$id")"); continue; }
  fi

  jq_inplace "$src_file" --arg id "$id" 'del(.tickets[] | select(.id | tostring == $id))'
  delete_messages+=("$(printf '  Deleted #%s.' "$id")")

  # Warn about (and offer to remove) any tickets that depend on the deleted ID
  for dep_file in "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"; do
    [[ ! -f "$dep_file" ]] && continue
    mapfile -t dependents < <(_jq_text --argjson id "$id" \
      '.tickets[] | select(.dependencies | map(. == $id) | any) | .id | tostring' "$(_state_transaction_current_file "$dep_file")")
    for dep_id in "${dependents[@]}"; do
      dep_title=$(_jq_text --arg dep_id "$dep_id" '.tickets[] | select(.id | tostring == $dep_id) | .title' "$(_state_transaction_current_file "$dep_file")")
      dep_title_display="$(_terminal_safe_line "$dep_title")"
      if $yes || ask_yn "  #$dep_id \"$dep_title_display\" depends on #$id — remove that dependency?" "y"; then
        jq_inplace "$dep_file" --argjson id "$id" --arg dep_id "$dep_id" \
          '(.tickets[] | select(.id | tostring == $dep_id) | .dependencies) |= map(select(. != $id))'
        delete_messages+=("$(printf '  Removed dependency on #%s from #%s.' "$id" "$dep_id")")
      else
        delete_messages+=("$(printf '  Warning: #%s still lists deleted ticket #%s as a dependency.' "$dep_id" "$id")")
      fi
    done
  done
done
_state_transaction_commit
for msg in "${delete_messages[@]}"; do
  _outf '%s\n' "$msg"
done
_outf '\n'
if [[ "$failed" == true ]]; then exit 1; fi
