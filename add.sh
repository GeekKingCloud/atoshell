#!/usr/bin/env bash
# add.sh — Create a new ticket
#
# Usage:
#   atoshell add [title] [options]
#
# Aliases: tasu, fab, new, open
#
# Options:
#   --multi|--stream                                Keep adding tickets until empty title
#   --simple                                        Title-only mode (skip all other prompts)
#   --import <file>                                 Import tickets from a JSON array file ("-" reads stdin)
#   --description|--desc|--body|-b <text>           Description
#   --type|--kind|-t <type|0-2>                     Ticket type (default: Task; 0=Bug 1=Feature 2=Task)
#   --priority|-p <priority|0-3>                    Priority (default: P2; 0=P0 1=P1 2=P2 3=P3)
#   --size|-s <size|0-4>                            Size (default: M; 0=XS 1=S 2=M 3=L 4=XL)
#   --status|-S <status>                            Status (default: Ready)
#   --disciplines|--discipline|--dis|-d <name>      Comma-separated fixed discipline tags
#   --accountable|--assign|-a <users>               Comma-separated accountable users ("me" = current user, "agent" = [agent])
#   --dependencies|--dependency|--depends|-D <ids>  Comma-separated dependency IDs
#   --as <agent-N|number>                           Attribute created_by to a numbered agent in non-interactive mode
# Options (Output):
#   --json|-j                                       Output created ticket(s) as JSON (agent-friendly)
#   --help|-h                                       Show 'add' usage help and exit
#
# Valid disciplines (fixed): Frontend, Backend, Database, Cloud, DevOps,
#   Architecture, Automation, QA, Research, Core
# Discipline aliases: fe=Frontend, be=Backend
# Use the narrowest accurate discipline set; do not tag speculatively.

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
_setup

# ── Parse flags ───────────────────────────────────────────────────────────────
multi=false simple=false import_json=false import_json_src=""
title="" description="" type="$TYPE_2" priority="$PRIORITY_2" size="$SIZE_2" status="$STATUS_READY"
disciplines=() dependencies=() accountable=()
as=""
json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --multi|--stream)
      multi=true
      shift ;;
    --simple)
      simple=true
      shift ;;
    --import)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--import" '--import requires a file path or "-".'
      import_json=true
      import_json_src="$2"
      shift 2 ;;
    --as)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--as"
      as="$2"
      shift 2 ;;
    --description|--desc|--body|-b)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--description"
      description="$2"
      shift 2 ;;
    --type|--kind|-t)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--type"
      type="$(_resolve_type "$2" "$json")" || exit 1
      shift 2 ;;
    --priority|-p)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--priority"
      priority="$(_resolve_priority "$2" "$json")" || exit 1
      shift 2 ;;
    --size|-s)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--size"
      size="$(_resolve_size "$2" "$json")" || exit 1
      shift 2 ;;
    --status|-S)
      shift
      [[ $# -eq 0 ]] && _cli_missing_value "$json" "--status"
      _sraw=""
      while [[ $# -gt 0 && "$1" != --* ]]; do
        _sraw="${_sraw:+$_sraw }$1"; shift
      done
      status="$(_resolve_status "$_sraw" "$json")" || exit 1 ;;
    --disciplines|--discipline|--dis|-d)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--disciplines"
      IFS=',' read -ra _discs <<< "$2"
      for _disc in "${_discs[@]}"; do
        _resolved_disc="$(_resolve_discipline "${_disc// /}" "$json")" || exit 1
        disciplines+=("$_resolved_disc")
      done
      shift 2 ;;
    --accountable|--assign|-a)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--accountable"
      # Split into an array from commas; "me" = current user, "agent" = [agent]
      IFS=',' read -ra _a <<< "$2"
      for _u in "${_a[@]}"; do
        _u="${_u// /}"
        [[ "$_u" == "me" ]]    && _u="$USERNAME"
        [[ "$_u" == "agent" ]] && _u="[agent]"
        [[ " ${accountable[*]} " == *" $_u "* ]] || accountable+=("$_u")
      done
      shift 2 ;;
    --dependencies|--dependency|--depends|-D)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--dependencies"
      # Split into an array from commas
      IFS=',' read -ra _deps <<< "$2"
      for _dep in "${_deps[@]}"; do
        dependencies+=("${_dep// /}")
      done
      shift 2 ;;
    --json|-j)
      json=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        _cli_error "$json" "UNKNOWN_OPTION" "unknown option \"$1\"." "option" "$1"
      fi
      title="${title:+$title }$1"
      shift ;;
  esac
done

actor="$(_resolve_actor "$as" "$json")"

# ── Validate dependencies ─────────────────────────────────────────────────────
if [[ "${#dependencies[@]}" -gt 0 ]]; then
  for _dep in "${dependencies[@]}"; do
    if ! [[ "$_dep" =~ ^[0-9]+$ ]]; then
      _cli_error "$json" "INVALID_DEPENDENCY" "dependency \"$_dep\" is not a valid ticket ID." "dep" "$_dep"
    fi
    if ! jq -e -s --arg dep "$_dep" '
      [.[].tickets[]? | select(.id | tostring == $dep)] | length > 0
    ' "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE" >/dev/null 2>&1; then
      _cli_error "$json" "DEP_NOT_FOUND" "dependency #$_dep does not exist." "dep" "$_dep"
    fi
  done
fi

if $json; then
  $multi && _cli_error "$json" "INVALID_ARGUMENT" "--multi is interactive and cannot be used with --json." "option" "--multi"
  $simple && _cli_error "$json" "INVALID_ARGUMENT" "--simple is interactive and cannot be used with --json." "option" "--simple"
  if ! $import_json; then
    [[ -z "$title" ]] && _cli_error "$json" "MISSING_ARGUMENT" "title is required for --json." "argument" "title"
    [[ -z "$description" ]] && _cli_error "$json" "MISSING_ARGUMENT" "description is required for --json." "argument" "description"
  fi
fi

# ── Simple prompt (title only) ────────────────────────────────────────────────
_prompt_simple() {
  _require_tty
  if [[ -z "$title" ]]; then
    title=$(ask "Title")
    [[ -z "$title" ]] && return 1
  fi
  return 0
}

# ── Interactive prompt ────────────────────────────────────────────────────────
_prompt_ticket() {
  _require_tty
  printf '\n'

  if [[ -z "$title" ]]; then
    title=$(ask "Title")
    [[ -z "$title" ]] && return 1   # empty title = done (used by multi mode)
  fi

  local desc_input=""
  _tty_read_multiline desc_input 'Description (press Enter on a blank line to finish):'
  [[ -n "$desc_input" ]] && description="$desc_input"

  type=$(ask_pick "Type" 2 "$TYPE_0" "$TYPE_1" "$TYPE_2")
  priority=$(ask_pick "Priority" 2 "$PRIORITY_0" "$PRIORITY_1" "$PRIORITY_2" "$PRIORITY_3")
  size=$(ask_pick "Size" 2 "$SIZE_0" "$SIZE_1" "$SIZE_2" "$SIZE_3" "$SIZE_4")
  status=$(ask_pick "Status" 1 "$STATUS_BACKLOG" "$STATUS_READY" "$STATUS_IN_PROGRESS")

  # Disciplines: show numbered list, accept numbers or names, comma-separated
  local disciplines_list=()
  while IFS= read -r d; do disciplines_list+=("$d"); done < <(_list_disciplines)
  printf 'Disciplines:\n' >&2
  for i in "${!disciplines_list[@]}"; do
    printf '  %d. %s\n' "$i" "${disciplines_list[$i]}" >&2
  done
  while true; do
    local raw_disciplines; raw_disciplines=$(ask "Choose disciplines (numbers or names, comma-separated, or blank)" "")
    [[ -z "$raw_disciplines" ]] && break
    IFS=',' read -ra _picks <<< "$raw_disciplines"
    local _valid=true _resolved _candidate _pick
    local _candidates=()
    for _pick in "${_picks[@]}"; do
      _pick="${_pick// /}"
      # Numbers select by list position; anything else is resolved as a name
      if [[ "$_pick" =~ ^[0-9]+$ ]] && (( _pick >= 0 && _pick < ${#disciplines_list[@]} )); then
        _candidate="${disciplines_list[$_pick]}"
      else
        _candidate=$(_resolve_discipline "$_pick" 2>&1) || { printf 'Error: "%s" is not a valid discipline or number.\n' "$(_terminal_safe_line "$_pick")" >&2; _valid=false; break; }
      fi
      _candidates+=("$_candidate")
    done
    if $_valid; then
      for _resolved in "${_candidates[@]}"; do
        [[ " ${disciplines[*]} " == *" $_resolved "* ]] || disciplines+=("$_resolved")  # skip duplicates
      done
      break
    fi
  done

  # Dependencies: validate each ID exists before accepting
  while true; do
    local raw_dependencies; raw_dependencies=$(ask "Dependencies (ticket IDs, comma-separated, or blank)" "")
    [[ -z "$raw_dependencies" ]] && break
    IFS=',' read -ra _deps <<< "$raw_dependencies"
    local _dep _dep_valid=true
    for _dep in "${_deps[@]}"; do
      _dep="${_dep// /}"
      if ! [[ "$_dep" =~ ^[0-9]+$ ]]; then
        printf 'Error: "%s" is not a valid ticket ID.\n' "$(_terminal_safe_line "$_dep")" >&2; _dep_valid=false; break
      fi
      if ! _find_ticket_file "$_dep" > /dev/null 2>&1; then
        printf 'Error: ticket #%s does not exist.\n' "$(_terminal_safe_line "$_dep")" >&2; _dep_valid=false; break
      fi
    done
    if $_dep_valid; then
      dependencies=("${_deps[@]// /}")
      break
    fi
  done

  return 0
}

# ── JSON output accumulator ───────────────────────────────────────────────────
_json_created_tickets='[]'
_created_ticket_messages=()
dependencies_prevalidated=false

_record_created_ticket_message() {
  local new_id="$1" t="$2" st="$3" p="$4" sz="$5"
  local msg
  msg=$(printf '\n  [#%s] %s\n  Status: %s  Priority: %s  Size: %s' \
    "$new_id" "$t" "$st" "$p" "$sz")
  if [[ "${#disciplines[@]}" -gt 0 ]]; then
    msg+=$'\n'
    msg+=$(printf '  Disciplines: %s' "$(IFS=', '; echo "${disciplines[*]}")")
  fi
  if [[ "${#accountable[@]}" -gt 0 ]]; then
    msg+=$'\n'
    msg+=$(printf '  Accountable: %s' "$(IFS=, ; echo "${accountable[*]}")")
  fi
  if [[ "${#dependencies[@]}" -gt 0 ]]; then
    msg+=$'\n'
    msg+=$(printf '  Depends: %s' "$(IFS=, ; echo "${dependencies[*]}")")
  fi
  msg+=$'\n'
  _created_ticket_messages+=("$(_terminal_safe_text "$msg")")
}

_flush_created_ticket_messages() {
  local msg
  for msg in "${_created_ticket_messages[@]}"; do
    _outf '%s' "$msg"
  done
  _created_ticket_messages=()
}

# ── Single-ticket creation ────────────────────────────────────────────────────
_create_ticket() {
  local transaction_owner=false
  if ! _state_transaction_is_active; then
    _state_transaction_begin
    transaction_owner=true
  fi

  if ! $dependencies_prevalidated && [[ "${#dependencies[@]}" -gt 0 ]]; then
    local _dep_check
    for _dep_check in "${dependencies[@]}"; do
      _find_ticket_file "$_dep_check" > /dev/null
    done
  fi

  local t; t="$(_sanitize_line "$title")"
  local b; b="$(_sanitize_text "$description")"
  local p="$priority" sz="$size" st="$status" tp="$type"
  local creator; creator="$actor"
  local new_id; new_id=$(_next_id)
  local new_uuid; new_uuid=$(_get_uuid)
  local dest_file; dest_file=$(_status_to_file "$st")

  # Convert bash arrays to deduplicated JSON arrays
  local deps_json accountable_json disc_json
  if [[ "${#disciplines[@]}" -gt 0 ]]; then
    disc_json=$(printf '%s\n' "${disciplines[@]}" | jq -R '.' | jq -s 'unique')
  else
    disc_json='[]'
  fi

  if [[ "${#accountable[@]}" -gt 0 ]]; then
    accountable_json=$(printf '%s\n' "${accountable[@]}" | jq -R '.' | jq -s 'unique')
  else
    accountable_json='[]'
  fi

  if [[ "${#dependencies[@]}" -gt 0 ]]; then
    deps_json=$(printf '%s\n' "${dependencies[@]}" | jq -R 'tonumber? // .' | jq -s 'unique')
  else
    deps_json='[]'
  fi

  jq_inplace "$dest_file" \
    --argjson id   "$new_id" \
    --arg     uuid "$new_uuid" \
    --arg     t    "$t" \
    --arg     b    "$b" \
    --arg     tp   "$tp" \
    --arg     p    "$p" \
    --arg     sz   "$sz" \
    --arg     st   "$st" \
    --arg     by   "$creator" \
    --arg     ts   "$(_timestamp)" \
    --argjson disc "$disc_json" \
    --argjson asns "$accountable_json" \
    --argjson deps "$deps_json" \
    '.tickets += [{
       id: $id, uuid: $uuid, title: $t, description: $b,
       status: $st, priority: $p, size: $sz,
       type: $tp, disciplines: $disc,
       accountable: $asns, dependencies: $deps, comments: [],
       created_by: $by, created_at: $ts
     }]'

  if $json; then
    local ticket_json
    ticket_json=$(jq --arg id "$new_id" '.tickets[] | select(.id | tostring == $id)' "$(_state_transaction_current_file "$dest_file")")
    _json_created_tickets=$(printf '%s' "$_json_created_tickets" | jq --argjson t "$ticket_json" '. + [$t]')
  else
    _record_created_ticket_message "$new_id" "$t" "$st" "$p" "$sz"
  fi

  if $transaction_owner; then
    _state_transaction_commit
    _flush_created_ticket_messages
  fi
}

# Build the import plan for a batch.
# proposed_id is the newly assigned ticket ID in this system.
# ref_id is the ID other imported tickets may use to point at this item:
#   - explicit incoming .id when present
#   - otherwise the proposed_id (legacy batch behavior)
_build_import_plan() {
  local raw_items="$1" next_id="$2"

  jq -n \
    --argjson items "$raw_items" \
    --argjson start "$next_id" '
      [range(0; ($items | length)) as $i | {
        item: ("[item " + ($i | tostring) + "]"),
        source_id: (
          ($items[$i].id // null)
          | if . == null then null else tostring end
        ),
        proposed_id: ($start + $i | tostring),
        ref_id: (
          ($items[$i].id // null)
          | if . == null then ($start + $i | tostring) else tostring end
        )
      }]
    '
}

# Return the set of newly assigned batch ticket IDs that participate in a cycle.
# Only dependencies that point at other tickets in the same batch are relevant
# here, because external tickets cannot point forward into newly allocated IDs.
_batch_cycle_ids() {
  local raw_items="$1" import_plan_json="$2"

  jq -rn \
    --argjson items "$raw_items" \
    --argjson plan "$import_plan_json" '
      ($plan | map({key: .ref_id, value: .proposed_id}) | from_entries) as $ref_map |
      [range(0; ($items | length)) as $i | {
        id: $plan[$i].proposed_id,
        deps: (
          ($items[$i].dependencies // [])
          | map(tostring)
          | map(if $ref_map[.] != null then $ref_map[.] else empty end)
        )
      }] as $tickets |
      ($tickets | map({key: .id, value: .deps}) | from_entries) as $adj |
      ($tickets | map(.id) | map({key: ., value: 0}) | from_entries) as $zero |
      (reduce $tickets[] as $t (
        $zero;
        reduce $t.deps[] as $d (.; .[$d] += 1)
      )) as $deg |
      { q: [$deg | to_entries[] | select(.value == 0) | .key], seen: [], d: $deg } |
      until(.q | length == 0;
        (.q[0]) as $n |
        .seen += [$n] |
        .q = .q[1:] |
        reduce ($adj[$n] // [])[] as $dep (
          .;
          .d[$dep] -= 1 |
          if .d[$dep] == 0 then .q += [$dep] else . end
        )
      ) |
      ($tickets | map(.id)) - .seen
    '
}

_import_field_value() {
  local item="$1" field="$2"
  printf '%s' "$item" | _jq_text --arg field "$field" \
    'if has($field) and .[$field] != null then (.[$field] | tostring) else empty end'
}

_import_field_present() {
  local item="$1" field="$2"
  printf '%s' "$item" | jq -e --arg field "$field" \
    'has($field) and .[$field] != null' >/dev/null
}

_import_value_matches_known() {
  local value="$1" numeric_pattern="$2"
  shift 2
  [[ "$value" =~ $numeric_pattern ]] && return 0

  local input="${value,,}" known
  for known in "$@"; do
    [[ "${known,,}" == "$input" ]] && return 0
  done
  return 1
}

_import_field_is_valid() {
  local field="$1" value="$2"
  case "$field" in
    type)
      _import_value_matches_known "$value" '^[0-2]$' \
        "$TYPE_0" "$TYPE_1" "$TYPE_2"
      ;;
    priority)
      _import_value_matches_known "$value" '^[0-3]$' \
        "$PRIORITY_0" "$PRIORITY_1" "$PRIORITY_2" "$PRIORITY_3"
      ;;
    size)
      _import_value_matches_known "$value" '^[0-4]$' \
        "$SIZE_0" "$SIZE_1" "$SIZE_2" "$SIZE_3" "$SIZE_4"
      ;;
    status)
      _import_value_matches_known "$value" '^[1-4]$' \
        "$STATUS_BACKLOG" "$STATUS_READY" "$STATUS_IN_PROGRESS" "$STATUS_DONE"
      ;;
    *) return 1 ;;
  esac
}

_validate_import_field() {
  local item="$1" pfx="$2" field="$3" error_type="$4"
  local value
  _import_field_present "$item" "$field" || return 0
  value="$(_import_field_value "$item" "$field")"
  _import_field_is_valid "$field" "$value" && return 0

  if $json; then
    json_errors=$(printf '%s' "$json_errors" | jq \
      --arg pfx "$pfx" --arg field "$field" --arg value "$value" --arg error_type "$error_type" \
      '. + [{"type":$error_type,"item":$pfx,"field":$field,"value":$value}]')
  else
    printf 'Error: %s %s "%s" is invalid\n' "$pfx" "$field" "$(_terminal_safe_line "$value")" >&2
  fi
  errors=$(( errors + 1 ))
  return 0
}

# ── Bulk JSON import ──────────────────────────────────────────────────────────
# Two-pass: validate all items first (no writes), then create.
# Pass 1 catches structural and enum errors across the whole batch and reports
# them together so the caller can fix and retry cleanly.
_import_import_json() {
  local src="$1" raw count

  if [[ "$src" == "-" ]]; then
    raw=$(cat)
  else
    if [[ ! -f "$src" ]]; then
      if $json; then _json_error "FILE_NOT_FOUND" "file" "$src"
      else printf 'Error: file not found: %s\n' "$(_terminal_safe_line "$src")" >&2
      fi
      exit 1
    fi
    raw=$(cat "$src")
  fi

  if ! printf '%s' "$raw" | jq -e '.' > /dev/null 2>&1; then
    if $json; then _json_error "INVALID_JSON"
    else printf 'Error: --import input is not valid JSON.\n' >&2
    fi
    exit 1
  fi
  if ! printf '%s' "$raw" | jq -e 'if type == "array" then . else error end' > /dev/null 2>&1; then
    if $json; then _json_error "INVALID_FORMAT"
    else printf 'Error: --import input must be a JSON array of ticket objects.\n' >&2
    fi
    exit 1
  fi

  count=$(printf '%s' "$raw" | jq 'length')
  if [[ "$count" -eq 0 ]]; then
    if $json; then printf '[]\n'; else _outf '\n  No tickets to import.\n\n'; fi
    return
  fi

  _state_lock_acquire
  local next_id import_plan_json existing_ids_json ref_ids_json valid_ids_json
  local batch_ref_to_proposed_json duplicate_ref_ids_json
  next_id=$(jq '.next_id' "$META_FILE")
  import_plan_json=$(_build_import_plan "$raw" "$next_id")
  existing_ids_json=$(jq -s '[.[].tickets[].id | tostring] | unique' \
    "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE")
  ref_ids_json=$(jq '[.[].ref_id] | unique' <<< "$import_plan_json")
  valid_ids_json=$(jq -n --argjson existing "$existing_ids_json" --argjson refs "$ref_ids_json" \
    '($existing + $refs) | unique')
  batch_ref_to_proposed_json=$(jq 'map({key: .ref_id, value: .proposed_id}) | from_entries' <<< "$import_plan_json")
  duplicate_ref_ids_json=$(jq '
    sort_by(.ref_id)
    | group_by(.ref_id)
    | map(select(length > 1) | {id: .[0].ref_id, items: map(.item)})
  ' <<< "$import_plan_json")

  # ── Pass 1: validate ───────────────────────────────────────────────────────
  local errors=0 json_errors='[]' i item pfx _t _dep proposed_id resolved_dep
  local cycle_ids_json cycle_ids_fmt _import_id
  local has_duplicate_ref_ids=false dep_ref_ambiguous=false
  [[ "$(jq 'length' <<< "$duplicate_ref_ids_json")" -gt 0 ]] && has_duplicate_ref_ids=true
  declare -A batch_self_dep_ids=()
  for (( i=0; i<count; i++ )); do
    item=$(printf '%s' "$raw" | jq --argjson i "$i" '.[$i]')
    pfx=$(jq -r --argjson i "$i" '.[$i].item' <<< "$import_plan_json")
    proposed_id=$(jq -r --argjson i "$i" '.[$i].proposed_id' <<< "$import_plan_json")
    _import_id=$(printf '%s' "$item" | jq -r 'if has("id") and .id != null then (.id | tostring) else empty end')

    _t=$(printf '%s' "$item" | jq -r '.title // empty')
    if [[ -z "$_t" ]]; then
      if $json; then
        json_errors=$(printf '%s' "$json_errors" | jq --arg pfx "$pfx" '. + [{"type":"MISSING_TITLE","item":$pfx}]')
      else
        printf 'Error: %s missing required field: title\n' "$pfx" >&2
      fi
      errors=$(( errors + 1 ))
    fi

    _validate_import_field "$item" "$pfx" type "INVALID_TYPE"
    _validate_import_field "$item" "$pfx" priority "INVALID_PRIORITY"
    _validate_import_field "$item" "$pfx" size "INVALID_SIZE"
    _validate_import_field "$item" "$pfx" status "INVALID_STATUS"

    if [[ -n "$_import_id" ]] && ! [[ "$_import_id" =~ ^[0-9]+$ ]]; then
      if $json; then
        json_errors=$(printf '%s' "$json_errors" | jq --arg pfx "$pfx" --arg id "$_import_id" \
          '. + [{"type":"INVALID_IMPORT_ID","item":$pfx,"id":$id}]')
      else
        printf 'Error: %s import id "%s" is not numeric\n' "$pfx" "$(_terminal_safe_line "$_import_id")" >&2
      fi
      errors=$(( errors + 1 ))
    fi

    while IFS= read -r _dep; do
      [[ -z "$_dep" ]] && continue
      if ! [[ "$_dep" =~ ^[0-9]+$ ]]; then
        if $json; then
          json_errors=$(printf '%s' "$json_errors" | jq --arg pfx "$pfx" --arg dep "$_dep" '. + [{"type":"INVALID_DEP_ID","item":$pfx,"dep":$dep}]')
        else
          printf 'Error: %s non-numeric dependency: "%s"\n' "$pfx" "$(_terminal_safe_line "$_dep")" >&2
        fi
        errors=$(( errors + 1 ))
      else
        dep_ref_ambiguous=false
        if $has_duplicate_ref_ids && jq -e --arg dep "$_dep" 'any(.[]; .id == $dep)' <<< "$duplicate_ref_ids_json" > /dev/null 2>&1; then
          dep_ref_ambiguous=true
        fi
        if ! $dep_ref_ambiguous; then
          resolved_dep=$(_jq_text --arg dep "$_dep" '.[$dep] // $dep' <<< "$batch_ref_to_proposed_json")
          if [[ "$resolved_dep" == "$proposed_id" ]]; then
            batch_self_dep_ids["$proposed_id"]=1
            if $json; then
              json_errors=$(printf '%s' "$json_errors" | jq --arg pfx "$pfx" --arg id "$proposed_id" \
                '. + [{"type":"SELF_DEPENDENCY","item":$pfx,"id":$id}]')
            else
              printf 'Error: %s ticket #%s cannot depend on itself\n' "$pfx" "$proposed_id" >&2
            fi
            errors=$(( errors + 1 ))
            continue
          fi
        fi

        if ! jq -e --arg dep "$_dep" 'any(.[]; . == $dep)' <<< "$valid_ids_json" > /dev/null 2>&1; then
          if $json; then
            json_errors=$(printf '%s' "$json_errors" | jq --arg pfx "$pfx" --arg dep "$_dep" '. + [{"type":"DEP_NOT_FOUND","item":$pfx,"dep":$dep}]')
          else
            printf 'Error: %s dependency ticket #%s not found\n' "$pfx" "$(_terminal_safe_line "$_dep")" >&2
          fi
          errors=$(( errors + 1 ))
        fi
      fi
    done < <(printf '%s' "$item" | _jq_text '.dependencies[]? | tostring')
  done

  if $has_duplicate_ref_ids; then
    local dup_id dup_items
    while IFS= read -r dup_id; do
      dup_items=$(_jq_text --arg id "$dup_id" '.[] | select(.id == $id) | (.items | join(", "))' <<< "$duplicate_ref_ids_json")
      if $json; then
        json_errors=$(printf '%s' "$json_errors" | jq --arg id "$dup_id" --arg items "$dup_items" \
          '. + [{"type":"DUPLICATE_IMPORT_ID","id":$id,"items":$items}]')
      else
        printf 'Error: import id "%s" is ambiguous across %s\n' "$(_terminal_safe_line "$dup_id")" "$(_terminal_safe_line "$dup_items")" >&2
      fi
      errors=$(( errors + 1 ))
    done < <(_jq_text '.[].id' <<< "$duplicate_ref_ids_json")
  else
    cycle_ids_json=$(_batch_cycle_ids "$raw" "$import_plan_json")
    if [[ "$(jq 'length' <<< "$cycle_ids_json")" -gt 0 ]]; then
      local cycle_id filtered_cycle_ids_json='[]'
      while IFS= read -r cycle_id; do
        [[ -n "${batch_self_dep_ids[$cycle_id]:-}" ]] && continue
        filtered_cycle_ids_json=$(printf '%s' "$filtered_cycle_ids_json" | jq --arg id "$cycle_id" '. + [$id]')
      done < <(_jq_text '.[]' <<< "$cycle_ids_json")

      if [[ "$(jq 'length' <<< "$filtered_cycle_ids_json")" -gt 0 ]]; then
        cycle_ids_fmt=$(_jq_text 'map("#" + .) | join(", ")' <<< "$filtered_cycle_ids_json")
        if $json; then
          json_errors=$(printf '%s' "$json_errors" | jq --argjson ids "$filtered_cycle_ids_json" \
            '. + [{"type":"DEP_CYCLE","ids":$ids}]')
        else
          printf 'Error: batch contains a dependency cycle involving ticket(s) %s\n' "$(_terminal_safe_line "$cycle_ids_fmt")" >&2
        fi
        errors=$(( errors + 1 ))
      fi
    fi
  fi

  if [[ "$errors" -gt 0 ]]; then
    if $json; then
      jq -n --arg code "VALIDATION_FAILED" \
             --argjson count "$errors" \
             --argjson errs "$json_errors" \
        '{error: $code, count: $count, errors: $errs}' >&2
    else
      printf '\n%d validation error(s) — no tickets created.\n' "$errors" >&2
    fi
    exit 1
  fi

  # ── Pass 2: create ─────────────────────────────────────────────────────────
  if ! $json; then _outf '\n  Importing %s ticket(s)...\n' "$count"; fi
  _state_transaction_begin
  dependencies_prevalidated=true
  for (( i=0; i<count; i++ )); do
    item=$(printf '%s' "$raw" | jq --argjson i "$i" '.[$i]')

    title=$(printf '%s' "$item" | _jq_text '.title')
    description=$(printf '%s' "$item" | _jq_text '.description // .body // ""')
    type=$(_resolve_type     "$(printf '%s' "$item" | _jq_text --arg default "$TYPE_2"       '.type     // $default')")
    priority=$(_resolve_priority "$(printf '%s' "$item" | _jq_text --arg default "$PRIORITY_2" '.priority // $default')")
    size=$(_resolve_size     "$(printf '%s' "$item" | _jq_text --arg default "$SIZE_2"       '.size     // $default')")
    status=$(_resolve_status "$(printf '%s' "$item" | _jq_text --arg default "$STATUS_READY"  '.status   // $default')")

    disciplines=()
    while IFS= read -r _d; do
      [[ -z "$_d" ]] && continue
      disciplines+=("$(_resolve_discipline "${_d// /}")")
    done < <(printf '%s' "$item" | _jq_text '.disciplines[]? // empty')

    accountable=()
    while IFS= read -r _u; do
      [[ -z "$_u" ]] && continue
      [[ "$_u" == "me" ]]    && _u="$USERNAME"
      [[ "$_u" == "agent" ]] && _u="[agent]"
      [[ " ${accountable[*]:-} " == *" $_u "* ]] || accountable+=("$_u")
    done < <(printf '%s' "$item" | _jq_text '.accountable[]? // empty')

    # Dependencies already validated in Pass 1 — safe to add directly
    dependencies=()
    while IFS= read -r _dep; do
      [[ -z "$_dep" ]] && continue
      dependencies+=("$(_jq_text --arg dep "$_dep" '.[$dep] // $dep' <<< "$batch_ref_to_proposed_json")")
    done < <(printf '%s' "$item" | _jq_text '.dependencies[]? | tostring')

    _create_ticket
  done
  dependencies_prevalidated=false
  _state_transaction_commit
  _state_lock_release
  if $json; then
    printf '%s\n' "$_json_created_tickets"
  else
    _flush_created_ticket_messages
    _outf '  Done.\n\n'
  fi
}

# ── Run ───────────────────────────────────────────────────────────────────────
# _first guards against clearing a title that was passed on the command line
# (e.g. add --multi "My first ticket") — we only reset state from iteration 2 onward.
if $multi && $simple; then
  printf '\n  Quick mode — enter titles one by one. Leave blank to finish.\n\n'
  _first=true
  while true; do
    if $_first; then _first=false; else title=""; fi
    _prompt_simple || break
    _create_ticket
  done
  printf '  Done.\n\n'

elif $multi; then
  printf '\n  Multi mode — enter tickets one by one. Leave title blank to finish.\n'
  _first=true
  while true; do
    if $_first; then
      _first=false
    else
      title="" description="" dependencies=() accountable=() disciplines=()
    fi
    _prompt_ticket || break
    _create_ticket
    type="$TYPE_2"; priority="$PRIORITY_2"; size="$SIZE_2"; status="$STATUS_READY"   # reset field defaults
  done
  printf '  Done.\n\n'

elif $simple; then
  _prompt_simple && _create_ticket || printf '\n  No ticket created.\n\n'

elif $import_json; then
  _import_import_json "$import_json_src"

elif [[ -n "$title" && -n "$description" ]]; then
  _create_ticket

else
  _prompt_ticket && _create_ticket || printf '\n  No ticket created.\n\n'
fi

# ── JSON output (single-ticket paths) ────────────────────────────────────────
# --import handles its own output inside _import_import_json
if $json && ! $import_json; then
  printf '%s\n' "$_json_created_tickets" | jq '.[0] // empty'
fi
