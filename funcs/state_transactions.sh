#!/usr/bin/env bash
# State transaction and atomic JSON update helpers for atoshell.

# ── Temporary files ──────────────────────────────────────────────────────────
_mktemp_sibling() {
  local target="$1"
  local dir base

  dir="$(_dirname "$target")"
  base="$(_basename "$target")"

  mktemp "$dir/.${base}.tmp.XXXXXX"
}

_state_tmp_cleanup() {
  local tmp="${1:-}"

  [[ -n "$tmp" ]] && rm -f "$tmp"
}

# ── Transaction paths ────────────────────────────────────────────────────────
_state_transaction_dir() {
  printf '%s/.transaction' "$ATO_DIR"
}

_state_transaction_manifest() {
  printf '%s/manifest.tsv' "$(_state_transaction_dir)"
}

_state_transaction_is_active() {
  [[ "${_STATE_TRANSACTION_ACTIVE:-false}" == true ]]
}

_state_transaction_path_allowed() {
  local path="$1"

  case "$path" in
    "$BACKLOG_FILE"|"$QUEUE_FILE"|"$DONE_FILE"|"$META_FILE")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_state_transaction_current_file() {
  local file="$1"
  local manifest key path after

  manifest="$(_state_transaction_manifest)"

  if _state_transaction_is_active && [[ -f "$manifest" ]]; then
    while IFS=$'\t' read -r key path; do
      if [[ "$path" == "$file" ]]; then
        after="$(_state_transaction_dir)/after/$key"
        [[ -f "$after" ]] && { printf '%s' "$after"; return 0; }
      fi
    done < "$manifest"
  fi

  printf '%s' "$file"
}

# ── Transaction staging and recovery ─────────────────────────────────────────
_state_transaction_key_for_file() {
  local file="$1"
  local manifest key path count

  _state_transaction_path_allowed "$file" || {
    printf 'Error: refusing transaction for path outside atoshell state: %s\n' "$file" >&2
    return 1
  }

  manifest="$(_state_transaction_manifest)"

  if [[ -f "$manifest" ]]; then
    while IFS=$'\t' read -r key path; do
      [[ "$path" == "$file" ]] && { printf '%s' "$key"; return 0; }
    done < "$manifest"
  fi

  count=0
  if [[ -f "$manifest" ]]; then
    while IFS= read -r _; do
      ((count += 1))
    done < "$manifest"
  fi
  key=$(( count + 1 ))

  printf '%s\t%s\n' "$key" "$file" >> "$manifest"
  cp "$file" "$(_state_transaction_dir)/before/$key"
  printf '%s' "$key"
}

_state_transaction_stage_jq() {
  local file="$1"
  local key input tmp after

  shift

  key="$(_state_transaction_key_for_file "$file")" || return 1
  input="$(_state_transaction_current_file "$file")"
  after="$(_state_transaction_dir)/after/$key"
  tmp="$(_mktemp_sibling "$after")"

  if jq "$@" "$input" > "$tmp" && jq -e . "$tmp" >/dev/null; then
    mv -f "$tmp" "$after"
  else
    rm -f "$tmp"
    return 1
  fi
}

_state_transaction_recover() {
  local transaction_dir manifest
  local key path before tmp

  transaction_dir="$(_state_transaction_dir)"
  manifest="$transaction_dir/manifest.tsv"
  [[ -d "$transaction_dir" ]] || return 0

  if [[ -f "$manifest" ]]; then
    while IFS=$'\t' read -r key path; do
      _state_transaction_path_allowed "$path" || continue
      before="$transaction_dir/before/$key"

      if [[ -f "$before" && ! -L "$before" && ! -L "$path" ]]; then
        tmp="$(_mktemp_sibling "$path")"
        trap '_state_tmp_cleanup "$tmp"' RETURN
        cp "$before" "$tmp"
        mv -f "$tmp" "$path"
        trap - RETURN
      fi
    done < "$manifest"
  fi

  rm -rf "$transaction_dir"
  _STATE_TRANSACTION_ACTIVE=false
  _STATE_TRANSACTION_OWNS_LOCK=false
}

_state_transaction_begin() {
  local transaction_dir

  if [[ "${_STATE_LOCK_HELD:-false}" == true ]]; then
    _STATE_TRANSACTION_OWNS_LOCK=false
  else
    _state_lock_acquire || return 1
    _STATE_TRANSACTION_OWNS_LOCK=true
  fi

  _state_transaction_is_active && return 0

  transaction_dir="$(_state_transaction_dir)"
  rm -rf "$transaction_dir"
  mkdir -p "$transaction_dir/before" "$transaction_dir/after"
  : > "$transaction_dir/manifest.tsv"
  printf 'staging\n' > "$transaction_dir/state"

  _STATE_TRANSACTION_ACTIVE=true
}

_state_transaction_commit() {
  local transaction_dir manifest
  local key path after tmp owns_lock

  _state_transaction_is_active || return 0

  transaction_dir="$(_state_transaction_dir)"
  manifest="$transaction_dir/manifest.tsv"
  printf 'committing\n' > "$transaction_dir/state"

  while IFS=$'\t' read -r key path; do
    after="$transaction_dir/after/$key"
    if [[ -f "$after" ]]; then
      tmp="$(_mktemp_sibling "$path")"
      trap '_state_tmp_cleanup "$tmp"' RETURN
      cp "$after" "$tmp"
      mv -f "$tmp" "$path"
      trap - RETURN
    fi
  done < "$manifest"

  rm -rf "$transaction_dir"
  owns_lock="${_STATE_TRANSACTION_OWNS_LOCK:-false}"
  _STATE_TRANSACTION_ACTIVE=false
  _STATE_TRANSACTION_OWNS_LOCK=false

  if [[ "$owns_lock" == true ]]; then
    _state_lock_release
  fi
}

# ── Atomic JSON updates ──────────────────────────────────────────────────────

# Atomically update a JSON file in-place using jq.
# Usage: jq_inplace <file> [jq args...]
jq_inplace() {
  local file="$1"
  local tmp owns_lock=false status=0

  shift

  if _state_transaction_is_active; then
    _state_transaction_stage_jq "$file" "$@"
    return
  fi

  if [[ "${_STATE_LOCK_HELD:-false}" != true ]]; then
    _state_lock_acquire || return 1
    owns_lock=true
  fi

  tmp="$(_mktemp_sibling "$file")"
  trap '_state_tmp_cleanup "$tmp"' RETURN

  if jq "$@" "$file" > "$tmp" && jq -e . "$tmp" >/dev/null; then
    mv -f "$tmp" "$file"
    trap - RETURN
  else
    rm -f "$tmp"
    trap - RETURN
    status=1
  fi

  if $owns_lock; then
    _state_lock_release
  fi

  return "$status"
}
