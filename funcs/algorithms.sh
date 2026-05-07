#!/usr/bin/env bash
# algorithms.sh — Ticket ranking algorithms
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/algorithms.sh"
#
# Provided functions:
#   _check_cyclic_deps    Detect cycles in the dependency graph (Kahn's algorithm).
#   _rank_ready_tickets   Rank Ready tickets using Kahn's cycle detection,
#                           BFS budget promotion, and priority topo-sort.

# ── _check_cyclic_deps ────────────────────────────────────────────────────────
# _check_cyclic_deps <ticket_id> [dep_id...]
# Returns 0 if no cycle, 1 if a cycle is detected in the dependency graph.
# Loads all tickets from all three files to build the full graph.
# If dep_ids are provided, they override the stored deps for ticket_id
# (used when adding deps to a ticket that hasn't been saved yet).
_check_cyclic_deps() {
  local ticket_id="$1"
  shift
  local -a extra_deps=("$@")

  # Build dep graph from all files
  local graph_json
  graph_json=$(jq -s '
    [.[].tickets[] | {id: (.id | tostring), deps: ((.dependencies // []) | map(tostring))}]
  ' "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE" 2>/dev/null || echo '[]')

  if [[ ${#extra_deps[@]} -gt 0 ]]; then
    local extra_json
    extra_json=$(printf '%s\n' "${extra_deps[@]}" | jq -R '.' | jq -s '.')
    graph_json=$(jq --arg id "$ticket_id" --argjson new_deps "$extra_json" '
      map(select(.id != $id)) + [{id: $id, deps: $new_deps}]
    ' <<< "$graph_json")
  fi

  # Kahn's cycle detection via jq — returns "ok" or "cyclic"
  local result
  result=$(jq -r '
    . as $tickets |
    (map({key: .id, value: .deps}) | from_entries) as $adj |
    ([.[].id] | map({key: ., value: 0}) | from_entries) as $zero |
    reduce $tickets[] as $t (
      $zero;
      reduce $t.deps[] as $d (.; if has($d) then .[$d] += 1 else . end)
    ) | . as $deg |
    { q: [$deg | to_entries[] | select(.value == 0) | .key], seen: 0, d: $deg } |
    until(.q | length == 0;
      (.q[0]) as $n |
      .seen += 1 | .q = .q[1:] |
      reduce ($adj[$n] // [])[] as $dep (
        .;
        if .d | has($dep) then
          .d[$dep] -= 1 |
          if .d[$dep] == 0 then .q += [$dep] else . end
        else . end
      )
    ) |
    if .seen == ($tickets | length) then "ok" else "cyclic" end
  ' <<< "$graph_json")

  [[ "$result" == "ok" ]]
}

# ── _rank_ready_tickets ───────────────────────────────────────────────────────
# Inputs (reads from env, set by _setup or _setup_readonly):
#   $QUEUE_FILE, $DONE_FILE
#   $STATUS_READY
#   $UNBLOCK_P0_BUDGET, $UNBLOCK_P1_BUDGET
#
# Outputs (via declare -g):
#   ranked_ready_json   — ordered array of all Ready tickets; tickets beyond
#                         topo_count annotated with _block_reason: "blocked"|"cycle"
#   topo_count          — index boundary: [0:topo_count] are actionable, rest blocked/cyclic
_rank_ready_tickets() {
  # Build the set of "satisfied" dep IDs — deps that don't need to be waited on.
  # Includes only done tickets.
  # A dep pointing at any of these is treated as already fulfilled.
  local _satisfied_ids
  _satisfied_ids=$(jq '[.tickets[].id] | map(tostring)' \
    "$DONE_FILE" 2>/dev/null || echo '[]')

  local _all_ready_json
  _all_ready_json=$(jq -c \
    --arg status "$STATUS_READY" \
    '[.tickets[] | select(.status == $status)]' \
    "$QUEUE_FILE" 2>/dev/null || echo '[]')

  local _rr_ticket_count
  _rr_ticket_count=$(jq 'length' <<< "$_all_ready_json")

  if [[ "$_rr_ticket_count" -eq 0 ]]; then
    return
  fi

  # Annotate each Ready ticket with numeric sort keys and split its deps into
  # two buckets:
  #   deps_ready    — unsatisfied deps that are also in the Ready list
  #                   (these create ordering constraints between ready tickets)
  #   deps_external — unsatisfied deps NOT in the Ready list
  #                   (these externally block the ticket entirely)
  # `priority` is the string label ("P2") kept for output; `pri` is the
  # numeric rank (0-3) used for integer comparisons in bash.
  local _ticket_rows
  _ticket_rows=$(jq -r \
    --argjson sat "$_satisfied_ids" \
    --argjson pri_labels "$PRIORITY_LABELS_JSON" \
    --argjson size_labels "$SIZE_LABELS_JSON" '
    def label_rank($labels; $value; $fallback):
      ([range(0; ($labels | length)) | select($labels[.] == $value)][0]) // $fallback;
    ( [.[].id | tostring] ) as $ready_ids |
    .[] |
      (.priority // $pri_labels[2]) as $priority |
      [
        (.id | tostring),
        $priority,
        (label_rank($pri_labels; $priority; 2) | tostring),
        (label_rank($size_labels; (.size // $size_labels[2]); 2) | tostring),
        ((.dependencies // []) | map(tostring) |
         map(select(. as $d |
           ($sat | any(. == $d) | not) and
           ($ready_ids | any(. == $d))
         )) | join(" ")),
        ((.dependencies // []) | map(tostring) |
         map(select(. as $d |
           ($sat | any(. == $d) | not) and
           ($ready_ids | any(. == $d) | not)
         )) | join(" "))
      ] | join("\u001c")' <<< "$_all_ready_json")

  # Load annotated ticket data into bash associative arrays for fast lookup.
  # _eff_pri starts equal to _orig_pri; budget promotion may lower it later.
  declare -A _eff_pri _orig_pri _eff_sz _ticket_deps_ready _ticket_deps_external _ticket_priority _has_external_block
  declare -a _ticket_ids=()

  # Use a non-whitespace delimiter so empty dep buckets stay in their columns.
  local _id _priority _pri _sz _deps_ready _deps_external
  while IFS=$'\034' read -r _id _priority _pri _sz _deps_ready _deps_external; do
    [[ -z "$_id" ]] && continue
    _ticket_ids+=("$_id")
    _ticket_priority["$_id"]="$_priority"
    _eff_pri["$_id"]=$_pri
    _orig_pri["$_id"]=$_pri
    _eff_sz["$_id"]=$_sz
    _ticket_deps_ready["$_id"]="${_deps_ready:-}"
    _ticket_deps_external["$_id"]="${_deps_external:-}"
    [[ -n "${_ticket_deps_external["$_id"]}" ]] && _has_external_block["$_id"]=true
  done <<< "$_ticket_rows"

  # ── Cycle detection (Kahn's algorithm, pass 1) ──────────────────────────
  # Build in-degree counts and reverse-dep map across ready-deps only.
  # Any ticket not drained by the BFS is part of a cycle.
  declare -A _kahn_in _kahn_rdeps_c _kahn_proc_set
  declare -a _kahn_q=() _kahn_proc=()

  local _tid _dep _cnt _cur_node _consumer
  # Count how many ready deps each ticket is waiting on (in-degree).
  for _tid in "${_ticket_ids[@]}"; do
    _cnt=0
    for _dep in ${_ticket_deps_ready["$_tid"]:-}; do
      [[ -n "${_eff_pri[$_dep]+_}" ]] && _cnt=$(( _cnt + 1 ))
    done
    _kahn_in["$_tid"]=$_cnt
    _kahn_rdeps_c["$_tid"]=""
  done

  # Build reverse map: for each dep, which tickets are waiting on it.
  for _tid in "${_ticket_ids[@]}"; do
    for _dep in ${_ticket_deps_ready["$_tid"]:-}; do
      [[ -n "${_eff_pri[$_dep]+_}" ]] && _kahn_rdeps_c["$_dep"]+=" $_tid"
    done
  done

  # Seed the queue with tickets that have no unsatisfied ready deps.
  for _tid in "${_ticket_ids[@]}"; do
    (( _kahn_in["$_tid"] == 0 )) && _kahn_q+=("$_tid")
  done

  # Process the queue: each time a ticket is drained, decrement the
  # in-degree of anything waiting on it and enqueue newly unblocked tickets.
  local _kahn_head=0
  while (( _kahn_head < ${#_kahn_q[@]} )); do
    _cur_node="${_kahn_q[$_kahn_head]}"
    _kahn_head=$(( _kahn_head + 1 ))
    _kahn_proc+=("$_cur_node")
    _kahn_proc_set["$_cur_node"]=true
    for _consumer in ${_kahn_rdeps_c["$_cur_node"]:-}; do
      _kahn_in["$_consumer"]=$(( _kahn_in["$_consumer"] - 1 ))
      (( _kahn_in["$_consumer"] == 0 )) && _kahn_q+=("$_consumer")
    done
  done

  # Any ticket not in _kahn_proc was never drained — it's in a cycle.
  declare -A _is_cyclic=()
  for _tid in "${_ticket_ids[@]}"; do
    if [[ -z "${_kahn_proc_set[$_tid]+_}" ]]; then
      _is_cyclic["$_tid"]=true
      printf '[WARN] Ticket #%s is part of a dependency cycle.\n' "$_tid" >&2
    fi
  done

  # ── Budget promotion (BFS transitive deps) ──────────────────────────────
  # For high-priority tickets (P0/P1), walk the full transitive dep tree and
  # check if the total cost (sum of dep sizes) fits within the configured
  # budget. If it does, promote all transitive deps to the ticket's priority
  # so they float to the top of the sort. P0 deps cost 0 (already critical).
  _transitive_deps_bfs() {
    local _start="$1"
    local -a _bfs_q=() _bfs_visited=()
    local -A _bfs_seen=()
    for _dep in ${_ticket_deps_ready["$_start"]:-}; do
      [[ -z "${_eff_pri[$_dep]+_}" ]] && continue
      [[ "${_is_cyclic[$_dep]:-}" == "true" ]] && continue
      _bfs_q+=("$_dep"); _bfs_visited+=("$_dep")
      _bfs_seen["$_dep"]=true
    done
    local _bfs_head=0
    while (( _bfs_head < ${#_bfs_q[@]} )); do
      local _cur="${_bfs_q[$_bfs_head]}"
      _bfs_head=$(( _bfs_head + 1 ))
      for _dep in ${_ticket_deps_ready["$_cur"]:-}; do
        [[ -z "${_eff_pri[$_dep]+_}" ]] && continue
        [[ "${_is_cyclic[$_dep]:-}" == "true" ]] && continue
        [[ -n "${_bfs_seen[$_dep]+_}" ]] && continue
        _bfs_seen["$_dep"]=true
        _bfs_visited+=("$_dep"); _bfs_q+=("$_dep")
      done
    done
    (( ${#_bfs_visited[@]} > 0 )) && printf '%s\n' "${_bfs_visited[@]}"
  }

  # Process tickets highest-priority first so a P0 ticket can't have its
  # deps promoted by a P1 ticket that's processed first.
  declare -a _sorted_ids
  mapfile -t _sorted_ids < <(
    for _tid in "${_ticket_ids[@]}"; do
      printf '%d %d %s\n' "${_orig_pri[$_tid]}" "${_eff_sz[$_tid]}" "$_tid"
    done | sort -n -k1 -k2 -k3 | awk '{print $3}'
  )

  local _p0_budget _p1_budget _local_pri _trans_deps _total_cost _dep_id _dep_priority _dep_cost _promote
  _p0_budget="${UNBLOCK_P0_BUDGET:-}"
  _p1_budget="${UNBLOCK_P1_BUDGET:-3}"

  for _tid in "${_sorted_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && continue
    _local_pri=${_orig_pri["$_tid"]}
    (( _local_pri >= 2 )) && continue   # only promote for P0/P1 tickets
    mapfile -t _trans_deps < <(_transitive_deps_bfs "$_tid")
    [[ ${#_trans_deps[@]} -eq 0 ]] && continue
    # Sum dep costs; P0 deps are free (they're already critical).
    _total_cost=0
    for _dep_id in "${_trans_deps[@]}"; do
      _dep_priority="${_ticket_priority[$_dep_id]:-$PRIORITY_2}"
      if [[ "$_dep_priority" == "$PRIORITY_0" ]]; then
        _dep_cost=0
      else
        _dep_cost=${_eff_sz["$_dep_id"]:-2}
      fi
      _total_cost=$(( _total_cost + _dep_cost ))
    done
    # Promote if within budget (P0 budget empty = infinite).
    _promote=false
    if [[ "${_ticket_priority[$_tid]}" == "$PRIORITY_0" ]]; then
      [[ -z "$_p0_budget" || "$_total_cost" -le "$_p0_budget" ]] && _promote=true
    elif [[ "${_ticket_priority[$_tid]}" == "$PRIORITY_1" ]]; then
      (( _total_cost <= _p1_budget )) && _promote=true
    fi
    if $_promote; then
      for _dep_id in "${_trans_deps[@]}"; do
        (( _eff_pri["$_dep_id"] > _local_pri )) && _eff_pri["$_dep_id"]=$_local_pri
      done
    fi
  done

  # ── Topological sort with effective priority (Kahn's, pass 2) ───────────
  # Same Kahn's structure as cycle detection, but now we greedily pick the
  # best available ticket at each step (lowest eff priority → size → id)
  # rather than processing in arbitrary order.
  declare -A _pending _rdeps_map _output_set
  declare -a _available=() _output_ids=()

  local _best _best_pri _best_sz _best_id_num _id_num _new_avail

  # In-degree and reverse map, excluding cyclic tickets.
  for _tid in "${_ticket_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && continue
    _cnt=0
    for _dep in ${_ticket_deps_ready["$_tid"]:-}; do
      [[ -n "${_eff_pri[$_dep]+_}" ]] && [[ "${_is_cyclic[$_dep]:-}" != "true" ]] \
        && _cnt=$(( _cnt + 1 ))
    done
    _pending["$_tid"]=$_cnt
    _rdeps_map["$_tid"]=""
  done

  for _tid in "${_ticket_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && continue
    for _dep in ${_ticket_deps_ready["$_tid"]:-}; do
      [[ -n "${_eff_pri[$_dep]+_}" ]] && [[ "${_is_cyclic[$_dep]:-}" != "true" ]] \
        && _rdeps_map["$_dep"]+=" $_tid"
    done
  done

  for _tid in "${_ticket_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && continue
    [[ "${_has_external_block["$_tid"]:-}" == "true" ]] && continue
    (( _pending["$_tid"] == 0 )) && _available+=("$_tid")
  done

  # Greedily emit the best available ticket, then unlock its dependents.
  # Tiebreak: effective priority → size → ticket ID (lower = older = first).
  while (( ${#_available[@]} > 0 )); do
    _best="" _best_pri=999 _best_sz=999 _best_id_num=999999
    for _tid in "${_available[@]}"; do
      _id_num=$(( _tid ))
      if   (( _eff_pri["$_tid"] < _best_pri )) ||
           (( _eff_pri["$_tid"] == _best_pri && _eff_sz["$_tid"] < _best_sz )) ||
           (( _eff_pri["$_tid"] == _best_pri && _eff_sz["$_tid"] == _best_sz && _id_num < _best_id_num )); then
        _best=$_tid _best_pri=${_eff_pri["$_tid"]} _best_sz=${_eff_sz["$_tid"]} _best_id_num=$_id_num
      fi
    done
    _new_avail=()
    for _tid in "${_available[@]}"; do [[ "$_tid" != "$_best" ]] && _new_avail+=("$_tid"); done
    _available=("${_new_avail[@]+"${_new_avail[@]}"}")
    _output_ids+=("$_best")
    _output_set["$_best"]=true
    for _consumer in ${_rdeps_map["$_best"]:-}; do
      _pending["$_consumer"]=$(( _pending["$_consumer"] - 1 ))
      [[ "${_has_external_block["$_consumer"]:-}" == "true" ]] && continue
      (( _pending["$_consumer"] == 0 )) && _available+=("$_consumer")
    done
  done

  # topo_count marks the boundary between actionable and blocked tickets in
  # _output_ids. Tickets before this index have no unsatisfied deps.
  declare -g topo_count
  topo_count=${#_output_ids[@]}

  # ── Append blocked tickets (externally blocked, then circular) ───────────
  # These come after the actionable slice so they still appear in the output
  # (visible but clearly tagged), sorted by priority within each group.

  local -a _rr_remaining_blocked=() _rr_cyclic_ids=()
  local _a _b _i _j

  # Externally-blocked: not in _output_ids and not cyclic.
  for _tid in "${_ticket_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && continue
    [[ -z "${_output_set[$_tid]+_}" ]] && _rr_remaining_blocked+=("$_tid")
  done

  # Sort externally-blocked by effective priority → size → id.
  for (( _i=0; _i<${#_rr_remaining_blocked[@]}; _i++ )); do
    for (( _j=_i+1; _j<${#_rr_remaining_blocked[@]}; _j++ )); do
      _a=${_rr_remaining_blocked[$_i]} _b=${_rr_remaining_blocked[$_j]}
      if   (( _eff_pri["$_b"] < _eff_pri["$_a"] )) ||
           (( _eff_pri["$_b"] == _eff_pri["$_a"] && _eff_sz["$_b"] < _eff_sz["$_a"] )) ||
           (( _eff_pri["$_b"] == _eff_pri["$_a"] && _eff_sz["$_b"] == _eff_sz["$_a"] && _b < _a )); then
        _rr_remaining_blocked[$_i]=$_b _rr_remaining_blocked[$_j]=$_a
      fi
    done
  done
  [[ ${#_rr_remaining_blocked[@]} -gt 0 ]] && _output_ids+=("${_rr_remaining_blocked[@]}")

  # Circular tickets sorted by original priority (eff priority is meaningless
  # for cycles since promotion never completed).
  for _tid in "${_ticket_ids[@]}"; do
    [[ "${_is_cyclic[$_tid]:-}" == "true" ]] && _rr_cyclic_ids+=("$_tid")
  done
  for (( _i=0; _i<${#_rr_cyclic_ids[@]}; _i++ )); do
    for (( _j=_i+1; _j<${#_rr_cyclic_ids[@]}; _j++ )); do
      _a=${_rr_cyclic_ids[$_i]} _b=${_rr_cyclic_ids[$_j]}
      if   (( _orig_pri["$_b"] < _orig_pri["$_a"] )) ||
           (( _orig_pri["$_b"] == _orig_pri["$_a"] && _eff_sz["$_b"] < _eff_sz["$_a"] )) ||
           (( _orig_pri["$_b"] == _orig_pri["$_a"] && _eff_sz["$_b"] == _eff_sz["$_a"] && _b < _a )); then
        _rr_cyclic_ids[$_i]=$_b _rr_cyclic_ids[$_j]=$_a
      fi
    done
  done
  [[ ${#_rr_cyclic_ids[@]} -gt 0 ]] && _output_ids+=("${_rr_cyclic_ids[@]}")

  # Reorder _all_ready_json to match _output_ids, annotating blocked/cyclic tickets
  # with _block_reason so the display layer can derive tags from the JSON alone.
  if [[ ${#_output_ids[@]} -gt 0 ]]; then
    local _order_json _blocked_json _cyclic_json
    _order_json=$(printf '%s\n' "${_output_ids[@]}" | jq -R 'tonumber' | jq -s '.')
    _blocked_json=$( (( ${#_rr_remaining_blocked[@]} > 0 )) \
      && printf '%s\n' "${_rr_remaining_blocked[@]}" | jq -R 'tonumber' | jq -s '.' \
      || echo '[]' )
    _cyclic_json=$( (( ${#_rr_cyclic_ids[@]} > 0 )) \
      && printf '%s\n' "${_rr_cyclic_ids[@]}" | jq -R 'tonumber' | jq -s '.' \
      || echo '[]' )
    declare -g ranked_ready_json
    ranked_ready_json=$(jq -c \
      --argjson order "$_order_json" \
      --argjson blocked "$_blocked_json" \
      --argjson cyclic "$_cyclic_json" '
      (map({key: (.id | tostring), value: .}) | from_entries) as $by_id |
      [ $order[] as $oid | ($by_id[$oid | tostring] // empty) |
        if   ($cyclic  | any(. == $oid)) then . + {_block_reason: "cycle"}
        elif ($blocked | any(. == $oid)) then . + {_block_reason: "blocked"}
        else . end ]' <<< "$_all_ready_json")
  fi
}
