#!/usr/bin/env bash
# prints.sh — Display and rendering helpers for atoshell command scripts
#
# Sourced automatically by helpers.sh — do not source directly.

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  [[ "$ATOSHELL_QUIET" == "1" ]] && return
  local title="$1"
  printf '\n'
  printf '+--------------------------------------------------+\n'
  printf '|  %-48s|\n' "$title"
  printf '+--------------------------------------------------+\n'
  printf '\n'
}

# ── Ticket display ────────────────────────────────────────────────────────────
# _print_ticket <id> <src_file> [details=false] [blocked_by=[]] [blocking=[]]
# Print a single ticket in human-readable form.
# blocked_by: JSON array of {id,title,status} for unresolved dependencies.
# blocking:   JSON array of {id,title,status} for tickets waiting on this one.
# Respects ATOSHELL_QUIET. Uses $PRIORITY_2 and $SIZE_2 from _load_config.
_print_ticket() {
  [[ "$ATOSHELL_QUIET" == "1" ]] && return
  local id="$1" src_file="$2" details="${3:-false}" blocked_by="${4:-[]}" blocking="${5:-[]}"
  printf '\n'
  jq -r --arg id "$id" --arg dp "$PRIORITY_2" --arg ds "$SIZE_2" \
     --argjson details    "$details" \
     --argjson blocked_by "$blocked_by" \
     --argjson blocking   "$blocking" '
    .tickets[] | select(.id | tostring == $id) |
    "  -- #\(.id): \(.title) ----------------------------",
    (if (.type // "") != "" then "  Type:         \(.type)" else empty end),
    "  Priority:     \(.priority // $dp)",
    "  Size:         \(.size // $ds)",
    "  Status:       \(.status)",
    (if ((.disciplines // []) | length) > 0 then "  Disciplines:  \(.disciplines | join(", "))" else empty end),
    (if ((.accountable // []) | length) > 0 then "  Accountable:  \(.accountable | map(if startswith("[") then . else "@\(.)" end) | join(", "))" else empty end),
    (if ((.dependencies // []) | length) > 0 then "  Dependencies: \(.dependencies | map("#\(.)") | join(", "))" else empty end),
    (if $details then
      "  Created:      by \(.created_by // "unknown")  \(.created_at // "unknown")",
      (if (.updated_at // "") != "" then "  Edited:       by \(.updated_by // "unknown")  \(.updated_at)" else empty end)
    else empty end),
    "",
    (if (.description // "") != "" then "  \(.description)" else empty end),
    (if ($blocked_by | length) > 0 or ($blocking | length) > 0 then
      "",
      "  . . . . . . . . . . . . . . . . . . . . . . . . ."
    else empty end),
    (if ($blocked_by | length) > 0 then
      "  Blocked by:   \($blocked_by | map("#\(.id) \(.title) [\(.status)]") | join(", "))"
    else empty end),
    (if ($blocking | length) > 0 then
      "  Blocking:     \($blocking | map("#\(.id)") | join(", "))"
    else empty end),
    (if (.comments | length) > 0 then
      "",
      "  -- Comments -------------------------------------------",
      (.comments | to_entries[] |
        "  #\(.key + 1) [\(.value.author // "?")] \(.value.text // .value.body // "")",
        (if $details then
          "    - \(.value.created_at // "")"
          + (if (.value.updated_at // "") != "" then " (edited \(.value.updated_at))" else "" end)
        else empty end),
        ""
      )
    else empty end)
  ' "$src_file" | _terminal_safe_text
  printf '\n'
}

# ── Board rendering ───────────────────────────────────────────────────────────
# Render the kanban board.
# Usage: _print_board [done] [all]
#   done — add a 4th "Done" column (suppresses the Done footer)
#   all  — show all tickets per column (bypasses default limit of 5)
# Reads config vars and file paths from caller scope via _load_config.
_print_board() {
  local done="${1:-}" full="${2:-}"
  local col_w=22 col_limit=5

  _col_header() { printf '|  %-*s' "$col_w" "${1:0:$col_w}"; }
  _col_cell()   { printf '|  %-*s' "$col_w" "${1:0:$col_w}"; }
  _divider() {
    local _num="${1:-4}"
    printf '+'
    local _dashes
    printf -v _dashes '%*s' $(( col_w + 2 )) ''
    _dashes="${_dashes// /-}"
    local _i
    for (( _i=0; _i<_num; _i++ )); do
      printf '%s+' "$_dashes"
    done
    printf '\n'
  }
  _board_safe_line() {
    local _s="$1"
    _s="${_s//$'\t'/ }"
    printf '%s' "$_s"
  }

  # Collect all board data in one jq pass; rendering stays in Bash below.
  local bl=() rd=() ip=() dn=() done_count=0
  local _key _line
  while IFS=$'\t' read -r _key _line; do
    [[ -n "$_key" ]] || continue
    case "$_key" in
      backlog)      bl+=("$(_board_safe_line "$_line")") ;;
      ready)        rd+=("$(_board_safe_line "$_line")") ;;
      in_progress)  ip+=("$(_board_safe_line "$_line")") ;;
      done)         dn+=("$(_board_safe_line "$_line")") ;;
      done_count)   done_count="${_line:-0}" ;;
    esac
  done < <(jq -r -s \
    --arg backlog "$STATUS_BACKLOG" \
    --arg ready "$STATUS_READY" \
    --arg in_progress "$STATUS_IN_PROGRESS" \
    --arg done "$STATUS_DONE" \
    --arg include_done "$done" '
    def emit($key; $tickets; $status):
      $tickets[]? | select(.status == $status) |
      [$key, "#\(.id) \(.title)"] | join("\t");
    emit("backlog"; .[0].tickets; $backlog),
    emit("ready"; .[1].tickets; $ready),
    emit("in_progress"; .[1].tickets; $in_progress),
    (if $include_done == "true" then
      emit("done"; .[2].tickets; $done)
    else
      ["done_count", (([.[2].tickets[]? | select(.status == $done)] | length) | tostring)] | join("\t")
    end)
  ' "$BACKLOG_FILE" "$QUEUE_FILE" "$DONE_FILE" 2>/dev/null | _terminal_safe_text || true)

  # Apply per-column limit unless --full
  _apply_limit() {
    local -n _ref="$1"
    local _total="${#_ref[@]}"
    if [[ "$full" != true && "$_total" -gt "$col_limit" ]]; then
      local _excess=$(( _total - col_limit ))
      _ref=("${_ref[@]:0:$col_limit}" "-- $_excess more --")
    fi
  }
  _apply_limit bl; _apply_limit rd; _apply_limit ip
  [[ "$done" == true ]] && _apply_limit dn

  # Find the tallest column
  local max_rows=0 num_cols=3
  [[ "$done" == true ]] && num_cols=4
  for n in "${#bl[@]}" "${#rd[@]}" "${#ip[@]}"; do
    (( n > max_rows )) && max_rows=$n
  done
  [[ "$done" == true ]] && (( ${#dn[@]} > max_rows )) && max_rows=${#dn[@]}

  printf '\n'
  _divider "$num_cols"
  _col_header "$(_terminal_safe_line "1 $STATUS_BACKLOG")"
  _col_header "$(_terminal_safe_line "2 $STATUS_READY")"
  _col_header "$(_terminal_safe_line "3 $STATUS_IN_PROGRESS")"
  [[ "$done" == true ]] && _col_header "$(_terminal_safe_line "4 $STATUS_DONE")"
  printf '|\n'
  _divider "$num_cols"

  if [[ "$max_rows" -eq 0 ]]; then
    _col_cell "(empty)"; _col_cell "(empty)"; _col_cell "(empty)"
    [[ "$done" == true ]] && _col_cell "(empty)"
    printf '|\n'
  else
    for (( i=0; i<max_rows; i++ )); do
      _col_cell "${bl[$i]:-}"; _col_cell "${rd[$i]:-}"
      _col_cell "${ip[$i]:-}"
      [[ "$done" == true ]] && _col_cell "${dn[$i]:-}"
      printf '|\n'
    done
  fi

  _divider "$num_cols"

  if [[ "$done" != true ]]; then
    printf '\n  %s: %d ticket(s)\n    Pass --done to show this column.\n\n' \
      "$(_terminal_safe_line "$STATUS_DONE")" "$done_count"
  else
    printf '\n'
  fi
}

# ── Blocker rendering ─────────────────────────────────────────────────────────
# Return all tickets that appear as dependencies, with what they're blocking.
# Each entry includes a `cycle` boolean (Kahn's algorithm over the full graph).
_blockers_json() {
  jq -rs --argjson pri_labels "$PRIORITY_LABELS_JSON" --arg s2 "$SIZE_2" '
    def priority_rank($value):
      ([range(0; ($pri_labels | length)) | select($pri_labels[.] == $value)][0]) // 2;
    [ .[].tickets[] ] as $all |

    # Kahn'\''s: identify cyclic ticket IDs
    ($all | map({key: (.id | tostring), value: ((.dependencies // []) | map(tostring))}) | from_entries) as $adj |
    ($all | map(.id | tostring) | map({key: ., value: 0}) | from_entries) as $zero_deg |
    reduce $all[] as $t (
      $zero_deg;
      reduce (($t.dependencies // []) | map(tostring))[] as $d (
        .; if has($d) then .[$d] += 1 else . end
      )
    ) | . as $in_deg |
    { q: [$in_deg | to_entries[] | select(.value == 0) | .key], processed: [], deg: $in_deg } |
    until(.q | length == 0;
      (.q[0]) as $n |
      .processed += [$n] | .q = .q[1:] |
      reduce ($adj[$n] // [])[] as $dep (
        .; if .deg | has($dep) then
          .deg[$dep] -= 1 |
          if .deg[$dep] == 0 then .q += [$dep] else . end
        else . end
      )
    ) |
    .processed as $proc |
    ($all | map(.id | tostring) | map(select(. as $id | $proc | any(. == $id) | not))) as $cyclic_ids |

    # Build blocker entries
    [ $all[] | . as $t | (.dependencies // [])[] | {dep_id: (. | tostring), blocked: $t} ] |
    group_by(.dep_id) |
    map(
      .[0].dep_id as $dep_id |
      (($all[] | select((.id | tostring) == $dep_id)) // empty) as $dep_ticket |
      {
        id: $dep_ticket.id,
        title: $dep_ticket.title,
        status: ($dep_ticket.status // ""),
        priority: ($dep_ticket.priority // $pri_labels[2]),
        size: ($dep_ticket.size // $s2),
        cycle: ($cyclic_ids | any(. == $dep_id)),
        blocking: [ .[].blocked | {id: .id, title: .title} ]
      }
    ) |
    sort_by(priority_rank(.priority), .id)
  ' "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE" 2>/dev/null
}

_print_blockers() {
  local data
  data=$(_blockers_json)
  local count
  count=$(jq 'length' <<< "$data")
  printf '\n'
  if [[ "$count" -eq 0 ]]; then
    printf '  (no blockers)\n\n'
    return
  fi
  printf '  -- Blockers (%d) ------------------------------------------\n' "$count"
  jq -r '.[] |
    (if .cycle then "  [CIRCULAR] " else empty end),
    "  #\(.id)  \(.priority)  \(.size)  [\(.status)]  \(.title)",
    "      → \(.blocking | map("#\(.id) \(.title)") | join(", "))",
    ""
  ' <<< "$data" | _terminal_safe_text
  printf '\n'
}

# ── List rendering ────────────────────────────────────────────────────────────
# _json_filtered and _print_filtered are called by list.sh.
# They read filter state from the caller scope:
#   $scope, $type, $priority, $size, $status, $disciplines, $acct
#   $ranked_ready_json (populated by _rank_ready_tickets for queue scope)
# Config constants (STATUS_*, PRIORITY_*, SIZE_*) come from setup helpers.
_json_filtered() {
  local file="$1"
  [[ ! -f "$file" ]] && return

  local ft="${type,,}" fp="${priority,,}" \
        fsz="${size,,}" fs="${status,,}" \
        fd="${disciplines,,}" fa="${acct,,}"

  if [[ "$scope" == "queue" ]]; then
    if [[ "${#ranked_ready_json}" -lt 20000 ]]; then
      jq -n -c \
        --argjson ready "$ranked_ready_json" \
        --slurpfile queue "$file" \
        --arg sr "${STATUS_READY,,}" \
        --arg sy "$STATUS_READY" \
        --arg ft "$ft" --arg fp "$fp" --arg fsz "$fsz" --arg fs "$fs" --arg fd "$fd" --arg fa "$fa" '
        def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
        def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
        def mf:
          ml((.type // "") | ascii_downcase; $ft) and
          ml((.priority // "") | ascii_downcase; $fp) and
          ml((.size // "") | ascii_downcase; $fsz) and
          mld((.disciplines // []); $fd) and
          mld((.accountable // []); $fa);
        ($queue[0].tickets // []) as $tickets |
        (if $fs == "" or $fs == $sr then
          [$ready[] | select(mf)]
        else [] end) as $ready_out |
        (if $fs == "" then
          [$tickets[] | select(.status != $sy and mf)]
        elif $fs != $sr then
          [$tickets[] | select((.status | ascii_downcase) == $fs and mf)]
        else [] end) as $nonready_out |
        $ready_out + $nonready_out'
      return
    fi

    local ready_tmp jq_status
    ready_tmp="$(_mktemp_sibling "$file")"
    printf '%s\n' "$ranked_ready_json" > "$ready_tmp"

    set +e
    jq -n -c \
      --slurpfile ready_json "$ready_tmp" \
      --slurpfile queue "$file" \
      --arg sr "${STATUS_READY,,}" \
      --arg sy "$STATUS_READY" \
      --arg ft "$ft" --arg fp "$fp" --arg fsz "$fsz" --arg fs "$fs" --arg fd "$fd" --arg fa "$fa" '
      def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
      def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
      def mf:
        ml((.type // "") | ascii_downcase; $ft) and
        ml((.priority // "") | ascii_downcase; $fp) and
        ml((.size // "") | ascii_downcase; $fsz) and
        mld((.disciplines // []); $fd) and
        mld((.accountable // []); $fa);
      ($queue[0].tickets // []) as $tickets |
      ($ready_json[0] // []) as $ready |
      (if $fs == "" or $fs == $sr then
        [$ready[] | select(mf)]
      else [] end) as $ready_out |
      (if $fs == "" then
        [$tickets[] | select(.status != $sy and mf)]
      elif $fs != $sr then
        [$tickets[] | select((.status | ascii_downcase) == $fs and mf)]
      else [] end) as $nonready_out |
      $ready_out + $nonready_out'
    jq_status=$?
    set -e
    rm -f "$ready_tmp"
    return "$jq_status"
  fi

  jq -c --arg ft "$ft" --arg fp "$fp" --arg fsz "$fsz" --arg fs "$fs" --arg fd "$fd" --arg fa "$fa" '
    def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
    def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
    [ .tickets[] | select(
      ($fs == "" or (.status | ascii_downcase) == $fs) and
      ml((.type // "") | ascii_downcase; $ft) and
      ml((.priority // "") | ascii_downcase; $fp) and
      ml((.size // "") | ascii_downcase; $fsz) and
      mld((.disciplines // []); $fd) and
      mld((.accountable // []); $fa)
    ) ]' "$file" 2>/dev/null
}

_print_filtered() {
  local file="$1" label="$2"
  [[ ! -f "$file" ]] && return

  local ft="${type,,}" fp="${priority,,}" \
        fsz="${size,,}" fs="${status,,}" \
        fd="${disciplines,,}" fa="${acct,,}"
  local safe_label
  safe_label="$(_terminal_safe_line "$label")"

  if [[ "$scope" == "queue" ]]; then
    local ready_tmp jq_status
    ready_tmp="$(_mktemp_sibling "$file")"
    printf '%s\n' "$ranked_ready_json" > "$ready_tmp"

    set +e
    jq -n -r \
      --slurpfile ready_json "$ready_tmp" \
      --slurpfile queue "$file" \
      --arg ft "$ft" --arg fp "$fp" --arg fsz "$fsz" --arg fs "$fs" --arg fd "$fd" --arg fa "$fa" \
      --arg sb "$STATUS_BACKLOG" --arg sy "$STATUS_READY" --arg sp "$STATUS_IN_PROGRESS" \
      --arg sd "$STATUS_DONE" \
      --arg label "$safe_label" \
      --arg dp "$PRIORITY_2" \
      --argjson pri_labels "$PRIORITY_LABELS_JSON" \
      --arg s0 "$SIZE_0" --arg s1 "$SIZE_1" --arg s2 "$SIZE_2" --arg s3 "$SIZE_3" --arg s4 "$SIZE_4" '
      def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
      def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
      def rpad(n): . + (" " * ([0, n - length] | max));
      def priority_rank($value):
        ([range(0; ($pri_labels | length)) | select($pri_labels[.] == $value)][0]) // 2;
      def size_rank($value):
        if $value == $s0 then 0 elif $value == $s1 then 1
        elif $value == $s2 then 2 elif $value == $s3 then 3 else 4 end;
      def status_rank($value):
        if $value == $sp then 0 elif $value == $sy then 1
        elif $value == $sb then 2 else 3 end;
      def mf:
        ml((.type // "") | ascii_downcase; $ft) and
        ml((.priority // "") | ascii_downcase; $fp) and
        ml((.size // "") | ascii_downcase; $fsz) and
        mld((.disciplines // []); $fd) and
        mld((.accountable // []); $fa);
      def render_common($iw; $szw; $dp; $s2):
        ("#" + (.id | tostring) | rpad($iw))
        + "  " + (.priority // $dp)
        + "  " + (.size // $s2 | rpad($szw))
        + "  " + ("[\(.status)]")
        + (if (.type // "") != "" then "  \(.type)" else "" end)
        + (if ((.disciplines // []) | length) > 0 then "  \(.disciplines | join(", "))" else "" end)
        + (if ((.accountable // []) | length) > 0 then "  \(.accountable | map(if startswith("[") then . else "@\(.)" end) | join(", "))" else "" end)
        + "  " + .title;
      def render_nonready($iw; $szw; $sw; $dp; $s2):
        ("#" + (.id | tostring) | rpad($iw))
        + "  " + (.priority // $dp)
        + "  " + (.size // $s2 | rpad($szw))
        + "  " + ("[\(.status)]" | rpad($sw))
        + (if (.type // "") != "" then "  \(.type)" else "" end)
        + (if ((.disciplines // []) | length) > 0 then "  \(.disciplines | join(", "))" else "" end)
        + (if ((.accountable // []) | length) > 0 then "  \(.accountable | map(if startswith("[") then . else "@\(.)" end) | join(", "))" else "" end)
        + "  " + .title;
      ($queue[0].tickets // []) as $tickets |
      ($ready_json[0] // []) as $ready |
      (if $fs == "" or $fs != ($sy | ascii_downcase) then
        [$tickets[] | select(
          (.status != $sy) and
          ($fs == "" or (.status | ascii_downcase) == $fs) and
          mf
        )] | sort_by(status_rank(.status), priority_rank(.priority // $dp), size_rank(.size // $s2))
      else [] end) as $nonready |
      (if $fs == "" or $fs == ($sy | ascii_downcase) then
        [$ready[] | select(mf)]
      else [] end) as $ready_items |
      (if ($nonready | length) > 0 then
        ($nonready | (map(.id | tostring | length) | max + 1) as $iw |
          ([$s0, $s1, $s2, $s3, $s4] | map(length) | max) as $szw |
          ([$sb, $sy, $sp, $sd] | map(length + 2) | max) as $sw |
          "  -- \($label) (\($nonready | length)) ------------------------------------------",
          ($nonready[] |
            "  " + render_nonready($iw; $szw; $sw; $dp; $s2)),
          "")
      else empty end),
      (if ($ready_items | length) > 0 then
        ($ready_items | (map(.id | tostring | length) | max + 1) as $iw |
          ([$s0, $s1, $s2, $s3, $s4] | map(length) | max) as $szw |
          "  -- Ready (\($ready_items | length)) ------------------------------------------",
          ($ready_items[] |
            (if ._block_reason == "cycle" then "[CIRCULAR]  "
             elif ._block_reason == "blocked" then "[BLOCKED]   "
             else "" end) as $tag |
            (if $tag != "" then "  \($tag)" else "  " end)
            + render_common($iw; $szw; $dp; $s2)),
          "")
      else empty end)' \
      2>/dev/null | _terminal_safe_text
    jq_status=${PIPESTATUS[0]}
    set -e
    rm -f "$ready_tmp"
    return "$jq_status"
  fi

  # Non-queue scopes: render count and rows from one filtered array.
  jq -r \
    --arg ft "$ft" --arg fp "$fp" --arg fsz "$fsz" --arg fs "$fs" --arg fd "$fd" --arg fa "$fa" \
    --arg sb "$STATUS_BACKLOG" --arg sy "$STATUS_READY" --arg sp "$STATUS_IN_PROGRESS" \
    --arg sd "$STATUS_DONE" \
    --arg label "$safe_label" \
    --arg dp "$PRIORITY_2" \
    --argjson pri_labels "$PRIORITY_LABELS_JSON" \
    --arg s0 "$SIZE_0" --arg s1 "$SIZE_1" --arg s2 "$SIZE_2" --arg s3 "$SIZE_3" --arg s4 "$SIZE_4" '
    def ml(v;l): l == "" or (v as $x | l | split(",") | any(. == $x));
    def mld(arr;l): l == "" or (arr | map(ascii_downcase) | any(ml(.;l)));
    def rpad(n): . + (" " * ([0, n - length] | max));
    def priority_rank($value):
      ([range(0; ($pri_labels | length)) | select($pri_labels[.] == $value)][0]) // 2;
    [ .tickets[] | select(
      ($fs == "" or (.status | ascii_downcase) == $fs) and
      ml((.type // "") | ascii_downcase; $ft) and
      ml((.priority // "") | ascii_downcase; $fp) and
      ml((.size // "") | ascii_downcase; $fsz) and
      mld((.disciplines // []); $fd) and
      mld((.accountable // []); $fa)
    ) ] |
    if length > 0 then
      . as $items |
      "  -- \($label) (\($items | length)) ------------------------------------------",
      ($items |
        sort_by(
          (if   .status == $sp then 0
           elif .status == $sy then 1
           elif .status == $sb then 2
           else 3 end),
          priority_rank(.priority // $dp),
          (.size // $s2 | if . == $s0 then 0 elif . == $s1 then 1
                          elif . == $s2 then 2 elif . == $s3 then 3 else 4 end)
        ) |
        (map(.id | tostring | length) | max + 1) as $iw |
        ([$s0, $s1, $s2, $s3, $s4] | map(length) | max) as $szw |
        ([$sb, $sy, $sp, $sd] | map(length + 2) | max) as $sw |
        .[] |
        "  " + ("#" + (.id | tostring) | rpad($iw))
            + "  " + (.priority // $dp)
            + "  " + (.size // $s2 | rpad($szw))
            + "  " + ("[\(.status)]" | rpad($sw))
            + (if (.type // "") != "" then "  \(.type)" else "" end)
            + (if ((.disciplines // []) | length) > 0 then "  \(.disciplines | join(", "))" else "" end)
            + (if ((.accountable // []) | length) > 0 then "  " + (.accountable | map(if startswith("[") then . else "@\(.)" end) | join(", ")) else "" end)
            + "  " + .title),
      ""
    else empty end
    ' "$file" 2>/dev/null | _terminal_safe_text
}
