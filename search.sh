#!/usr/bin/env bash
# search.sh — Search ticket content across titles, descriptions, and comments
#
# Usage:
#   atoshell search <query> [options]
#
# Aliases: hiku, crawl, find
#
# Options (Output):
#   --json|-j  Output matching tickets as a JSON array (agent-friendly)
#   --help|-h  Show 'search' usage help and exit

# ── Setup ─────────────────────────────────────────────────────────────────────
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"
_setup_readonly

# ── Parse flags ───────────────────────────────────────────────────────────────
query=""
json=false
_cli_json_requested "$@" && json=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --json|-j)
      json=true
      shift ;;
    *)
      if [[ "$1" == -* ]]; then
        _cli_error "$json" "UNKNOWN_OPTION" "unknown option \"$1\"." "option" "$1"
      fi
      query="${query:+$query }$1"
      shift ;;
  esac
done

[[ -z "$query" ]] && _cli_error "$json" "MISSING_ARGUMENT" "missing search query." "argument" "query"

# ── Shared: collect matching tickets from all files ───────────────────────────
files=()
for f in "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"; do
  [[ -f "$f" ]] && files+=("$f")
done

_search_filter='[ .[].tickets[] | select(
  (.title | ascii_downcase | contains($q)) or
  ((.description // "") | ascii_downcase | contains($q)) or
  ((.type // "") | ascii_downcase | contains($q)) or
  ((.priority // "") | ascii_downcase | contains($q)) or
  ((.size // "") | ascii_downcase | contains($q)) or
  ((.status // "") | ascii_downcase | contains($q)) or
  any((.disciplines // [])[]; ascii_downcase | contains($q)) or
  any((.accountable // [])[]; ascii_downcase | contains($q)) or
  any((.comments // [])[]; (.text // "") | ascii_downcase | contains($q))
) ]'

# ── JSON output ───────────────────────────────────────────────────────────────
if $json; then
  jq -rs --arg q "${query,,}" "$_search_filter" "${files[@]}"
  exit 0
fi

# ── Human output ──────────────────────────────────────────────────────────────
display_query="$(_terminal_safe_line "$query")"
printf '\n  Searching for "%s"...\n\n' "$display_query"

results=$(jq -rs \
  --arg q  "${query,,}" \
  --arg sp "$STATUS_IN_PROGRESS" \
  --arg sy "$STATUS_READY" \
  --arg sb "$STATUS_BACKLOG" \
  --arg sd "$STATUS_DONE" \
  --argjson pri_labels "$PRIORITY_LABELS_JSON" \
  --arg s0 "$SIZE_0" --arg s1 "$SIZE_1" --arg s2 "$SIZE_2" --arg s3 "$SIZE_3" --arg s4 "$SIZE_4" \
  --arg dp "$PRIORITY_2" \
  --arg ds "$SIZE_2" \
  "$_search_filter"' |
  def priority_rank($value):
    ([range(0; ($pri_labels | length)) | select($pri_labels[.] == $value)][0]) // 2;
  sort_by(
    (if   .status == $sp then 0
     elif .status == $sy then 1
     elif .status == $sb then 2
     else 3 end),
    priority_rank(.priority // $dp),
    (.size // $ds | if . == $s0 then 0 elif . == $s1 then 1
                    elif . == $s2 then 2 elif . == $s3 then 3 else 4 end)
  ) |
  def rpad(n): . + (" " * ([0, n - length] | max));
  (map(.id | tostring | length) | max + 1) as $iw |
  ([$sb, $sy, $sp, $sd] | map(length + 2) | max) as $sw |
  .[] |
  "  " + ("#" + (.id | tostring) | rpad($iw))
      + "  " + (.priority // $dp)
      + "  " + ((.size // $ds) | rpad(2))
      + "  " + ("[\(.status)]" | rpad($sw))
      + "  " + .title
  ' "${files[@]}" 2>/dev/null | _terminal_safe_text || true)

if [[ -n "$results" ]]; then
  printf '%s\n' "$results"
else
  printf '  No results for "%s".\n' "$display_query"
fi
printf '\n'
