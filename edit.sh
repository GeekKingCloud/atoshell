#!/usr/bin/env bash
# edit.sh — Edit ticket properties
#
# Usage:
#   atoshell edit <id> [options]
#
# Aliases: henshu, mod
#
# Options:
#   --title|-T <text|change>                                            Update title; "change" = interactive
#   --description|--desc|--body|-b <text|change>                        Update description; "change" = interactive
#   --type|--kind|-t <name|0-2>                                         Set ticket type (0=Bug 1=Feature 2=Task)
#   --priority|-p <value|0-3>                                           Set priority (P0/P1/P2/P3 or 0–3)
#   --size|-s <value|0-4>                                               Set size (XS/S/M/L/XL or 0–4)
#   --status|--move|-S <status|col#>                                    Move ticket (name, multi-word, or column number 1–4)
#   --disciplines|--discipline|--dis|-d [add|remove|clear] <vals>       Manage fixed discipline tags (default: add)
#   --accountable|--assign|-a [add|remove|clear] <vals>                 Manage accountable (default: add)
#   --dependencies|--dependency|--depends|-D [add|remove|clear] <vals>  Manage dependencies (default: add)
#   --as <agent-N|number>                                               Attribute updated_by to a numbered agent in non-interactive mode
# Options (Output):
#   --help|-h                                                           Show 'edit' usage help and exit
#
# To add, edit or remove comments: atoshell comment <id> [options]
#
# Valid disciplines (fixed): Frontend, Backend, Database, Cloud, DevOps, Architecture, Automation, QA, Research, Core
# Discipline aliases: fe=Frontend, be=Backend
# Use the narrowest accurate discipline set.

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
_setup

# ── Resolve ticket ────────────────────────────────────────────────────────────
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { _show_help "${BASH_SOURCE[0]}"; exit 0; }
ticket_id="${1:-}"
[[ -z "$ticket_id" || "$ticket_id" == -* ]] && { printf 'Error: missing ticket ID.\nUsage: atoshell edit <id> [flags]\n' >&2; exit 1; }
shift
_state_lock_acquire
src_file="$(_find_ticket_file "$ticket_id")"

# ── Parse flags ───────────────────────────────────────────────────────────────
title_interactive=false title=""
desc_interactive=false desc_changed=false description=""
type="" priority="" size="" status=""
disc_action=""   disc_ids=()
acct_action=""   acct_ids=()
dep_action=""    dep_ids=()
as=""
any_changes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title|-T)
      [[ $# -lt 2 ]] && { printf 'Error: --title requires a value or "change".\n' >&2; exit 1; }
      val="$2"
      shift 2
      if [[ "$val" == "change" ]]; then
        title_interactive=true
      else
        [[ -z "$val" ]] && { printf 'Error: ticket title cannot be empty.\n' >&2; exit 1; }
        title="$(_sanitize_line "$val")"
      fi
      any_changes=true ;;
    --description|--desc|--body|-b)
      [[ $# -lt 2 ]] && { printf 'Error: --description requires a value or "change".\n' >&2; exit 1; }
      val="$2"
      shift 2
      if [[ "$val" == "change" ]]; then
        desc_interactive=true
      else
        description="$(_sanitize_text "$val")"
      fi
      desc_changed=true
      any_changes=true ;;
    --type|--kind|-t)
      [[ $# -lt 2 ]] && { printf 'Error: --type requires a value.\n' >&2; exit 1; }
      val="$2"
      shift 2
      type="$(_resolve_type "$val")"
      any_changes=true ;;
    --priority|-p)
      [[ $# -lt 2 ]] && { printf 'Error: --priority requires a value.\n' >&2; exit 1; }
      priority="$(_resolve_priority "$2")"
      shift 2
      any_changes=true ;;
    --size|-s)
      [[ $# -lt 2 ]] && { printf 'Error: --size requires a value.\n' >&2; exit 1; }
      size="$(_resolve_size "$2")"
      shift 2
      any_changes=true ;;
    --status|--move|-S)
      # Collect all remaining non-flag words as the status (supports "in progress" without quotes)
      shift  # consume the flag itself
      [[ $# -eq 0 ]] && { printf 'Error: --status requires a value.\n' >&2; exit 1; }
      raw_status=""
      while [[ $# -gt 0 && "$1" != --* ]]; do
        raw_status="${raw_status:+$raw_status }$1"; shift
      done
      status="$(_resolve_status "$raw_status")"
      any_changes=true ;;
    --disciplines|--discipline|--dis|-d)
      [[ $# -lt 2 ]] && { printf 'Error: --disciplines requires values.\n' >&2; exit 1; }
      if [[ "$2" == "add" || "$2" == "remove" || "$2" == "rm" || "$2" == "clear" ]]; then
        sub="$2"; shift 2
      else
        sub="add"; shift
      fi
      case "$sub" in
        add)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --disciplines add requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          disc_action="add"
          for d in "${_v[@]}"; do disc_ids+=("${d// /}"); done
          any_changes=true ;;
        remove|rm)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --disciplines remove requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          disc_action="remove"
          for d in "${_v[@]}"; do disc_ids+=("${d// /}"); done
          any_changes=true ;;
        clear)
          disc_action="clear"
          any_changes=true ;;
        *)
          printf 'Error: --disciplines requires add|remove|clear, got "%s".\n' "$(_terminal_safe_line "$sub")" >&2
          exit 1 ;;
      esac ;;
    --accountable|--assign|-a)
      [[ $# -lt 2 ]] && { printf 'Error: --accountable requires values.\n' >&2; exit 1; }
      if [[ "$2" == "add" || "$2" == "remove" || "$2" == "rm" || "$2" == "clear" ]]; then
        sub="$2"; shift 2
      else
        if [[ $# -ge 3 && "$3" != --* ]]; then
          printf 'Error: --accountable requires add|remove|clear, got "%s".\n' "$(_terminal_safe_line "$2")" >&2
          exit 1
        fi
        sub="add"; shift
      fi
      case "$sub" in
        add)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --accountable add requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          acct_action="add"
          for u in "${_v[@]}"; do
            u="${u// /}"
            [[ "$u" == "me" ]]    && u="$USERNAME"
            [[ "$u" == "agent" ]] && u="[agent]"
            acct_ids+=("$u")
          done
          any_changes=true ;;
        remove|rm)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --accountable remove requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          acct_action="remove"
          for u in "${_v[@]}"; do
            u="${u// /}"
            [[ "$u" == "me" ]]    && u="$USERNAME"
            [[ "$u" == "agent" ]] && u="[agent]"
            acct_ids+=("$u")
          done
          any_changes=true ;;
        clear)
          acct_action="clear"
          any_changes=true ;;
        *)
          printf 'Error: --accountable requires add|remove|clear, got "%s".\n' "$(_terminal_safe_line "$sub")" >&2
          exit 1 ;;
      esac ;;
    --dependencies|--dependency|--depends|-D)
      [[ $# -lt 2 ]] && { printf 'Error: --dependencies requires values.\n' >&2; exit 1; }
      if [[ "$2" == "add" || "$2" == "remove" || "$2" == "rm" || "$2" == "clear" ]]; then
        sub="$2"; shift 2
      else
        sub="add"; shift
      fi
      case "$sub" in
        add)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --dependencies add requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          dep_action="add"
          dep_ids+=("${_v[@]}")
          any_changes=true ;;
        remove|rm)
          [[ $# -eq 0 || "$1" == --* ]] && { printf 'Error: --dependencies remove requires values.\n' >&2; exit 1; }
          IFS=',' read -ra _v <<< "$1"; shift
          dep_action="remove"
          dep_ids+=("${_v[@]}")
          any_changes=true ;;
        clear)
          dep_action="clear"
          any_changes=true ;;
        *)
          printf 'Error: --dependencies requires add|remove|clear, got "%s".\n' "$(_terminal_safe_line "$sub")" >&2
          exit 1 ;;
      esac ;;
    --as)
      [[ $# -lt 2 ]] && { printf 'Error: --as requires a value.\n' >&2; exit 1; }
      as="$2"
      shift 2 ;;
    *)
      printf 'Error: unknown flag: %s\n' "$(_terminal_safe_line "$1")" >&2
      printf 'Run "atoshell help" for usage.\n' >&2
      exit 1 ;;
  esac
done

$any_changes || {
  printf 'Error: no changes specified. Run "atoshell help" for usage.\n' >&2
  exit 1
}

actor="$(_resolve_actor "$as")"

# ── Interactive prompts ───────────────────────────────────────────────────────
if $title_interactive; then
  current_title=$(jq -r --arg id "$ticket_id" \
    '.tickets[] | select(.id | tostring == $id) | .title' "$src_file")
  _tty_read_with_initial title '  Title: ' "$(_terminal_safe_line "$current_title")"
  title="$(_sanitize_line "$title")"
  [[ -z "$title" ]] && { printf 'Error: ticket title cannot be empty.\n' >&2; exit 1; }
fi

if $desc_interactive; then
  current_desc=$(jq -r --arg id "$ticket_id" \
    '.tickets[] | select(.id | tostring == $id) | .description // ""' "$src_file")
  _tty_read_with_initial description '  Description: ' "$(_terminal_safe_text "$current_desc")"
  description="$(_sanitize_text "$description")"
fi

# ── Pre-flight: validate and warn on removes ──────────────────────────────────
printf '\n'

# Disciplines: validate names, warn on remove if not present
resolved_disc_ids=()
for d in "${disc_ids[@]}"; do
  rd="$(_resolve_discipline "$d")"
  if [[ "$disc_action" == "remove" ]]; then
    present=$(jq -r --arg id "$ticket_id" --arg d "${rd,,}" \
      '.tickets[] | select(.id | tostring == $id)
       | .disciplines | map(ascii_downcase) | any(. == $d)' \
      "$src_file" 2>/dev/null || echo "false")
    if [[ "$present" != "true" ]]; then
      _outf '  [WARN] discipline "%s" not on ticket #%s — skipping.\n' "$rd" "$ticket_id"
    else
      resolved_disc_ids+=("$rd")
    fi
  else
    resolved_disc_ids+=("$rd")
  fi
done

# Accountable: warn on remove if not present
resolved_acct_ids=()
for u in "${acct_ids[@]}"; do
  if [[ "$acct_action" == "remove" ]]; then
    present=$(jq -r --arg id "$ticket_id" --arg u "${u,,}" \
      '.tickets[] | select(.id | tostring == $id)
       | .accountable | map(ascii_downcase) | any(. == $u)' \
      "$src_file" 2>/dev/null || echo "false")
    if [[ "$present" != "true" ]]; then
      _outf '  [WARN] accountable "%s" not on ticket #%s — skipping.\n' "$(_terminal_safe_line "$u")" "$ticket_id"
    else
      resolved_acct_ids+=("$u")
    fi
  else
    resolved_acct_ids+=("$u")
  fi
done

# Dependencies: warn on remove if not present
resolved_dep_ids=()
for dep in "${dep_ids[@]}"; do
  if [[ "$dep_action" == "remove" ]]; then
    present=$(jq -r --arg id "$ticket_id" --argjson dep "${dep}" \
      '.tickets[] | select(.id | tostring == $id)
       | .dependencies | any(. == $dep)' \
      "$src_file" 2>/dev/null || echo "false")
    if [[ "$present" != "true" ]]; then
      _outf '  [WARN] dependency #%s not on ticket #%s — skipping.\n' "$dep" "$ticket_id"
    else
      resolved_dep_ids+=("$dep")
    fi
  else
    _find_ticket_file "$dep" > /dev/null
    resolved_dep_ids+=("$dep")
  fi
done

if [[ "$dep_action" == "add" && "${#resolved_dep_ids[@]}" -gt 0 ]]; then
  mapfile -t existing_dep_ids < <(jq -r --arg id "$ticket_id" \
    '.tickets[] | select(.id | tostring == $id) | .dependencies[]? | tostring' "$src_file")
  combined_dep_ids=("${existing_dep_ids[@]+"${existing_dep_ids[@]}"}" "${resolved_dep_ids[@]}")
  if ! _check_cyclic_deps "$ticket_id" "${combined_dep_ids[@]}"; then
    printf 'Error: adding those dependencies would create a cycle involving ticket #%s.\n' "$ticket_id" >&2
    exit 1
  fi
fi

# ── Apply changes ─────────────────────────────────────────────────────────────
edit_messages=()
_edit_record() {
  local fmt="$1"
  shift
  edit_messages+=("$(_terminal_safe_text "$(printf "$fmt" "$@")")")
}

_state_transaction_begin
# Title
if [[ -n "$title" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" --arg v "$title" \
    '(.tickets[] | select(.id | tostring == $id) | .title) = $v'
  _edit_record '  [OK] title → %s' "$title"
fi

# Description
if $desc_changed; then
  jq_inplace "$src_file" --arg id "$ticket_id" --arg v "$description" \
    '(.tickets[] | select(.id | tostring == $id) | .description) = $v'
  _edit_record '  [OK] description updated'
fi

# Type
if [[ -n "$type" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" --arg v "$type" \
    '(.tickets[] | select(.id | tostring == $id) | .type) = $v'
  _edit_record '  [OK] type → %s' "$type"
fi

# Priority
if [[ -n "$priority" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" --arg v "$priority" \
    '(.tickets[] | select(.id | tostring == $id) | .priority) = $v'
  _edit_record '  [OK] priority → %s' "$priority"
fi

# Size
if [[ -n "$size" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" --arg v "$size" \
    '(.tickets[] | select(.id | tostring == $id) | .size) = $v'
  _edit_record '  [OK] size → %s' "$size"
fi

# Status (may move ticket between files)
if [[ -n "$status" ]]; then
  dest_file="$(_status_to_file "$status")"
  if [[ "$src_file" != "$dest_file" ]]; then
    ticket=$(jq --arg id "$ticket_id" --arg s "$status" \
      '.tickets[] | select(.id | tostring == $id) | .status = $s' "$(_state_transaction_current_file "$src_file")")
    _move_ticket_json "$src_file" "$dest_file" "$ticket_id" "$ticket"
    src_file="$dest_file"   # subsequent changes apply to the new file
  else
    jq_inplace "$src_file" --arg id "$ticket_id" --arg s "$status" \
      '(.tickets[] | select(.id | tostring == $id) | .status) = $s'
  fi
  _edit_record '  [OK] status → %s' "$status"
fi

# Disciplines
if [[ "$disc_action" == "clear" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" \
    '(.tickets[] | select(.id | tostring == $id) | .disciplines) = []'
  _edit_record '  [OK] disciplines cleared'
elif [[ "$disc_action" == "remove" && "${#resolved_disc_ids[@]}" -gt 0 ]]; then
  rm_json=$(printf '%s\n' "${resolved_disc_ids[@]}" | jq -R 'ascii_downcase' | jq -s '.')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson rm "$rm_json" \
    '(.tickets[] | select(.id | tostring == $id) | .disciplines) |=
      map(select(ascii_downcase as $v | $rm | any(. == $v) | not))'
  _edit_record '  [OK] disciplines removed: %s' "$(IFS=', '; echo "${resolved_disc_ids[*]}")"
elif [[ "$disc_action" == "add" && "${#resolved_disc_ids[@]}" -gt 0 ]]; then
  add_json=$(printf '%s\n' "${resolved_disc_ids[@]}" | jq -R '.' | jq -s '.')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson add "$add_json" \
    '(.tickets[] | select(.id | tostring == $id) | .disciplines) |= (. + $add | unique)'
  _edit_record '  [OK] disciplines added: %s' "$(IFS=', '; echo "${resolved_disc_ids[*]}")"
fi

# Accountable
if [[ "$acct_action" == "clear" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" \
    '(.tickets[] | select(.id | tostring == $id) | .accountable) = []'
  _edit_record '  [OK] accountable cleared'
elif [[ "$acct_action" == "remove" && "${#resolved_acct_ids[@]}" -gt 0 ]]; then
  rm_json=$(printf '%s\n' "${resolved_acct_ids[@]}" | jq -R 'ascii_downcase' | jq -s '.')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson rm "$rm_json" \
    '(.tickets[] | select(.id | tostring == $id) | .accountable) |=
      map(select(ascii_downcase as $v | $rm | any(. == $v) | not))'
  _edit_record '  [OK] accountable removed: %s' "$(IFS=', '; echo "${resolved_acct_ids[*]}")"
elif [[ "$acct_action" == "add" && "${#acct_ids[@]}" -gt 0 ]]; then
  add_json=$(printf '%s\n' "${acct_ids[@]}" | jq -R '.' | jq -s 'unique')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson add "$add_json" \
    '(.tickets[] | select(.id | tostring == $id) | .accountable) |= (. + $add | unique)'
  _edit_record '  [OK] accountable added: @%s' "$(IFS=', @'; echo "${acct_ids[*]}")"
fi

# Dependencies
if [[ "$dep_action" == "clear" ]]; then
  jq_inplace "$src_file" --arg id "$ticket_id" \
    '(.tickets[] | select(.id | tostring == $id) | .dependencies) = []'
  _edit_record '  [OK] dependencies cleared'
elif [[ "$dep_action" == "remove" && "${#resolved_dep_ids[@]}" -gt 0 ]]; then
  rm_json=$(printf '%s\n' "${resolved_dep_ids[@]}" | jq -R 'tonumber? // .' | jq -s '.')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson rm "$rm_json" \
    '(.tickets[] | select(.id | tostring == $id) | .dependencies) |=
      map(select(. as $v | $rm | any(. == $v) | not))'
  _edit_record '  [OK] dependencies removed: #%s' "$(IFS=', #'; echo "${resolved_dep_ids[*]}")"
elif [[ "$dep_action" == "add" && "${#resolved_dep_ids[@]}" -gt 0 ]]; then
  add_json=$(printf '%s\n' "${resolved_dep_ids[@]}" | jq -R 'tonumber? // .' | jq -s '. | unique')
  jq_inplace "$src_file" --arg id "$ticket_id" --argjson add "$add_json" \
    '(.tickets[] | select(.id | tostring == $id) | .dependencies) |= (. + $add | unique)'
  _edit_record '  [OK] dependencies added: #%s' "$(IFS=', #'; echo "${resolved_dep_ids[*]}")"
fi

# ── Stamp audit fields ────────────────────────────────────────────────────────
jq_inplace "$src_file" --arg id "$ticket_id" --arg by "$actor" \
  --arg ts "$(_timestamp)" \
  '(.tickets[] | select(.id | tostring == $id)) |= . + {updated_by: $by, updated_at: $ts}'
_state_transaction_commit

for msg in "${edit_messages[@]}"; do
  _outf '%s\n' "$msg"
done
_outf '\n'
