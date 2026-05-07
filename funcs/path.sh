#!/usr/bin/env bash
# Path and project resolution helpers for atoshell.
_dirname() {
  local path="${1:-}"
  case "$path" in
    */*)
      path="${path%/*}"
      [[ -n "$path" ]] || path="/"
      printf '%s\n' "$path"
      ;;
    *)
      printf '.\n'
      ;;
  esac
}
_basename() {
  local path="${1:-}"
  path="${path%/}"
  case "$path" in
    */*) printf '%s\n' "${path##*/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}
_source_path() {
  local source_path="${1:-${BASH_SOURCE[0]-}}"
  if [[ -z "$source_path" || "$source_path" == "bash" || "$source_path" == "-bash" ]]; then
    source_path="${BASH_ARGV0:-}"
  fi
  if [[ -z "$source_path" || "$source_path" == "bash" || "$source_path" == "-bash" ]]; then
    source_path="${0-}"
  fi
  printf '%s\n' "$source_path"
}
_source_dir() {
  local source_path
  source_path="$(_source_path "${1:-}")"
  cd "$(_dirname "$source_path")" && pwd
}
ATOSHELL_DIR="${ATOSHELL_DIR:-$(_source_dir "${BASH_SOURCE[0]-}")/..}"
# Fixed taxonomy for ticket tagging and filtering. This is intentionally not a
# config.env value; project configs should not redefine the meaning of tickets.
DISCIPLINE_LABELS="Frontend,Backend,Database,Cloud,DevOps,Architecture,Automation,QA,Research,Core"
_resolve_project() {
  local walk="${1:-false}"
  if [[ -d "$PWD/.atoshell" ]]; then
    printf '%s' "$PWD"
    return
  fi
  if [[ "$walk" == true ]]; then
    local d="$PWD"
    while [[ "$d" != "/" ]]; do
      [[ -d "$d/.atoshell" ]] && { printf '%s' "$d"; return; }
      d="$(_dirname "$d")"
    done
  fi
  printf 'Error: no .atoshell/ found in current directory.\n' >&2
  printf 'Run "atoshell init" to initialise a project here.\n' >&2
  exit 1
}
