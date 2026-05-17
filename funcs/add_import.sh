#!/usr/bin/env bash
# Bulk import planning and validation helpers for add.sh.

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
