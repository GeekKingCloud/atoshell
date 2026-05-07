#!/usr/bin/env bash
# list.sh — List tickets with optional filters
#
# Usage:
#   atoshell list [scope] [options]
#
# Aliases: rekki, draw
#
# Scopes (default: queue):
#   File-based:   queue (q) | backlog (bl) | done (d)
#   Status-based: ready (rd) | in-progress (ip) | done (d) | blockers (deps)
#
# Options (Filters):
#   --type|--kind|-t <Bug|Feature|Task|0-2>  Comma-separated type
#   --priority|-p <P0|P1|...|0-3>            Comma-separated priority
#   --size|-s <XS|S|M|L|XL|0-4>              Comma-separated size
#   --status|-S <status>                     Status
#   --disciplines|--discipline|--dis|-d <n>  Comma-separated fixed discipline tags
#   --accountable|--assign|-a <user>         Filter by accountable ("me" = current user)
#   --mine|--me|-M                           Filter for current user's tickets
#   --agent|-A                               Filter for tickets assigned to "agent"
# Options (Output):
#   --json|-j                                Output as JSON array/object (agent-friendly)
#   --help|-h                                Show 'list' usage help and exit
#
# Valid disciplines (fixed): Frontend, Backend, Database, Cloud, DevOps, Architecture, Automation, QA, Research, Core
# Discipline aliases: fe=Frontend, be=Backend
# Disciplines match tickets to relevant capability areas.

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
_setup_readonly

# ── Parse args ────────────────────────────────────────────────────────────────
type="" priority="" size="" status="" disciplines="" acct=""
scope="queue" json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    queue|q)
      scope="queue"
      shift ;;
    backlog|bl)
      scope="backlog"
      shift ;;
    ready|rd)
      scope="ready"
      shift ;;
    in-progress|ip)
      scope="in-progress"
      shift ;;
    done|d)
      scope="done"
      shift ;;
    blockers|deps)
      scope="blockers"
      shift ;;
    --type|--kind|-t)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--type"
      type="$(_resolve_type_filter "$2" "$json")" || exit 1
      shift 2 ;;
    --priority|-p)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--priority"
      priority="$(_resolve_priority_filter "$2" "$json")" || exit 1
      shift 2 ;;
    --size|-s)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--size"
      size="$(_resolve_size_filter "$2" "$json")" || exit 1
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
      _resolve_discs "$2" "$json"
      shift 2 ;;
    --accountable|--assign|-a)
      [[ $# -lt 2 ]] && _cli_missing_value "$json" "--accountable"
      _u="$2"; [[ "$_u" == "me" ]] && _u="$USERNAME"
      acct="$_u"
      shift 2 ;;
    --mine|--me|-M)
      acct="$USERNAME"
      shift ;;
    --agent|-A)
      acct="[agent]"
      shift ;;
    --json|-j)
      json=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        _cli_error "$json" "UNKNOWN_OPTION" "unknown option \"$1\"." "option" "$1"
      fi
      scope="$1"
      shift ;;
  esac
done

# ── Validate scope ────────────────────────────────────────────────────────────
if [[ -n "$scope" ]]; then
  case "$scope" in
    queue|q|backlog|bl|done|d|ready|rd|in-progress|ip|blockers|deps) ;;
    *)
      _cli_error "$json" "UNEXPECTED_ARGUMENT" "unknown list scope \"$scope\"." "got" "$scope" ;;
  esac
fi

# ── Derive scope from status when --status is the primary filter ───────────────
if [[ -n "$status" ]]; then
  case "${status,,}" in
    "${STATUS_BACKLOG,,}")      scope="backlog"     ;;
    "${STATUS_READY,,}")        scope="ready"       ;;
    "${STATUS_IN_PROGRESS,,}")  scope="in-progress" ;;
    "${STATUS_DONE,,}")         scope="done"        ;;
  esac
fi

# ── Blockers view ─────────────────────────────────────────────────────────────
if [[ "$scope" == "blockers" ]]; then
  $json && { _blockers_json; exit 0; }
  _print_blockers
  exit 0
fi

# ── Ready-ticket ranking pipeline ─────────────────────────────────────────────
# Populates ranked_ready_json and topo_count for queue/ready/in-progress scopes — see funcs/algorithms.sh
ranked_ready_json='[]'
topo_count=0

[[ "$scope" == "queue" || "$scope" == "ready" ]] && _rank_ready_tickets

# ── Scope → file, label, status ───────────────────────────────────────────────
case "$scope" in
  backlog)
    target_file="$BACKLOG_FILE" label="Backlog" ;;
  done)
    target_file="$DONE_FILE" label="$STATUS_DONE"
    [[ -z "$status" ]] && status="$STATUS_DONE"
    scope="done" ;;
  ready)
    target_file="$QUEUE_FILE" label="$STATUS_READY"
    [[ -z "$status" ]] && status="$STATUS_READY"
    scope="queue" ;;
  in-progress)
    target_file="$QUEUE_FILE" label="$STATUS_IN_PROGRESS"
    [[ -z "$status" ]] && status="$STATUS_IN_PROGRESS"
    scope="queue" ;;
  *)
    target_file="$QUEUE_FILE" label="Active" ;;
esac

if $json; then
  _json_filtered "$target_file"
else
  printf '\n'
  _print_filtered "$target_file" "$label"
  printf '\n'
fi
