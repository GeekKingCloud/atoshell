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
declare -a delete_messages=()
declare -a confirmed_ids=()
declare -A dep_prompted=()
declare -A dep_remove_confirmed=()

if ! $yes; then
  for id in "${ids[@]}"; do
    if ! src_file=$(_find_ticket_file "$id" 2>/dev/null); then
      _outf '  Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
      failed=true
      continue
    fi
    title=$(_jq_text --arg id "$id" '.tickets[] | select(.id | tostring == $id) | .title' "$src_file" 2>/dev/null)
    title_display="$(_terminal_safe_line "$title")"

    if ask_yn "Delete #$id: \"$title_display\"?" "n"; then
      confirmed_ids+=("$id")
    else
      delete_messages+=("$(printf '  Skipped #%s.' "$id")")
      continue
    fi

    for dep_file in "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"; do
      [[ ! -f "$dep_file" ]] && continue
      declare -a dependents=()
      mapfile -t dependents < <(_jq_text --argjson id "$id" \
        '.tickets[] | select(.dependencies | map(. == $id) | any) | .id | tostring' "$dep_file")
      for dep_id in "${dependents[@]+"${dependents[@]}"}"; do
        dep_prompted["$id:$dep_id"]=1
        dep_title=$(_jq_text --arg dep_id "$dep_id" '.tickets[] | select(.id | tostring == $dep_id) | .title' "$dep_file")
        dep_title_display="$(_terminal_safe_line "$dep_title")"
        if ask_yn "  #$dep_id \"$dep_title_display\" depends on #$id — remove that dependency?" "y"; then
          dep_remove_confirmed["$id:$dep_id"]=1
        else
          delete_messages+=("$(printf '  Warning: #%s still lists deleted ticket #%s as a dependency.' "$dep_id" "$id")")
        fi
      done
    done
  done
else
  confirmed_ids=("${ids[@]}")
fi

if [[ "${#confirmed_ids[@]}" -eq 0 ]]; then
  for msg in "${delete_messages[@]+"${delete_messages[@]}"}"; do
    _outln "$msg"
  done
  _outf '\n'
  if [[ "$failed" == true ]]; then exit 1; fi
  exit 0
fi

_state_lock_acquire
_state_transaction_begin
for id in "${confirmed_ids[@]+"${confirmed_ids[@]}"}"; do
  if ! src_file=$(_find_ticket_file "$id" 2>/dev/null); then
    _outf '  Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
    failed=true
    continue
  fi
  jq_inplace "$src_file" --arg id "$id" 'del(.tickets[] | select(.id | tostring == $id))'
  delete_messages+=("$(printf '  Deleted #%s.' "$id")")

  for dep_file in "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"; do
    [[ ! -f "$dep_file" ]] && continue
    declare -a dependents=()
    mapfile -t dependents < <(_jq_text --argjson id "$id" \
      '.tickets[] | select(.dependencies | map(. == $id) | any) | .id | tostring' "$(_state_transaction_current_file "$dep_file")")
    for dep_id in "${dependents[@]+"${dependents[@]}"}"; do
      if $yes || [[ -n "${dep_remove_confirmed["$id:$dep_id"]+_}" ]]; then
        jq_inplace "$dep_file" --argjson id "$id" --arg dep_id "$dep_id" \
          '(.tickets[] | select(.id | tostring == $dep_id) | .dependencies) |= map(select(. != $id))'
        delete_messages+=("$(printf '  Removed dependency on #%s from #%s.' "$id" "$dep_id")")
      elif [[ -z "${dep_prompted["$id:$dep_id"]+_}" ]]; then
        delete_messages+=("$(printf '  Warning: #%s still lists deleted ticket #%s as a dependency.' "$dep_id" "$id")")
      fi
    done
  done
done
_state_transaction_commit
for msg in "${delete_messages[@]+"${delete_messages[@]}"}"; do
  _outln "$msg"
done
_outf '\n'
if [[ "$failed" == true ]]; then exit 1; fi
