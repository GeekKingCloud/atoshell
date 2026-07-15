#!/usr/bin/env bash
# Config and timestamp helpers for atoshell.

# ── Load project config ──────────────────────────────────────────────────────
_load_config() {
  local project_root="$1"
  local _helpers_dir

  ATO_DIR="$project_root/.atoshell"
  BACKLOG_FILE="$ATO_DIR/backlog.json"
  QUEUE_FILE="$ATO_DIR/queue.json"
  DONE_FILE="$ATO_DIR/done.json"
  META_FILE="$ATO_DIR/meta.json"
  CONFIG_FILE="$ATO_DIR/config.env"

  # Source canonical project-config defaults first, then let config.env override them.
  _helpers_dir="$(_source_dir "${BASH_SOURCE[0]-}")"
  # shellcheck source=funcs/config_vars.sh
  source "$_helpers_dir/config_vars.sh"

  USERNAME=""
  [[ -f "$CONFIG_FILE" ]] && _load_config_file "$CONFIG_FILE"
  unset DISCIPLINES

  # Resolve author from project config only. Missing USERNAME stays visible.
  if [[ -z "${USERNAME:-}" ]]; then
    USERNAME="undefined"
  fi

  if [[ "${USERNAME,,}" == "me" ]]; then
    printf '[WARN] USERNAME=me conflicts with the "me" accountable shorthand. Set a real name in .atoshell/config.env.\n' >&2
  fi

  local -a label_json=()
  mapfile -t label_json < <(
    jq -n -c \
      --arg p0 "$PRIORITY_0" --arg p1 "$PRIORITY_1" \
      --arg p2 "$PRIORITY_2" --arg p3 "$PRIORITY_3" \
      --arg s0 "$SIZE_0" --arg s1 "$SIZE_1" --arg s2 "$SIZE_2" \
      --arg s3 "$SIZE_3" --arg s4 "$SIZE_4" \
      '[$p0, $p1, $p2, $p3], [$s0, $s1, $s2, $s3, $s4]'
  )
  PRIORITY_LABELS_JSON="${label_json[0]}"
  SIZE_LABELS_JSON="${label_json[1]}"
}

_load_config_file() {
  local file="$1"
  local line trimmed key rhs value
  local known_keys="" default_line default_key

  [[ -f "$file" ]] || return 0

  while IFS= read -r default_line || [[ -n "$default_line" ]]; do
    [[ "$default_line" =~ ^([A-Z0-9_]+)= ]] || continue
    default_key="${BASH_REMATCH[1]}"
    known_keys+=" $default_key "
  done < <(_config_defaults)

  while IFS= read -r line || [[ -n "$line" ]]; do
    _config_trim_into trimmed "$line"
    [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]] && continue
    [[ "$trimmed" =~ ^([A-Z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue

    key="${BASH_REMATCH[1]}"
    rhs="${BASH_REMATCH[2]}"

    [[ "$known_keys" == *" $key "* ]] || continue
    _config_parse_value_into value "$rhs" || continue

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"
}

# ── Config defaults and template ─────────────────────────────────────────────

# Canonical list of every known project config var with its default value.
# funcs/config_vars.sh is the single source of truth for config-backed values.
# USERNAME is left blank in generated config; runtime falls back to "undefined".
_config_defaults() {
  local _helpers_dir

  _helpers_dir="$(_source_dir "${BASH_SOURCE[0]-}")"
  printf 'USERNAME=""\n'
  cat "$_helpers_dir/config_vars.sh"
}

_config_known_keys_from_defaults() {
  local line key known_keys=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^([A-Z0-9_]+)= ]] || continue
    key="${BASH_REMATCH[1]}"
    known_keys+=" $key "
  done < <(_config_defaults)

  printf '%s\n' "$known_keys"
}

_config_template() {
  local _helpers_dir

  _helpers_dir="$(_source_dir "${BASH_SOURCE[0]-}")"
  # shellcheck source=funcs/config_vars.sh
  source "$_helpers_dir/config_vars.sh"

  printf '%s\n' '# .atoshell/config.env — project configuration for atoshell'
  printf '%s\n' '#'
  printf '%s\n' '# Shared ticket files (`queue.json`, `backlog.json`, `done.json`) are intended'
  printf '%s\n' '# to be committed. Local-only files such as `config.env` and `meta.json` should'
  printf '%s\n' '# be gitignored.'
  printf '\n'
  printf '%s\n' '# ── Column names ──────────────────────────────────────────────────────────────'
  printf '%s\n' '# Rename these to match your workflow. They control how tickets are displayed'
  printf '%s\n' '# and which JSON file each status lives in.'
  printf 'STATUS_BACKLOG="%s"          # Untriaged / parked / failed — lives in backlog.json\n' "$STATUS_BACKLOG"
  printf 'STATUS_READY="%s"              # Ready to work — lives in queue.json\n' "$STATUS_READY"
  printf 'STATUS_IN_PROGRESS="%s"  # Being worked — lives in queue.json\n' "$STATUS_IN_PROGRESS"
  printf 'STATUS_DONE="%s"                # Completed work — lives in done.json\n' "$STATUS_DONE"
  printf '\n'
  printf '%s\n' '# ── Username ──────────────────────────────────────────────────────────────────'
  printf '%s\n' '# Your name, used as the author on tickets and comments and as the value of "me"'
  printf '%s\n' '# when filtering or assigning. Defaults to "undefined" unless set here.'
  printf '%s\n' '#USERNAME="Your Name"'
  printf '\n'
  printf '%s\n' '# ── Priority labels (highest → lowest) ────────────────────────────────────────'
  printf 'PRIORITY_0="%s"\n' "$PRIORITY_0"
  printf 'PRIORITY_1="%s"\n' "$PRIORITY_1"
  printf 'PRIORITY_2="%s"\n' "$PRIORITY_2"
  printf 'PRIORITY_3="%s"\n' "$PRIORITY_3"
  printf '\n'
  printf '%s\n' '# ── Size labels (smallest → largest) ──────────────────────────────────────────'
  printf 'SIZE_0="%s"\n' "$SIZE_0"
  printf 'SIZE_1="%s"\n' "$SIZE_1"
  printf 'SIZE_2="%s"\n' "$SIZE_2"
  printf 'SIZE_3="%s"\n' "$SIZE_3"
  printf 'SIZE_4="%s"\n' "$SIZE_4"
  printf '\n'
  printf '%s\n' '# ── Ticket types ───────────────────────────────────────────────────────────────'
  printf 'TYPE_0="%s"\n' "$TYPE_0"
  printf 'TYPE_1="%s"\n' "$TYPE_1"
  printf 'TYPE_2="%s"\n' "$TYPE_2"
  printf '\n'
  printf '%s\n' '# ── Timestamps ────────────────────────────────────────────────────────────────'
  printf '%s\n' '# Controls created_at, updated_at, and ticket comment timestamps.'
  printf '%s\n' '# Use an IANA name such as "America/Mexico_City"'
  printf 'ATOSHELL_TIMEZONE="%s"\n' "$ATOSHELL_TIMEZONE"
  printf '\n'
  printf '%s\n' '# ── Blocker handling (dependency budget) ───────────────────────────────────────'
  printf '%s\n' '# How much size-budget to spend clearing blockers for valuable blocked tickets.'
  printf '%s\n' '# `take next` skips blocked work whose cleanup cost exceeds the relevant budget.'
  printf '%s\n' '# Size cost = size rank: XS=0, S=1, M=2, L=3, XL=4. P0 blockers always cost 0.'
  printf '%s\n' '# Leave UNBLOCK_P0_BUDGET empty for infinite (always worth clearing all blockers).'
  printf 'UNBLOCK_P0_BUDGET="%s"   # infinite\n' "$UNBLOCK_P0_BUDGET"
  printf 'UNBLOCK_P1_BUDGET="%s"  # e.g. 1×L, 3×S, or 1×S + 1×M\n' "$UNBLOCK_P1_BUDGET"
}

# ── Config value parser ──────────────────────────────────────────────────────
_config_trim_into() {
  local __var_name="$1"
  local value="$2"

  while [[ "$value" == [[:space:]]* ]]; do
    value="${value#?}"
  done
  while [[ "$value" == *[[:space:]] ]]; do
    value="${value%?}"
  done

  printf -v "$__var_name" '%s' "$value"
}

_config_parse_quoted_value() {
  local __var_name="$1"
  local rhs="$2"
  local quote="$3"
  local parsed="" rest="" ch
  local escaped=0 i

  for (( i = 1; i < ${#rhs}; i++ )); do
    ch="${rhs:i:1}"

    if [[ "$quote" == "'" ]]; then
      if [[ "$ch" == "'" ]]; then
        _config_trim_into rest "${rhs:i+1}"
        [[ -z "$rest" || "${rest:0:1}" == "#" ]] || return 1
        printf -v "$__var_name" '%s' "$parsed"
        return 0
      fi
      parsed+="$ch"
      continue
    fi

    if [[ "$escaped" -eq 1 ]]; then
      case "$ch" in
        '"'|"\\"|"\$"|'`')
          parsed+="$ch"
          ;;
        *)
          parsed+="\\$ch"
          ;;
      esac
      escaped=0
      continue
    fi

    case "$ch" in
      "\\")
        escaped=1
        ;;
      '"')
        _config_trim_into rest "${rhs:i+1}"
        [[ -z "$rest" || "${rest:0:1}" == "#" ]] || return 1
        printf -v "$__var_name" '%s' "$parsed"
        return 0
        ;;
      *)
        parsed+="$ch"
        ;;
    esac
  done

  return 1
}

_config_parse_value_into() {
  local __var_name="$1"
  local rhs

  _config_trim_into rhs "$2"

  case "${rhs:0:1}" in
    '"')
      _config_parse_quoted_value "$__var_name" "$rhs" '"'
      return
      ;;
    "'")
      _config_parse_quoted_value "$__var_name" "$rhs" "'"
      return
      ;;
  esac

  rhs="${rhs%%#*}"
  _config_trim_into rhs "$rhs"

  [[ "$rhs" =~ [[:space:]\;\&\|\<\>\`\$\(\)\{\}] ]] && return 1
  printf -v "$__var_name" '%s' "$rhs"
}

_escape_env_value() {
  printf '%s' "$1" | sed 's/[\\"]/\\&/g'
}

_format_config_assignment() {
  local key="$1"
  local value="$2"

  printf '%s="%s"' "$key" "$(_escape_env_value "$value")"
}

_set_config_value_in_file() {
  local file="$1"
  local key="$2"
  local value="$3"
  local replacement tmp

  replacement="$(_format_config_assignment "$key" "$value")"
  tmp="${file}.tmp.$$"
  awk -v key="$key" -v replacement="$replacement" '
    BEGIN { replaced = 0 }
    $0 ~ ("^[#[:space:]]*" key "[[:space:]]*=") {
      print replacement
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print replacement
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# ── Timestamp formatting ─────────────────────────────────────────────────────
_timestamp_format_date_tz() {
  local timezone="$1"
  local stamp

  stamp="$(TZ="$timezone" date +"%Y-%m-%dT%H:%M:%S%z")" || return
  printf '%s:%s\n' "${stamp:0:${#stamp}-2}" "${stamp: -2}"
}

_timestamp_date_has_zoneinfo() {
  local timezone="$1"

  [[ -f "/usr/share/zoneinfo/$timezone" || -f "/usr/share/lib/zoneinfo/$timezone" ]]
}

_timestamp_format_iana() {
  local timezone="$1"
  local python_bin

  if _timestamp_date_has_zoneinfo "$timezone"; then
    _timestamp_format_date_tz "$timezone" && return
  fi

  for python_bin in python3 python; do
    if command -v "$python_bin" >/dev/null 2>&1; then
      "$python_bin" -c 'import sys
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
print(datetime.now(timezone.utc).astimezone(ZoneInfo(sys.argv[1])).isoformat(timespec="seconds"))' "$timezone" 2>/dev/null && return
    fi
  done

  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command '$tz=[System.TimeZoneInfo]::FindSystemTimeZoneById($args[0]); $dt=[System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow,$tz); $dt.ToString("yyyy-MM-ddTHH:mm:sszzz")' "$timezone" 2>/dev/null && return
  fi

  printf 'atoshell: ATOSHELL_TIMEZONE="%s" requires IANA timezone support from system date, python, or pwsh\n' "$timezone" >&2
  return 1
}

_timestamp() {
  local timezone="${ATOSHELL_TIMEZONE:-UTC}"

  case "$(printf '%s' "$timezone" | tr '[:upper:]' '[:lower:]')" in
    utc|z|etc/utc)
      date -u +"%Y-%m-%dT%H:%M:%SZ"
      return
      ;;
  esac

  if [[ "$timezone" == */* ]]; then
    _timestamp_format_iana "$timezone"
    return
  fi

  _timestamp_format_date_tz "$timezone"
}

# ── Config file sync ─────────────────────────────────────────────────────────
# Idempotent config file setup — mirrors _ensure_files for config.env.
# Creates the file from a packaged template or generated fallback if missing/empty,
# then rewrites existing files through the canonical template while preserving
# supported project values.
_ensure_config() {
  local file="$1"
  local tmpl used_template=false

  if [[ ! -s "$file" ]]; then
    tmpl="$ATOSHELL_DIR/.atoshell.example/config.env"
    if [[ -f "$tmpl" ]]; then
      cp "$tmpl" "$file"
      used_template=true
    fi

    if ! $used_template; then
      _config_template > "$file"
      _outf '  [CREATED]  .atoshell/config.env\n'
      return
    fi

    # Template used — patch in any vars _config_defaults knows about that the template lacks.
    _sync_config_vars "$file"
    _outf '  [CREATED]  .atoshell/config.env\n'
    return
  fi

  _sync_config_vars "$file"
}

# Inner: rewrite through the canonical config template and reapply supported
# project values. Unsupported stale keys are intentionally dropped.
_sync_config_vars() {
  local file="$1"
  local tmp line trimmed key rhs value known_keys

  tmp="${file}.tmp.$$"
  known_keys="$(_config_known_keys_from_defaults)"
  _config_template > "$tmp"

  while IFS= read -r line || [[ -n "$line" ]]; do
    _config_trim_into trimmed "$line"
    [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]] && continue
    [[ "$trimmed" =~ ^([A-Z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    rhs="${BASH_REMATCH[2]}"

    [[ "$known_keys" == *" $key "* ]] || continue
    [[ "$key" != "DISCIPLINES" ]] || continue
    _config_parse_value_into value "$rhs" || continue
    if [[ "$key" == "USERNAME" && -z "$value" ]]; then
      continue
    fi
    _set_config_value_in_file "$tmp" "$key" "$value"
  done < "$file"

  mv "$tmp" "$file"
  _outf '  [OK]       .atoshell/config.env\n'

  return 0
}
