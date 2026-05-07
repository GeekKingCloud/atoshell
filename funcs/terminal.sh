#!/usr/bin/env bash
# Terminal, output, prompt, and actor helpers for atoshell.

# ── Quiet mode ────────────────────────────────────────────────────────────────

# Set ATOSHELL_QUIET=1 (via --quiet/-q on any command) to suppress all decorative output.
# Errors always print regardless.
# Defaults to quiet when stdout is not a TTY (pipes, scripts, CI).
# Bats captures stdout in a non-TTY context, so treat test runs as TTY-like.
_stdout_is_tty() {
  [[ -n "${BATS_TEST_TMPDIR:-}" ]] && return 0
  [[ -t 1 ]]
}

_stdout_is_tty && ATOSHELL_QUIET="${ATOSHELL_QUIET:-0}" || ATOSHELL_QUIET="${ATOSHELL_QUIET:-1}"

_out() {
  [[ "$ATOSHELL_QUIET" == "1" ]] || printf '%s' "$*"
}

_outf() {
  [[ "$ATOSHELL_QUIET" == "1" ]] || printf "$@"
}

_status_ok() {
  local msg=""

  (($# > 0)) || return 0

  printf -v msg "$@"
  _outf '  [OK] %s\n' "$msg"
}

_status_warn() {
  local msg=""

  (($# > 0)) || return 0

  printf -v msg "$@"
  _outf '  [WARN] %s\n' "$msg"
}

# ── Error handling ────────────────────────────────────────────────────────────

# Standardized error reporting. Prints error message to stderr and returns 1.
# Usage: _error "message" ["usage string"]
_error() {
  local msg="$1"
  local usage="${2:-}"

  printf 'Error: %s\n' "$msg" >&2
  [[ -n "$usage" ]] && printf 'Usage: %s\n' "$usage" >&2
  return 1
}

# Strip terminal control sequences for human output only. Stored JSON stays raw.
_terminal_safe_text() {
  {
    if (($# > 0)); then
      printf '%s' "$1"
    else
      cat
    fi
  } |
    LC_ALL=C sed -E $'s/\x1B\\][^\x07\x1B]*(\x07|\x1B\\\\)//g; s/\x1B[P_^X][^\x1B]*(\x1B\\\\)//g; s/\x1B\\[[0-?]*[ -/]*[@-~]//g; s/\x1B\\].*//g; s/\x1B[P_^X].*//g; s/\x1B[@-Z\\\\-_]//g; s/\x1B//g' |
    LC_ALL=C tr -d '\000-\010\013\014\015-\037\177'
}

_terminal_safe_line() {
  local s

  s="$(_terminal_safe_text "$1")"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"

  printf '%s' "$s"
}

_jq_text() {
  jq -r "$@" | tr -d '\r'
}

# ── CLI and JSON errors ──────────────────────────────────────────────────────

# Emit a machine-readable error object to stderr.
# Usage: _json_error CODE [key value ...]
_json_error() {
  local code="$1"
  local obj

  shift
  obj="$(jq -n --arg c "$code" '{error: $c}')"

  while [[ $# -ge 2 ]]; do
    obj="$(jq -n --argjson base "$obj" --arg k "$1" --arg v "$2" '$base + {($k): $v}')"
    shift 2
  done

  printf '%s\n' "$obj" >&2
  exit 1
}

_cli_json_requested() {
  local arg

  for arg in "$@"; do
    [[ "$arg" == "--json" || "$arg" == "-j" ]] && return 0
  done

  return 1
}

_cli_error() {
  local json="$1"
  local code="$2"
  local message="$3"

  shift 3

  if [[ "$json" == true ]]; then
    _json_error "$code" "$@"
  fi

  printf 'Error: %s\n' "$(_terminal_safe_line "$message")" >&2
  exit 1
}

_cli_missing_value() {
  local json="$1"
  local option="$2"
  local message="${3:-$option requires a value.}"

  _cli_error "$json" "MISSING_ARGUMENT" "$message" "option" "$option"
}

# ── Interactive helpers ──────────────────────────────────────────────────────
_stdin_is_tty() {
  [[ -t 0 ]]
}

_require_tty() {
  # Call before any interactive prompt. Exits 1 with a clear message if stdin
  # is not a TTY so agents get an immediate error rather than a hung process.
  if ! _stdin_is_tty; then
    printf 'Error: interactive input required but stdin is not a TTY.\n' >&2
    printf 'Pass all required values as flags for non-interactive use.\n' >&2
    exit 1
  fi
}

_tty_read() {
  local __var_name="$1"
  local prompt="$2"
  local default="${3-}"
  local read_val=""

  _require_tty
  IFS= read -e -r -p "$prompt" read_val </dev/tty
  [[ -z "$read_val" && -n "$default" ]] && read_val="$default"
  printf -v "$__var_name" '%s' "$read_val"
}

_tty_read_with_initial() {
  local __var_name="$1"
  local prompt="$2"
  local initial="${3-}"
  local read_val=""

  _require_tty
  IFS= read -e -r -i "$initial" -p "$prompt" read_val </dev/tty
  printf -v "$__var_name" '%s' "$read_val"
}

_tty_read_multiline() {
  local __var_name="$1"
  local header="${2:-}"
  local input_line=""
  local -a lines=()

  _require_tty
  [[ -n "$header" ]] && printf '%s\n' "$header" >&2

  while IFS= read -r input_line </dev/tty; do
    [[ -z "$input_line" ]] && break
    lines+=("$input_line")
  done

  if (( ${#lines[@]} > 0 )); then
    local multiline_text="${lines[0]}"
    local next_index

    for (( next_index = 1; next_index < ${#lines[@]}; next_index++ )); do
      multiline_text+=$'\n'"${lines[$next_index]}"
    done

    printf -v "$__var_name" '%s' "$multiline_text"
  else
    printf -v "$__var_name" '%s' ''
  fi
}

ask() {
  local prompt="$1"
  local default="${2:-}"
  local val=""

  if [[ -n "$default" ]]; then
    _tty_read val "$prompt [$default]: " "$default"
  else
    _tty_read val "$prompt: "
  fi

  val="${val//\\ / }"
  printf '%s' "$val"
}

ask_yn() {
  local prompt="$1"
  local default="${2:-y}"
  local prompt_text ans

  while true; do
    if [[ "${default,,}" == "y" ]]; then
      prompt_text="$prompt [Y/n]: "
    else
      prompt_text="$prompt [y/N]: "
    fi

    _tty_read ans "$prompt_text" "$default"

    case "${ans,,}" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        printf 'Please answer y or n.\n' >&2
        ;;
    esac
  done
}

# ask_pick <label> <default_index> <opt1> <opt2> ...
# Prints a numbered list and returns the selected value.
ask_pick() {
  local label="$1"
  local default="$2"
  local i choice

  shift 2
  local options=("$@")

  printf '%s:\n' "$label" >&2
  for i in "${!options[@]}"; do
    printf '  %d. %s\n' "$i" "$(_terminal_safe_line "${options[$i]}")" >&2
  done

  while true; do
    _tty_read choice "  Choice [$default]: " "$default"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < ${#options[@]} )); then
      printf '%s' "${options[$choice]}"
      return 0
    fi
    printf '  Enter a number between 0 and %d.\n' "$(( ${#options[@]} - 1 ))" >&2
  done
}

# ── Actor helpers ────────────────────────────────────────────────────────────

# Normalise a named actor override. Bare positive integers become agent-N.
_normalize_actor() {
  local actor="${1:-}"

  if [[ "$actor" =~ ^[1-9][0-9]*$ ]]; then
    printf 'agent-%s' "$actor"
  else
    printf '%s' "$actor"
  fi
}

# Validate that an explicit actor override is a supported named-agent id.
# Accepted forms:
#   - bare positive integer (normalized later to agent-N)
#   - agent-N
_validate_actor() {
  local actor="${1:-}"
  local json="${2:-false}"

  if [[ -z "$actor" ]]; then
    if [[ "$json" == true ]]; then
      _json_error "MISSING_ARGUMENT" "option" "--as"
    fi
    printf 'Error: --as requires a non-empty value.\n' >&2
    exit 1
  fi

  if [[ "$actor" =~ ^([1-9][0-9]*|agent-[1-9][0-9]*)$ ]]; then
    return 0
  fi

  if [[ "$json" == true ]]; then
    _json_error "INVALID_ACTOR" "got" "$actor"
  fi
  printf 'Error: --as must be a positive number or agent-N (got "%s").\n' "$(_terminal_safe_line "$actor")" >&2
  exit 1
}

# Resolve the effective actor for audit/comment/accountable attribution.
# Defaults to USERNAME in interactive sessions and [agent] in non-TTY mode.
# Explicit overrides are only allowed in non-TTY mode.
_resolve_actor() {
  local as="${1:-}"
  local json="${2:-false}"

  if [[ -n "$as" ]]; then
    if _stdin_is_tty; then
      if [[ "$json" == true ]]; then
        _json_error "INVALID_ARGUMENT" "option" "--as"
      fi
      printf 'Error: --as is only allowed in non-interactive mode.\n' >&2
      exit 1
    fi

    _validate_actor "$as" "$json"
    printf '%s' "$(_normalize_actor "$as")"
    return
  fi

  _stdin_is_tty && printf '%s' "$USERNAME" || printf '%s' '[agent]'
}

# ── Help text ────────────────────────────────────────────────────────────────

# Print the header comment block of a script as help text (strips leading '# ').
_show_help() {
  awk 'NR==1{next} /^# ── /{exit} /^#/{sub(/^# ?/,""); print; next} /^[^#]/{exit}' "$1"
}
