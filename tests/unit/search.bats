#!/usr/bin/env bats
# Tests for: atoshell search
#
# Fixture data:
#   queue   — #1 "Fix login bug" (desc: special characters), #2 "Add dark mode"
#             (comment body: "Design spec attached"), #3 "Update API docs"
#   backlog — #4 "Migrate to Postgres"
#   done    — #5 "Initial project setup"

load '../helpers/setup'

# ── 1. Basic title matching ───────────────────────────────────────────────────
@test "search: exit code 0 on a match" {
  run atoshell search "Fix login bug"
  [ "$status" -eq 0 ]
}
@test "search: title exact match returns the ticket" {
  run atoshell search "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: title partial match returns the ticket" {
  run atoshell search "dark mode"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "search: title match is case-insensitive" {
  run atoshell search "fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: output includes ticket ID" {
  run atoshell search "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "search: output includes priority" {
  run atoshell search "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"P1"* ]]
}

# ── 2. Description and comment matching ───────────────────────────────────────
@test "search: matches ticket by description content" {
  run atoshell search "special characters"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: description match is case-insensitive" {
  run atoshell search "SPECIAL CHARACTERS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: matches ticket by comment body" {
  run atoshell search "Design spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "search: comment match is case-insensitive" {
  run atoshell search "design spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "search: matches ticket by discipline" {
  tmp="$BATS_TEST_TMPDIR/queue-with-discipline.json"
  jq '(.tickets[] | select(.id==1) | .disciplines) = ["Backend"]' .atoshell/queue.json > "$tmp"
  mv "$tmp" .atoshell/queue.json
  run atoshell search "Backend"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: matches ticket by priority label" {
  run atoshell search "P0"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initial project setup"* ]]
}
@test "search: matches ticket by type" {
  printf '{"tickets":[
    {"id":1,"title":"Defect-classified work","status":"Ready","priority":"P1","size":"S","type":"Bug","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell search "bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Defect-classified work"* ]]
}
@test "search: matches ticket by size label" {
  printf '{"tickets":[
    {"id":1,"title":"Large estimate work","status":"Ready","priority":"P1","size":"XL","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell search "xl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Large estimate work"* ]]
}
@test "search: matches ticket by status label" {
  printf '{"tickets":[
    {"id":1,"title":"Completed work","status":"Done","priority":"P1","size":"S","dependencies":[],"comments":[]}
  ]}' > .atoshell/done.json
  run atoshell search "done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Completed work"* ]]
}
@test "search: matches ticket by accountable user" {
  printf '{"tickets":[
    {"id":1,"title":"Assigned item","status":"Ready","priority":"P1","size":"S","accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell search "lyra"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Assigned item"* ]]
}
@test "search: human output keeps in-progress matches ahead of ready and backlog matches" {
  printf '{"tickets":[
    {"id":1,"title":"shared ready","status":"Ready","priority":"P1","size":"S","dependencies":[],"comments":[]},
    {"id":2,"title":"shared working","status":"In Progress","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  printf '{"tickets":[
    {"id":3,"title":"shared backlog","status":"Backlog","priority":"P0","size":"XS","dependencies":[],"comments":[]}
  ]}' > .atoshell/backlog.json
  printf '{"tickets":[]}' > .atoshell/done.json
  run atoshell search shared
  [ "$status" -eq 0 ]
  working_line=$(printf '%s\n' "$output" | grep -n 'shared working' | cut -d: -f1)
  ready_line=$(printf '%s\n' "$output" | grep -n 'shared ready' | cut -d: -f1)
  backlog_line=$(printf '%s\n' "$output" | grep -n 'shared backlog' | cut -d: -f1)
  [ "$working_line" -lt "$ready_line" ]
  [ "$ready_line" -lt "$backlog_line" ]
}
@test "search: missing priority and size display configured defaults" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'PRIORITY_0="Critical"' \
    'PRIORITY_1="High"' \
    'PRIORITY_2="Medium"' \
    'PRIORITY_3="Low"' \
    'SIZE_0="One"' \
    'SIZE_1="Two"' \
    'SIZE_2="Three"' \
    'SIZE_3="Five"' \
    'SIZE_4="Eight"' \
    'USERNAME="testuser"' \
    > .atoshell/config.env
  printf '{"tickets":[
    {"id":1,"title":"Missing search defaults","status":"Ready","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json

  run atoshell search "Missing search defaults"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Medium"*"Three"*"Missing search defaults"* ]]
  [[ "$output" != *"?"*"Missing search defaults"* ]]
}

# ── 3. Cross-file matching ────────────────────────────────────────────────────
@test "search: finds ticket in backlog.json" {
  run atoshell search "Migrate to Postgres"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrate to Postgres"* ]]
}
@test "search: finds ticket in done.json" {
  run atoshell search "Initial project setup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initial project setup"* ]]
}
@test "search: returns tickets from multiple files in one query" {
  printf '{"tickets":[
    {"id":1,"title":"Queue match","description":"shared-token","status":"Ready","priority":"P1","size":"S","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  printf '{"tickets":[
    {"id":4,"title":"Backlog match","description":"shared-token","status":"Backlog","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/backlog.json
  printf '{"tickets":[
    {"id":5,"title":"Done match","description":"shared-token","status":"Done","priority":"P0","size":"S","dependencies":[],"comments":[]}
  ]}' > .atoshell/done.json

  run atoshell search "shared-token"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Queue match"* ]]
  [[ "$output" == *"Backlog match"* ]]
  [[ "$output" == *"Done match"* ]]
}

# ── 4. No results ─────────────────────────────────────────────────────────────
@test "search: exit code 0 when no results" {
  run atoshell search "xyzzy_no_such_thing"
  [ "$status" -eq 0 ]
}
@test "search: 'No results' message when nothing matches" {
  run atoshell search "xyzzy_no_such_thing"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No results"* ]]
}
@test "search: no ticket lines when nothing matches" {
  run atoshell search "xyzzy_no_such_thing"
  [ "$status" -eq 0 ]
  [[ "$output" != *"#"* ]]
}

# ── 5. Multiple matches ───────────────────────────────────────────────────────
@test "search: returns multiple tickets when query matches several" {
  run atoshell search "login"
  [ "$status" -eq 0 ]
  # queue.json has at least one match; output should include the ticket
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: does not include unmatched tickets" {
  run atoshell search "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Add dark mode"* ]]
}

# ── 6. --json output ──────────────────────────────────────────────────────────
@test "search --json: exit code 0" {
  run atoshell search "Fix login" --json
  [ "$status" -eq 0 ]
}
@test "search --json: output is valid JSON array" {
  run atoshell search "Fix login" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | type == "array"' > /dev/null
}
@test "search --json: matched ticket is in the array" {
  run atoshell search "Fix login" --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '[.[] | select(.id == 1)] | length')
  [ "$count" -eq 1 ]
}
@test "search --json: empty array when no match" {
  run atoshell search "xyzzy_no_such_thing" --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 0 ]
}
@test "search --json: backlog ticket appears in results" {
  run atoshell search "Postgres" --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '[.[] | select(.id == 4)] | length')
  [ "$count" -eq 1 ]
}
@test "search -j: short flag works identically to --json" {
  run atoshell search "Fix login" -j
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | type == "array"' > /dev/null
}

# ── 7. Error cases ────────────────────────────────────────────────────────────
@test "search: no query exits non-zero" {
  run atoshell search
  [ "$status" -ne 0 ]
}
@test "search: no query prints usage message" {
  run atoshell search
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"search"* ]]
}

# ── 8. Command aliases ────────────────────────────────────────────────────────
@test "search: find alias works" {
  run atoshell find "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: hiku alias works" {
  run atoshell hiku "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "search: crawl alias works" {
  run atoshell crawl "Fix login bug"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "search --help: exits 0" {
  run atoshell search --help
  [ "$status" -eq 0 ]
}
@test "search --help: output contains Usage" {
  run atoshell search --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
