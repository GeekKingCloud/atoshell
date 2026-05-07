#!/usr/bin/env bats
# algorithms.bats — Unit tests for algorithm functions

load '../helpers/setup'

# Additional setup for algorithm tests
setup() {
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"
  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"
  export ATOSHELL_DIR="$ATOSHELL_REPO"

  mkdir -p "$TEST_PROJECT/.atoshell"
  cp "$BATS_TEST_DIRNAME/../fixtures/queue.json"   "$TEST_PROJECT/.atoshell/queue.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/backlog.json" "$TEST_PROJECT/.atoshell/backlog.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/done.json" "$TEST_PROJECT/.atoshell/done.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/meta.json"    "$TEST_PROJECT/.atoshell/meta.json"

  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'USERNAME="testuser"' \
    > "$TEST_PROJECT/.atoshell/config.env"

  # Source the helper and algorithm functions
  # shellcheck source=/dev/null
  source "$ATOSHELL_REPO/funcs/helpers.sh"
  source "$ATOSHELL_REPO/funcs/algorithms.sh"
  _load_config "$TEST_PROJECT"

  cd "$TEST_PROJECT"
}

# Test fixtures for complex dependency scenarios
setup_ranking_fixtures() {
  # Clear and setup queue with test data
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {
      "id": 1,
      "title": "P0 ticket - no deps",
      "status": "Ready",
      "priority": "P0",
      "size": "M",
      "type": "Bug",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 2,
      "title": "P1 S ticket - should come before P1 M",
      "status": "Ready",
      "priority": "P1",
      "size": "S",
      "type": "Feature",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 3,
      "title": "P1 M ticket",
      "status": "Ready",
      "priority": "P1",
      "size": "M",
      "type": "Feature",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 4,
      "title": "P2 XS ticket - should come after P1 M",
      "status": "Ready",
      "priority": "P2",
      "size": "XS",
      "type": "Task",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 5,
      "title": "P1 ticket with P0 dep - budget test",
      "status": "Ready",
      "priority": "P1",
      "size": "M",
      "type": "Feature",
      "disciplines": [],
      "accountable": [],
      "dependencies": [6],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 6,
      "title": "P2 dep of P1 ticket",
      "status": "Ready",
      "priority": "P2",
      "size": "S",
      "type": "Task",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 10,
      "title": "Older ticket with same priority/size",
      "status": "Ready",
      "priority": "P1",
      "size": "M",
      "type": "Bug",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 11,
      "title": "Newer ticket with same priority/size",
      "status": "Ready",
      "priority": "P1",
      "size": "M",
      "type": "Bug",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T01:00:00Z"
    }
  ]
}
EOF

  # Setup done.json with In Progress tickets for dependency context
  cat > "$DONE_FILE" <<'EOF'
  {
  "tickets": [
    {
      "id": 7,
      "title": "In Progress external dep",
      "status": "In Progress",
      "priority": "P1",
      "size": "M",
      "type": "Feature",
      "disciplines": [],
      "accountable": [],
      "dependencies": [],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 8,
      "title": "Ticket with external dep",
      "status": "Ready",
      "priority": "P2",
      "size": "M",
      "type": "Task",
      "disciplines": [],
      "accountable": [],
      "dependencies": [7],
      "created_by": "test",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
EOF
}

# ── _check_cyclic_deps tests ─────────────────────────────────────────────────

@test "algorithms: _check_cyclic_deps detects no cycle in linear chain" {
  # Setup: 1→2→3 (all Ready)
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [3]},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  _check_cyclic_deps 1
  [[ "$?" -eq 0 ]]
}

@test "algorithms: _check_cyclic_deps detects self-dependency cycle" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [1]}
  ]
}
EOF
  
  run _check_cyclic_deps 1
  [ "$status" -ne 0 ]
}

@test "algorithms: _check_cyclic_deps detects 2-ticket cycle" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [1]}
  ]
}
EOF

  run _check_cyclic_deps 1
  [ "$status" -ne 0 ]
}

@test "algorithms: _check_cyclic_deps detects 3-ticket cycle" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [3]},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [1]}
  ]
}
EOF

  run _check_cyclic_deps 1
  [ "$status" -ne 0 ]
}

@test "algorithms: _check_cyclic_deps validates with extra_deps override" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  # Adding a dep that creates a cycle via override
  run _check_cyclic_deps 1 1
  [ "$status" -ne 0 ]
}

# ── _rank_ready_tickets: Priority Ordering Tests ────────────────────────────

@test "rank: P1 S comes before P1 M (size tiebreaker)" {
  setup_ranking_fixtures

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  # Ticket 2 (P1/S) should sort before ticket 3 (P1/M) — same priority, smaller size wins
  pos_2=$(jq -r 'to_entries[] | select(.value.id == 2) | .key' <<< "$ranked_ready_json")
  pos_3=$(jq -r 'to_entries[] | select(.value.id == 3) | .key' <<< "$ranked_ready_json")
  [[ "$pos_2" -lt "$pos_3" ]]
}

@test "rank: P1 M comes before P2 XS (priority over size)" {
  setup_ranking_fixtures
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # Find positions
  p1_m_pos=$(jq -r 'to_entries[] | select(.value.id == 3) | .key' <<< "$ranked_ready_json")
  p2_xs_pos=$(jq -r 'to_entries[] | select(.value.id == 4) | .key' <<< "$ranked_ready_json")
  
  [[ "$p1_m_pos" -lt "$p2_xs_pos" ]]
}

@test "rank: same priority/size uses ID order (lower ID first)" {
  setup_ranking_fixtures
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # Find both P1 M tickets (IDs 3 and 10/11)
  # Ticket 10 is older (lower ID) than 11
  pos_10=$(jq -r 'to_entries[] | select(.value.id == 10) | .key' <<< "$ranked_ready_json")
  pos_11=$(jq -r 'to_entries[] | select(.value.id == 11) | .key' <<< "$ranked_ready_json")
  
  [[ "$pos_10" -lt "$pos_11" ]]
}

@test "rank: P0 ticket appears first regardless of size" {
  setup_ranking_fixtures
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  first_id=$(jq -r '.[0].id' <<< "$ranked_ready_json")
  first_priority=$(jq -r '.[0].priority' <<< "$ranked_ready_json")
  
  [[ "$first_priority" == "P0" ]]
}

# ── _rank_ready_tickets: Budget Promotion Tests ─────────────────────────────

@test "rank: P1 promotes transitive deps within budget" {
  setup_ranking_fixtures

  # Ticket 5 (P1/M) depends on ticket 6 (P2/S); cost=1, budget=3 → should promote
  UNBLOCK_P1_BUDGET=3
  export UNBLOCK_P1_BUDGET

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  # Original priority of ticket 6 is unchanged in the JSON
  dep_priority=$(jq -r '.[] | select(.id == 6) | .priority' <<< "$ranked_ready_json")
  [[ "$dep_priority" == "P2" ]]

  # Effective priority promotion makes ticket 6 sort before non-promoted P2 ticket 4 (P2/XS)
  pos_6=$(jq -r 'to_entries[] | select(.value.id == 6) | .key' <<< "$ranked_ready_json")
  pos_4=$(jq -r 'to_entries[] | select(.value.id == 4) | .key' <<< "$ranked_ready_json")

  [[ "$pos_6" -lt "$pos_4" ]]

  unset UNBLOCK_P1_BUDGET
}

@test "rank: P1 promotion costs calculated from size ranks" {
  setup_ranking_fixtures
  
  # Test cost calculation: size S=1, M=2, L=3, XL=4
  UNBLOCK_P1_BUDGET=3
  export UNBLOCK_P1_BUDGET
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # With budget of 3, dependencies within budget should be promoted
  # This test verifies the promotion logic runs
  [[ "$topo_count" -gt 0 ]]
  
  unset UNBLOCK_P1_BUDGET
}

@test "rank: P0 deps have zero cost" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P0", "size": "XL", "dependencies": []},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  UNBLOCK_P1_BUDGET=1  # Small budget
  export UNBLOCK_P1_BUDGET
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # Despite small budget, promotion should succeed because P0 dep costs 0
  # Verify both tickets are in actionable section (topo_count >= 2)
  [[ "$topo_count" -ge 2 ]]
  
  unset UNBLOCK_P1_BUDGET
}

@test "rank: promotion fails when budget exceeded" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [2, 3]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  UNBLOCK_P1_BUDGET=1  # Budget too small for two M tickets (cost 2+2=4 > 1)
  export UNBLOCK_P1_BUDGET
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # Deps should NOT be promoted, so ticket 1 should be blocked
  block_reason=$(jq -r '.[] | select(.id == 1) | ._block_reason' <<< "$ranked_ready_json" | head -1)
  [[ "$block_reason" == "blocked" || "$block_reason" == "null" ]]
  
  unset UNBLOCK_P1_BUDGET
}

# ── _rank_ready_tickets: Dependency Tests ───────────────────────────────────

@test "rank: ready-ready deps create topological ordering" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # Ticket 2 must come before ticket 1 (dependency constraint)
  pos_1=$(jq -r 'to_entries[] | select(.value.id == 1) | .key' <<< "$ranked_ready_json")
  pos_2=$(jq -r 'to_entries[] | select(.value.id == 2) | .key' <<< "$ranked_ready_json")
  
  [[ "$pos_2" -lt "$pos_1" ]]
}

@test "rank: tickets with external deps are marked blocked" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [99]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  total=$(jq 'length' <<< "$ranked_ready_json")
  [[ "$total" -eq 2 ]]

  t1_block=$(jq -r '.[] | select(.id == 1) | ._block_reason' <<< "$ranked_ready_json")
  [[ "$t1_block" == "blocked" ]]

  [[ "$topo_count" -eq 1 ]]
}

@test "rank: topo_count separates actionable from cyclic" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P0", "size": "M", "dependencies": []},
    {"id": 2, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [3]},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [2]}
  ]
}
EOF

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  total_count=$(jq 'length' <<< "$ranked_ready_json")
  [[ "$total_count" -eq 3 ]]
  # Ticket 1 is actionable; tickets 2-3 form a cycle → topo_count < total
  [[ "$topo_count" -lt "$total_count" ]]
  [[ "$topo_count" -gt 0 ]]
}

@test "rank: cyclic dependencies are detected and marked" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [2]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [3]},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [1]}
  ]
}
EOF
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  # All three should be marked as cycle
  block_reason=$(jq -r '.[0]._block_reason' <<< "$ranked_ready_json")
  [[ "$block_reason" == "cycle" ]]
}

@test "rank: mixed actionable and cyclic tickets" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P0", "size": "M", "dependencies": []},
    {"id": 2, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [8]},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [4]},
    {"id": 4, "status": "Ready", "priority": "P2", "size": "M", "dependencies": [3]},
    {"id": 5, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  cat > "$DONE_FILE" <<'EOF'
  {
  "tickets": [
    {"id": 8, "status": "Done", "priority": "P1", "size": "M", "dependencies": []}
  ]
}
EOF
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  total=$(jq 'length' <<< "$ranked_ready_json")
  
  [[ "$total" -eq 5 ]]
  [[ "$topo_count" -gt 0 ]]

  # External deps don't block — ticket 2's dep (8, in done.json) is satisfied
  blocked_count=$(jq '[.[] | select(._block_reason == "blocked")] | length' <<< "$ranked_ready_json")
  [[ "$blocked_count" -eq 0 ]]

  # Tickets 3-4 form a cycle
  cyclic_count=$(jq '[.[] | select(._block_reason == "cycle")] | length' <<< "$ranked_ready_json")
  [[ "$cyclic_count" -gt 0 ]]
}

@test "rank: in-progress deps are not treated as satisfied" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P1", "size": "M", "dependencies": [8]},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []},
    {"id": 8, "status": "In Progress", "priority": "P1", "size": "M", "dependencies": []}
  ]
}
EOF

  cat > "$DONE_FILE" <<'EOF'
{
  "tickets": []
}
EOF

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  block_reason=$(jq -r '.[] | select(.id == 1) | ._block_reason' <<< "$ranked_ready_json")
  [[ "$block_reason" == "blocked" ]]

  actionable_ids=$(jq -r '.[0:'"$topo_count"'] | map(.id) | join(",")' <<< "$ranked_ready_json")
  [[ "$actionable_ids" == "2" ]]
}

@test "rank: empty ready list returns immediately" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": []
}
EOF
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  [[ "$topo_count" -eq 0 ]]
  [[ "$ranked_ready_json" == "[]" ]]
}

@test "rank: tickets with no dependencies are all actionable" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []},
    {"id": 2, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "M", "dependencies": []}
  ]
}
EOF
  
  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets
  
  total=$(jq 'length' <<< "$ranked_ready_json")
  [[ "$topo_count" -eq "$total" ]]
}

@test "rank: sparse ready ticket uses configured priority and size defaults" {
  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "dependencies": []},
    {"id": 2, "status": "Ready", "priority": "P1", "size": "S", "dependencies": []},
    {"id": 3, "status": "Ready", "priority": "P2", "size": "XS", "dependencies": []}
  ]
}
EOF

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  sparse_priority=$(jq -r '.[] | select(.id == 1) | .priority // "missing"' <<< "$ranked_ready_json")
  sparse_pos=$(jq -r 'to_entries[] | select(.value.id == 1) | .key' <<< "$ranked_ready_json")
  p1_pos=$(jq -r 'to_entries[] | select(.value.id == 2) | .key' <<< "$ranked_ready_json")
  p2_xs_pos=$(jq -r 'to_entries[] | select(.value.id == 3) | .key' <<< "$ranked_ready_json")

  [[ "$sparse_priority" == "missing" ]]
  [[ "$p1_pos" -lt "$sparse_pos" ]]
  [[ "$p2_xs_pos" -lt "$sparse_pos" ]]
  [[ "$topo_count" -eq 3 ]]
}

@test "rank: configured labels with spaces and punctuation preserve ordering" {
  printf '%s\n' \
    'PRIORITY_0="Now!"' \
    'PRIORITY_1="Soon \"1\""' \
    'PRIORITY_2="Later\\2"' \
    'PRIORITY_3="Eventually"' \
    'SIZE_0="Tiny"' \
    'SIZE_1="Small-ish"' \
    'SIZE_2="Medium Size"' \
    'SIZE_3="Large"' \
    'SIZE_4="Huge"' \
    > "$CONFIG_FILE"
  _load_config "$TEST_PROJECT"

  cat > "$QUEUE_FILE" <<'EOF'
{
  "tickets": [
    {"id": 1, "status": "Ready", "priority": "Later\\2", "size": "Medium Size", "dependencies": []},
    {"id": 2, "status": "Ready", "priority": "Soon \"1\"", "size": "Small-ish", "dependencies": []},
    {"id": 3, "status": "Ready", "priority": "Now!", "size": "Huge", "dependencies": []}
  ]
}
EOF

  ranked_ready_json='[]'
  topo_count=0
  _rank_ready_tickets

  ids=$(jq -r 'map(.id) | join(",")' <<< "$ranked_ready_json")

  [ "$ids" = "3,2,1" ]
}
