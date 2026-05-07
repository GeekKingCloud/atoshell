#!/usr/bin/env bash
# State lock helpers for atoshell.

# ── Lock path and metadata ───────────────────────────────────────────────────
_state_lock_dir() {
  printf '%s/.lock' "$ATO_DIR"
}

_state_now_epoch() {
  date +%s
}

_state_lock_meta_value() {
  local key="$1"
  local meta="$2"

  sed -n "s/^${key}=//p" "$meta" 2>/dev/null | head -n 1
}

_state_lock_mtime_epoch() {
  local path="$1"

  stat -c %Y "$path" 2>/dev/null ||
    stat -f %m "$path" 2>/dev/null ||
    _state_now_epoch
}

_state_lock_print_error() {
  local lock_dir meta

  lock_dir="$(_state_lock_dir)"
  meta="$lock_dir/meta"

  printf 'Error: atoshell state is locked at %s.\n' "$lock_dir" >&2
  if [[ -f "$meta" ]]; then
    printf 'Lock metadata:\n' >&2
    sed 's/^/  /' "$meta" >&2
  else
    printf 'Lock metadata: unavailable\n' >&2
  fi
  printf 'Remove the lock only if no atoshell process is running.\n' >&2
}

# ── Lock owner detection ─────────────────────────────────────────────────────
_state_lock_owner_alive() {
  local pid="${1:-}"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

_state_lock_owner_args() {
  local pid="${1:-}"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1

  if [[ -r "/proc/$pid/cmdline" ]]; then
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null && return 0
  fi

  ps -p "$pid" -o args= 2>/dev/null || true
}

_state_lock_owner_matches() {
  local pid="$1"
  local command_name="$2"
  local args

  _state_lock_owner_alive "$pid" || return 1
  [[ -n "$command_name" ]] || return 0

  args="$(_state_lock_owner_args "$pid")"
  [[ -n "$args" ]] || return 0
  [[ "$args" == *"$command_name"* ]]
}

# ── Stale lock recovery ──────────────────────────────────────────────────────
_state_lock_reap_stale() {
  local lock_dir meta
  local created now pid

  lock_dir="$(_state_lock_dir)"
  meta="$lock_dir/meta"
  [[ -d "$lock_dir" ]] || return 0

  now="$(_state_now_epoch)"

  if [[ ! -f "$meta" ]]; then
    if (( now - $(_state_lock_mtime_epoch "$lock_dir") >= 300 )); then
      rm -rf "$lock_dir"
    fi
    return 0
  fi

  created="$(_state_lock_meta_value created_at_epoch "$meta")"
  if [[ ! "$created" =~ ^[0-9]+$ ]]; then
    if (( now - $(_state_lock_mtime_epoch "$meta") >= 300 )); then
      rm -rf "$lock_dir"
    fi
    return 0
  fi

  (( now - created >= 300 )) || return 0

  pid="$(_state_lock_meta_value pid "$meta")"
  if _state_lock_owner_matches "$pid" "$(_state_lock_meta_value command "$meta")"; then
    return 0
  fi

  rm -rf "$lock_dir"
}

# ── Lock lifecycle ───────────────────────────────────────────────────────────
_state_lock_acquire() {
  local lock_dir start now

  [[ "${_STATE_LOCK_HELD:-false}" == true ]] && return 0

  mkdir -p "$ATO_DIR"
  lock_dir="$(_state_lock_dir)"
  start="$(_state_now_epoch)"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    _state_lock_reap_stale
    now="$(_state_now_epoch)"

    if (( now - start >= 30 )); then
      _state_lock_print_error
      return 1
    fi

    sleep 1
  done

  _STATE_LOCK_HELD=true
  {
    printf 'pid=%s\n' "$$"
    printf 'created_at_epoch=%s\n' "$(_state_now_epoch)"
    printf 'command=%s\n' "${0##*/}"
    printf 'cwd=%s\n' "$PWD"
  } > "$lock_dir/meta"

  trap _state_lock_release EXIT
  _state_transaction_recover
}

_state_lock_release() {
  if [[ "${_STATE_LOCK_HELD:-false}" == true ]]; then
    rm -rf "$(_state_lock_dir)"
    _STATE_LOCK_HELD=false
  fi

  trap - EXIT
}

_with_state_lock() {
  local owns_lock=false status=0

  if [[ "${_STATE_LOCK_HELD:-false}" != true ]]; then
    _state_lock_acquire || return 1
    owns_lock=true
  fi

  "$@" || status=$?

  if $owns_lock; then
    _state_lock_release
  fi

  return "$status"
}
