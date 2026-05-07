#!/usr/bin/env bash
# Ticket domain resolver and rendering support helpers for atoshell.

# ── Dependency context ───────────────────────────────────────────────────────
_ticket_dep_context() {
  # Computed dependency context is read-time metadata; it is never stored on
  # tickets and always treats only Done as satisfied.
  local id="$1"
  local src_file="$2"

  jq -rs --arg id "$id" --arg sd "$STATUS_DONE" '
    (.[0].tickets[] | select(.id | tostring == $id)) as $ticket |
    [.[1:][]?.tickets[]?] as $all |
    (reduce $all[] as $candidate ({}; .[$candidate.id | tostring] //= $candidate)) as $by_id |
    {
      blocked_by: [
        ($ticket.dependencies // [])[]? as $dep |
        ($dep | tostring) as $dep_id |
        ($by_id[$dep_id] // {id: ($dep_id | tonumber), title: "(deleted)", status: "Unknown"}) as $dep_ticket |
        select($dep_ticket.status != $sd) |
        {id: $dep_ticket.id, title: $dep_ticket.title, status: $dep_ticket.status}
      ],
      blocking: [
        $all[] |
        select(
          .status != $sd and
          ((.dependencies // []) | map(tostring) | any(. == $id))
        ) |
        {id: .id, title: .title, status: .status}
      ]
    }
  ' "$src_file" "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"
}

# ── Type, priority, and size resolvers ───────────────────────────────────────

# Validate input against the type list (case-insensitive) or index (0-2).
# Prints the canonical type name and returns 0, or exits 1 on no match.
_resolve_type() {
  local input="${1,,}"
  local json="${2:-false}"
  local -a known=("$TYPE_0" "$TYPE_1" "$TYPE_2")
  local type_label

  if [[ "$1" =~ ^[0-2]$ ]]; then
    printf '%s' "${known[$1]}"
    return 0
  fi

  for type_label in "${known[@]}"; do
    [[ "${type_label,,}" == "$input" ]] && { printf '%s' "$type_label"; return 0; }
  done

  if [[ "$json" == true ]]; then
    _json_error "INVALID_TYPE" "got" "$1"
  fi
  printf 'Error: unknown type "%s".\n' "$(_terminal_safe_line "$1")" >&2
  printf 'Valid types: %s/%s/%s (or 0-2)\n' \
    "$(_terminal_safe_line "$TYPE_0")" \
    "$(_terminal_safe_line "$TYPE_1")" \
    "$(_terminal_safe_line "$TYPE_2")" >&2
  exit 1
}

# Validate input against the priority list (case-insensitive) or index (0-3).
# Prints the canonical priority name and returns 0, or exits 1 on no match.
_resolve_priority() {
  local input="${1,,}"
  local json="${2:-false}"
  local -a known=("$PRIORITY_0" "$PRIORITY_1" "$PRIORITY_2" "$PRIORITY_3")
  local priority_label

  if [[ "$1" =~ ^[0-3]$ ]]; then
    printf '%s' "${known[$1]}"
    return 0
  fi

  for priority_label in "${known[@]}"; do
    [[ "${priority_label,,}" == "$input" ]] && { printf '%s' "$priority_label"; return 0; }
  done

  if [[ "$json" == true ]]; then
    _json_error "INVALID_PRIORITY" "got" "$1"
  fi
  printf 'Error: unknown priority "%s".\n' "$(_terminal_safe_line "$1")" >&2
  printf 'Valid priorities: %s/%s/%s/%s (or 0-3)\n' \
    "$(_terminal_safe_line "$PRIORITY_0")" \
    "$(_terminal_safe_line "$PRIORITY_1")" \
    "$(_terminal_safe_line "$PRIORITY_2")" \
    "$(_terminal_safe_line "$PRIORITY_3")" >&2
  exit 1
}

# Validate input against the size list (case-insensitive) or index (0-4).
# Prints the canonical size name and returns 0, or exits 1 on no match.
_resolve_size() {
  local input="${1,,}"
  local json="${2:-false}"
  local -a known=("$SIZE_0" "$SIZE_1" "$SIZE_2" "$SIZE_3" "$SIZE_4")
  local size_label

  if [[ "$1" =~ ^[0-4]$ ]]; then
    printf '%s' "${known[$1]}"
    return 0
  fi

  for size_label in "${known[@]}"; do
    [[ "${size_label,,}" == "$input" ]] && { printf '%s' "$size_label"; return 0; }
  done

  if [[ "$json" == true ]]; then
    _json_error "INVALID_SIZE" "got" "$1"
  fi
  printf 'Error: unknown size "%s".\n' "$(_terminal_safe_line "$1")" >&2
  printf 'Valid sizes: %s/%s/%s/%s/%s (or 0-4)\n' \
    "$(_terminal_safe_line "$SIZE_0")" \
    "$(_terminal_safe_line "$SIZE_1")" \
    "$(_terminal_safe_line "$SIZE_2")" \
    "$(_terminal_safe_line "$SIZE_3")" \
    "$(_terminal_safe_line "$SIZE_4")" >&2
  exit 1
}

# ── Filter resolvers ─────────────────────────────────────────────────────────
_resolve_enum_filter() {
  local raw="$1"
  local resolver="$2"
  local json="${3:-false}"
  local code="${4:-INVALID_FILTER}"
  local -a values=() resolved=()
  local value resolved_value

  IFS=',' read -ra values <<< "$raw"
  for value in "${values[@]}"; do
    value="${value// /}"
    if [[ -z "$value" ]]; then
      if [[ "$json" == true ]]; then
        _json_error "$code" "got" "$raw"
      fi
      printf 'Error: empty filter value.\n' >&2
      exit 1
    fi

    resolved_value="$("$resolver" "$value" "$json")" || exit 1
    resolved+=("$resolved_value")
  done

  (IFS=','; printf '%s' "${resolved[*]}")
}

_resolve_type_filter() {
  _resolve_enum_filter "$1" _resolve_type "${2:-false}" INVALID_TYPE
}

_resolve_priority_filter() {
  _resolve_enum_filter "$1" _resolve_priority "${2:-false}" INVALID_PRIORITY
}

_resolve_size_filter() {
  _resolve_enum_filter "$1" _resolve_size "${2:-false}" INVALID_SIZE
}

# ── Status and routing helpers ───────────────────────────────────────────────

# Resolve a user-supplied status string (case-insensitive) or column number (1-4)
# to the canonical value. Prints the canonical status and returns 0, or prints an
# error and exits 1.
_resolve_status() {
  local input="${1,,}"
  local json="${2:-false}"
  local -a known=("$STATUS_BACKLOG" "$STATUS_READY" "$STATUS_IN_PROGRESS" "$STATUS_DONE")
  local status_label index

  if [[ "$1" =~ ^[1-4]$ ]]; then
    index=$(( $1 - 1 ))
    printf '%s' "${known[$index]}"
    return 0
  fi

  for status_label in "${known[@]}"; do
    [[ "${status_label,,}" == "$input" ]] && { printf '%s' "$status_label"; return 0; }
  done

  if [[ "$json" == true ]]; then
    _json_error "INVALID_STATUS" "got" "$1"
  fi
  printf 'Error: unknown status "%s".\n' "$(_terminal_safe_line "$1")" >&2
  printf 'Valid statuses (or column number 1-4): %s\n' "$(_terminal_safe_line "${known[*]}")" >&2
  exit 1
}

# Route a status name to the file that owns it.
_status_to_file() {
  local status="$1"

  if [[ "$status" == "$STATUS_DONE" ]]; then
    printf '%s\n' "$DONE_FILE"
  elif [[ "$status" == "$STATUS_BACKLOG" ]]; then
    printf '%s\n' "$BACKLOG_FILE"
  else
    printf '%s\n' "$QUEUE_FILE"
  fi
}

# ── Input normalization ──────────────────────────────────────────────────────

# Keep stored ticket text raw; terminal safety is enforced at human render time.
_sanitize_line() {
  local s

  s="$1"
  s="${s//$'\r'/}"
  s="${s//$'\n'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"

  printf '%s' "$s"
}

_sanitize_text() {
  printf '%s' "$1"
}

# ── Discipline helpers ───────────────────────────────────────────────────────

# Print each discipline on its own line.
_list_disciplines() {
  local IFS=','
  local discipline_label

  for discipline_label in $DISCIPLINE_LABELS; do
    printf '%s\n' "${discipline_label## }"
  done
}

# Validate input against the disciplines list (case-insensitive).
# Prints the canonical discipline name and returns 0, or exits 1 on no match.
_resolve_discipline() {
  local input="${1,,}"
  local json="${2:-false}"
  local -a disciplines_list=()
  local discipline_label

  case "$input" in
    fe)  input="frontend"  ;;
    be)  input="backend"   ;;
  esac

  IFS=',' read -ra disciplines_list <<< "$DISCIPLINE_LABELS"
  for discipline_label in "${disciplines_list[@]}"; do
    discipline_label="${discipline_label## }"
    [[ "${discipline_label,,}" == "$input" ]] && { printf '%s' "$discipline_label"; return 0; }
  done

  if [[ "$json" == true ]]; then
    _json_error "INVALID_DISCIPLINE" "got" "$1"
  fi
  printf 'Error: unknown discipline "%s".\n' "$(_terminal_safe_line "$1")" >&2
  printf 'Valid disciplines:\n' >&2
  _list_disciplines | _terminal_safe_text | sed 's/^/  /' >&2
  exit 1
}

# Resolve comma-separated discipline input; sets caller-scope $disciplines.
_resolve_discs() {
  local json="${2:-false}"
  local -a disc_inputs=() resolved_discs=()
  local disc_input resolved_disc

  IFS=',' read -ra disc_inputs <<< "$1"
  for disc_input in "${disc_inputs[@]}"; do
    resolved_disc="$(_resolve_discipline "${disc_input// /}" "$json")" || exit 1
    resolved_discs+=("$resolved_disc")
  done

  disciplines="$(IFS=','; printf '%s' "${resolved_discs[*]}")"
}
