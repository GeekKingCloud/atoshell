#!/usr/bin/env bats
# take.bats — Tests for take.sh
#
# Fixtures:
#   queue.json   : #1 Ready/P1, #2 In Progress/P2, #3 Ready/P3
#   backlog.json : #4 Backlog/P2
#   done.json : #5 Done/P0
#
# Note: bats runs with stdin non-TTY, so take.sh assigns to "[agent]" (not "testuser").

load '../helpers/setup'

# ── 1. Basic take by ID ───────────────────────────────────────────────────────
@test "take: exits 0 on clean take" {
  run atoshell take 1
  [ "$status" -eq 0 ]
}
@test "take: [OK] line in output" {
  run atoshell take 1
  [[ "$output" == *"[OK]"* ]]
}
@test "take: adds agent to accountable (non-TTY mode)" {
  run atoshell take 1
  result=$(jq -r '
    .tickets[] | select(.id == 1) | .accountable | any(. == "[agent]")
  ' .atoshell/queue.json)
  [ "$result" = "true" ]
}
@test "take: sets status to In Progress from Ready" {
  run atoshell take 1
  status_val=$(jq -r '.tickets[] | select(.id == 1) | .status' .atoshell/queue.json)
  [ "$status_val" = "In Progress" ]
}
@test "take: sets status to In Progress from Backlog (cross-file move)" {
  run atoshell take 4
  [ "$status" -eq 0 ]
  status_val=$(jq -r '.tickets[] | select(.id == 4) | .status' .atoshell/queue.json)
  [ "$status_val" = "In Progress" ]
}
@test "take: ticket removed from backlog.json after Backlog take" {
  run atoshell take 4
  count=$(jq '.tickets | length' .atoshell/backlog.json)
  [ "$count" -eq 0 ]
}
@test "take: idempotent accountable — does not duplicate agent" {
  run atoshell take 1
  run atoshell take 1
  count=$(jq '
    .tickets[] | select(.id == 1) | .accountable | map(select(. == "[agent]")) | length
  ' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

# ── 2. Take next ──────────────────────────────────────────────────────────────
@test "take next: exits 0 when ready ticket available" {
  run atoshell take next
  [ "$status" -eq 0 ]
}
@test "take next: assigns agent to highest-priority ready ticket (#1)" {
  run atoshell take next
  result=$(jq -r '
    .tickets[] | select(.id == 1) | .accountable | any(. == "[agent]")
  ' .atoshell/queue.json)
  [ "$result" = "true" ]
}
@test "take next: moves selected ticket to In Progress" {
  run atoshell take next
  status_val=$(jq -r '.tickets[] | select(.id == 1) | .status' .atoshell/queue.json)
  [ "$status_val" = "In Progress" ]
}
@test "take next: exits non-zero when no ready tickets" {
  # Move both ready tickets to In Progress so no Ready tickets remain
  jq '(.tickets[] | select(.id == 1)).status = "In Progress"' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  jq '(.tickets[] | select(.id == 3)).status = "In Progress"' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q2.json" && mv "$BATS_TEST_TMPDIR/q2.json" .atoshell/queue.json
  run atoshell take next
  [ "$status" -ne 0 ]
}

# ── 3. Status warnings ────────────────────────────────────────────────────────
@test "take: warns when already In Progress" {
  run atoshell take 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
  [[ "$output" == *"In Progress"* ]]
}
@test "take: still assigns when already In Progress" {
  run atoshell take 2
  result=$(jq -r '
    .tickets[] | select(.id == 2) | .accountable | any(. == "[agent]")
  ' .atoshell/queue.json)
  [ "$result" = "true" ]
}
@test "take: errors on Done ticket without --force" {
  run atoshell take 5
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error:"* ]]
}
@test "take: assigned-to warning strips terminal control sequences" {
  jq '.tickets[0].accountable = ["other\u001b]52;c;SGVsbG8=\u0007user"]' \
    .atoshell/queue.json > .atoshell/queue.tmp
  mv .atoshell/queue.tmp .atoshell/queue.json

  run atoshell take 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"otheruser"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}
@test "take: does not modify ticket on Done guard failure" {
  accountable_before=$(jq -c '.tickets[] | select(.id == 5) | .accountable' .atoshell/done.json)
  run atoshell take 5
  accountable_after=$(jq -c '.tickets[] | select(.id == 5) | .accountable' .atoshell/done.json)
  [ "$accountable_before" = "$accountable_after" ]
}
@test "take: --force overrides Done guard, exits 0" {
  run atoshell take 5 --force
  [ "$status" -eq 0 ]
}
@test "take: --force assigns agent on Done ticket" {
  run atoshell take 5 --force
  result=$(jq -r '
    .tickets[] | select(.id == 5) | .accountable | any(. == "[agent]")
  ' .atoshell/done.json)
  [ "$result" = "true" ]
}
@test "take: --force does not change status of Done ticket" {
  run atoshell take 5 --force
  status_val=$(jq -r '.tickets[] | select(.id == 5) | .status' .atoshell/done.json)
  [ "$status_val" = "Done" ]
}
@test "take: --force warns about done status" {
  run atoshell take 5 --force
  [[ "$output" == *"[WARN]"* ]]
}
@test "take: --force on done+assigned ticket still warns about done, not about assignee" {
  jq '(.tickets[] | select(.id == 5)).accountable = ["lyra"]' \
    .atoshell/done.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/done.json
  run atoshell take 5 --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
  [[ "$output" != *"assigned to"* ]]
}

# ── 4. Accountable warnings ───────────────────────────────────────────────────
@test "take: warns when ticket is assigned to others (not agent)" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"[WARN]"* ]]
  [[ "$output" == *"lyra"* ]]
}
@test "take: warns 'also assigned to' when shared with agent already present" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["[agent]","lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"also assigned to"* ]]
  [[ "$output" == *"lyra"* ]]
}
@test "take: no accountable warning when ticket is unassigned" {
  run atoshell take 1
  [[ "$output" != *"assigned to"* ]]
}
@test "take: --force suppresses accountable warning" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1 --force
  [ "$status" -eq 0 ]
  [[ "$output" != *"assigned to"* ]]
}

# ── 5. JSON output ────────────────────────────────────────────────────────────
@test "take: --json exits 0" {
  run atoshell take 1 --json
  [ "$status" -eq 0 ]
}
@test "take: --json outputs valid JSON" {
  run atoshell take 1 --json
  echo "$output" | jq . > /dev/null
}
@test "take: --json output has status In Progress" {
  run atoshell take 1 --json
  status_val=$(echo "$output" | jq -r '.status')
  [ "$status_val" = "In Progress" ]
}
@test "take: --json output has agent in accountable" {
  run atoshell take 1 --json
  result=$(echo "$output" | jq -r '.accountable | any(. == "[agent]")')
  [ "$result" = "true" ]
}
@test "take next --json: outputs valid JSON" {
  run atoshell take next --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null
}
@test "take next: skips ready tickets blocked by in-progress deps" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ready","status":"Ready","priority":"P0","size":"S",
     "accountable":[],"dependencies":[8],"comments":[]},
    {"id":2,"title":"Actually ready","status":"Ready","priority":"P1","size":"S",
     "accountable":[],"dependencies":[],"comments":[]},
    {"id":8,"title":"Active dep","status":"In Progress","priority":"P1","size":"M",
     "accountable":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress" and (.accountable | any(. == "[agent]"))) | .id' .atoshell/queue.json | head -1)
  [ "$taken_id" -eq 2 ]
}

# ── 5b. JSON assignment errors ────────────────────────────────────────────────
@test "take: --json exits 1 when ticket assigned to others" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1 --json
  [ "$status" -eq 1 ]
}
@test "take: --json TICKET_ALREADY_ASSIGNED error when assigned to others" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1 --json
  err=$(echo "$output" | jq -r '.error')
  [ "$err" = "TICKET_ALREADY_ASSIGNED" ]
}
@test "take: --json TICKET_ALSO_ASSIGNED error when shared with others" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["[agent]","lyra"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1 --json
  [ "$status" -eq 1 ]
  err=$(echo "$output" | jq -r '.error')
  [ "$err" = "TICKET_ALSO_ASSIGNED" ]
}

# ── 5c. --as flag ────────────────────────────────────────────────────────────
@test "take: --as assigns named agent instead of [agent]" {
  run atoshell take 1 --as agent-1
  [ "$status" -eq 0 ]
  result=$(jq -r '.tickets[] | select(.id == 1) | .accountable | any(. == "agent-1")' .atoshell/queue.json)
  [ "$result" = "true" ]
}
@test "take: --as does not add [agent] when name is specified" {
  run atoshell take 1 --as agent-1
  [ "$status" -eq 0 ]
  result=$(jq -r '.tickets[] | select(.id == 1) | .accountable | any(. == "[agent]")' .atoshell/queue.json)
  [ "$result" = "false" ]
}
@test "take: --as works with next" {
  run atoshell take next --as agent-2
  [ "$status" -eq 0 ]
  result=$(jq -r '[.tickets[] | select(.accountable | any(. == "agent-2"))] | length' .atoshell/queue.json)
  [ "$result" -ge 1 ]
}
@test "take: --as does not duplicate if named agent already accountable" {
  jq '(.tickets[] | select(.id == 1)).accountable = ["agent-1"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell take 1 --as agent-1
  [ "$status" -eq 0 ]
  count=$(jq -r '.tickets[] | select(.id == 1) | [.accountable[] | select(. == "agent-1")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "take: --as numeric shorthand normalizes to agent-N" {
  run atoshell take 1 --as 10
  [ "$status" -eq 0 ]
  result=$(jq -r '.tickets[] | select(.id == 1) | .accountable | any(. == "agent-10")' .atoshell/queue.json)
  [ "$result" = "true" ]
}
@test "take: --as stamps updated_by to named agent" {
  run atoshell take 1 --as agent-1
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id == 1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "agent-1" ]
}
@test "take: --as without value exits cleanly" {
  run atoshell take 1 --as
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as requires a value"* ]]
}
@test "take: --as rejects arbitrary names" {
  run atoshell take 1 --as alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}

# ── 6. Error cases ────────────────────────────────────────────────────────────
@test "take: no arguments defaults to next" {
  run atoshell take
  [ "$status" -eq 0 ]
  status_val=$(jq -r '.tickets[] | select(.id == 1) | .status' .atoshell/queue.json)
  [ "$status_val" = "In Progress" ]
}
@test "take: exits non-zero for non-numeric ID" {
  run atoshell take abc
  [ "$status" -ne 0 ]
}
@test "take: exits non-zero for unknown ID" {
  run atoshell take 999
  [ "$status" -ne 0 ]
}
@test "take: --force with next exits non-zero" {
  run atoshell take next --force
  [ "$status" -ne 0 ]
}
@test "take: --force with next error mentions next" {
  run atoshell take next --force
  [[ "$output" == *"Error:"* ]]
}

# ── 7. Aliases ────────────────────────────────────────────────────────────────
@test "take alias: toru exits 0" {
  run atoshell toru 1
  [ "$status" -eq 0 ]
}
@test "take alias: snatch exits 0" {
  run atoshell snatch 1
  [ "$status" -eq 0 ]
}
@test "take alias: grab exits 0" {
  run atoshell grab 1
  [ "$status" -eq 0 ]
}

# ── 8. take next filter flags ─────────────────────────────────────────────────
@test "take next --type: takes ticket matching type, skips non-matching" {
  printf '{"tickets":[
    {"id":1,"title":"Bug ticket","status":"Ready","priority":"P1","size":"S","type":"Bug","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"Feature ticket","status":"Ready","priority":"P1","size":"S","type":"Feature","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --type Feature
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next --type: numeric shorthand resolves configured type" {
  printf '{"tickets":[
    {"id":1,"title":"Bug ticket","status":"Ready","priority":"P1","size":"S","type":"Bug","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"Feature ticket","status":"Ready","priority":"P1","size":"S","type":"Feature","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --type 1
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next --priority: takes ticket matching priority, skips others" {
  printf '{"tickets":[
    {"id":1,"title":"P0 ticket","status":"Ready","priority":"P0","size":"S","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"P3 ticket","status":"Ready","priority":"P3","size":"S","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --priority P3
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next --priority: numeric shorthand resolves configured priority" {
  printf '{"tickets":[
    {"id":1,"title":"P0 ticket","status":"Ready","priority":"P0","size":"S","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"P3 ticket","status":"Ready","priority":"P3","size":"S","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --priority 3
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next --size: takes ticket matching size, skips others" {
  printf '{"tickets":[
    {"id":1,"title":"Small ticket","status":"Ready","priority":"P1","size":"XS","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"Large ticket","status":"Ready","priority":"P1","size":"XL","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --size XL
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next --size: numeric shorthand resolves configured size" {
  printf '{"tickets":[
    {"id":1,"title":"Small ticket","status":"Ready","priority":"P1","size":"XS","disciplines":[],"dependencies":[],"comments":[]},
    {"id":2,"title":"Large ticket","status":"Ready","priority":"P1","size":"XL","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --size 4
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next: sparse Ready ticket can be selected" {
  printf '{"tickets":[
    {"id":1,"title":"Sparse ready","status":"Ready","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 1 ]
}
@test "take next --disciplines: takes ticket matching discipline, skips others" {
  printf '{"tickets":[
    {"id":1,"title":"Frontend ticket","status":"Ready","priority":"P1","size":"S","disciplines":["Frontend"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Backend ticket","status":"Ready","priority":"P1","size":"S","disciplines":["Backend"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --disciplines Backend
  [ "$status" -eq 0 ]
  taken_id=$(jq -r '.tickets[] | select(.status == "In Progress") | .id' .atoshell/queue.json)
  [ "$taken_id" -eq 2 ]
}
@test "take next: exits non-zero when filter matches no ready tickets" {
  printf '{"tickets":[
    {"id":1,"title":"Feature ticket","status":"Ready","priority":"P1","size":"S","type":"Feature","disciplines":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell take next --type Bug
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error:"* ]]
}

# ── 9. Structured errors (--json mode) ───────────────────────────────────────
@test "take --json: ticket not found emits TICKET_NOT_FOUND error code" {
  run_split atoshell take 999 --json
  assert_json_error_split "TICKET_NOT_FOUND"
}
@test "take --json: ticket not found error is valid JSON" {
  run_split atoshell take 999 --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "TICKET_NOT_FOUND" ]
}
@test "take --json: ticket not found error includes id field" {
  run_split atoshell take 999 --json
  [ "$status" -ne 0 ]
  id_field=$(jq -r '.id' "$BATS_TEST_TMPDIR/stderr")
  [ "$id_field" = "999" ]
}
@test "take next --json: no ready tickets emits NO_READY_TICKETS error code" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run_split atoshell take next --json
  assert_json_error_split "NO_READY_TICKETS"
}
@test "take next --json: no ready tickets error is valid JSON" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run_split atoshell take next --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "NO_READY_TICKETS" ]
}
@test "take --json: non-numeric ID emits INVALID_TICKET_ID error code" {
  run_split atoshell take abc --json
  assert_json_error_split "INVALID_TICKET_ID"
}
@test "take --json: closed ticket emits TICKET_CLOSED error code" {
  run_split atoshell take 5 --json
  assert_json_error_split "TICKET_CLOSED"
}
@test "take --json: closed ticket error is valid JSON with status field" {
  run_split atoshell take 5 --json
  [ "$status" -ne 0 ]
  st=$(jq -r '.status' "$BATS_TEST_TMPDIR/stderr")
  [ -n "$st" ]
}
# ── --help flag ──────────────────────────────────────────────────────────────
@test "take --help: exits 0" {
  run atoshell take --help
  [ "$status" -eq 0 ]
}
@test "take --help: output contains Usage" {
  run atoshell take --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "take --help: output lists fixed disciplines" {
  run atoshell take --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid disciplines (fixed)"* ]]
  [[ "$output" == *"Frontend, Backend"* ]]
  [[ "$output" == *"matches your capability area"* ]]
}
