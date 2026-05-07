#!/usr/bin/env bats
# Tests for: atoshell list
#
# Fixture IDs:
#   queue   — #1 P1/S/Ready "Fix login bug", #2 P2/M/In Progress "Add dark mode",
#             #3 P3/XS/Ready "Update API docs"
#   backlog — #4 P2/XL/Backlog "Migrate to Postgres"
#   done    — #5 P0/S/Done "Initial project setup"

load '../helpers/setup'

# ── 1. Default scope (queue) ──────────────────────────────────────────────────
@test "list: exit code 0 with no args" {
  run atoshell list
  [ "$status" -eq 0 ]
}
@test "list: shows queue tickets by default" {
  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" == *"Add dark mode"* ]]
  [[ "$output" == *"Update API docs"* ]]
}
@test "list: default human output shows queue section counts" {
  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" == *"-- Active (1)"* ]]
  [[ "$output" == *"-- Ready (2)"* ]]
}
@test "list: shows ticket IDs" {
  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "list: does not show backlog tickets by default" {
  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" != *"Migrate to Postgres"* ]]
}
@test "list: does not show done tickets by default" {
  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" != *"Initial project setup"* ]]
}
@test "list queue: explicit queue scope matches default" {
  run atoshell list queue
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list q: short queue alias works" {
  run atoshell list q
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list: --accountable matches named agents" {
  jq '(.tickets[] | select(.id==1)).accountable = ["agent-10"]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json" && mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json
  run atoshell list --accountable agent-10
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}

# ── 2. Scope keywords ─────────────────────────────────────────────────────────
@test "list backlog: shows backlog tickets" {
  run atoshell list backlog
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrate to Postgres"* ]]
}
@test "list bl: short backlog alias works" {
  run atoshell list bl
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrate to Postgres"* ]]
}
@test "list done: shows multiple Done tickets when present" {
  run atoshell list done
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initial project setup"* ]]
}
@test "list done: shows only Done-status tickets" {
  printf '{"tickets":[
    {"id":5,"title":"Done ticket","status":"Done","priority":"P0","size":"S","dependencies":[],"comments":[]},
    {"id":6,"title":"Another done ticket","status":"Done","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/done.json
  run atoshell list done
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done ticket"* ]]
  [[ "$output" == *"Another done ticket"* ]]
}
@test "list backlog: does not show queue tickets" {
  run atoshell list backlog
  [ "$status" -eq 0 ]
  [[ "$output" != *"Fix login bug"* ]]
}
@test "list ready: shows only Ready tickets" {
  run atoshell list ready
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" != *"Add dark mode"* ]]
}
@test "list rd: short ready alias works" {
  run atoshell list rd
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list in-progress: shows only In Progress tickets" {
  run atoshell list in-progress
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
  [[ "$output" != *"Fix login bug"* ]]
}
@test "list ip: short in-progress alias works" {
  run atoshell list ip
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "list in-review: removed scope exits non-zero" {
  run atoshell list in-review
  [ "$status" -ne 0 ]
}
@test "list ir: removed alias exits non-zero" {
  run atoshell list ir
  [ "$status" -ne 0 ]
}
@test "list archive: removed scope exits non-zero" {
  run atoshell list archive
  [ "$status" -ne 0 ]
}
@test "list ar: removed alias exits non-zero" {
  run atoshell list ar
  [ "$status" -ne 0 ]
}

# ── 3. --status filter ────────────────────────────────────────────────────────
@test "list --status: shows matching ticket" {
  run atoshell list --status "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "list --status: human count matches rendered non-ready section" {
  run atoshell list --status "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-- In Progress (1)"* ]]
  [[ "$output" != *"-- Ready ("* ]]
}
@test "list --status: hides non-matching tickets" {
  run atoshell list --status "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Fix login bug"* ]]
}
@test "list --status: filter is case-insensitive" {
  run atoshell list --status "in progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}

# ── 4. --priority filter ──────────────────────────────────────────────────────
@test "list --priority: shows matching P1 ticket" {
  run atoshell list --priority P1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list --priority: human count matches rendered ready section" {
  run atoshell list --priority P1
  [ "$status" -eq 0 ]
  [[ "$output" == *"-- Ready (1)"* ]]
  [[ "$output" != *"Add dark mode"* ]]
}
@test "list --priority: hides non-matching tickets" {
  run atoshell list --priority P1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Add dark mode"* ]]
}
@test "list -p: short priority flag works" {
  run atoshell list -p P1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list --priority: numeric shorthand resolves configured priority" {
  run atoshell list --priority 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" != *"Add dark mode"* ]]
}

# ── 5. --size filter ──────────────────────────────────────────────────────────
@test "list --size: shows matching S ticket" {
  run atoshell list --size S
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list --size: hides non-matching tickets" {
  run atoshell list --size S
  [ "$status" -eq 0 ]
  [[ "$output" != *"Add dark mode"* ]]
}
@test "list -s: short size flag works" {
  run atoshell list -s M
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "list --size: numeric shorthand resolves configured size" {
  run atoshell list --size 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" != *"Add dark mode"* ]]
}

# ── 6. --type filter ──────────────────────────────────────────────────────────
@test "list --type: shows only tickets of matching type" {
  printf '{"tickets":[
    {"id":1,"title":"Bug ticket","status":"Ready","priority":"P1","size":"S",
     "type":"Bug","dependencies":[],"comments":[]},
    {"id":2,"title":"Feature ticket","status":"Ready","priority":"P2","size":"M",
     "type":"Feature","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --type Bug
  [ "$status" -eq 0 ]
  [[ "$output" == *"Bug ticket"* ]]
  [[ "$output" != *"Feature ticket"* ]]
}
@test "list -t: short type flag works" {
  printf '{"tickets":[
    {"id":1,"title":"Bug ticket","status":"Ready","priority":"P1","size":"S",
     "type":"Bug","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list -t Bug
  [ "$status" -eq 0 ]
  [[ "$output" == *"Bug ticket"* ]]
}
@test "list --type: numeric shorthand resolves configured type" {
  printf '{"tickets":[
    {"id":1,"title":"Bug ticket","status":"Ready","priority":"P1","size":"S",
     "type":"Bug","dependencies":[],"comments":[]},
    {"id":2,"title":"Feature ticket","status":"Ready","priority":"P2","size":"M",
     "type":"Feature","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --type 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"Bug ticket"* ]]
  [[ "$output" != *"Feature ticket"* ]]
}
@test "list: human output strips terminal control sequences from stored title" {
  jq '.tickets[0].title = "Danger \u001b[?25lTitle \u001b]8;;https://example.test\u001b\\link\u001b]8;;\u001b\\Done"' \
    .atoshell/queue.json > .atoshell/queue.tmp
  mv .atoshell/queue.tmp .atoshell/queue.json

  run atoshell list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Danger Title linkDone"* ]]
  [[ "$output" != *$'\e'* ]]
}

# ── 7. --accountable filter ───────────────────────────────────────────────────
@test "list --assign: shows only accountable tickets" {
  printf '{"tickets":[
    {"id":1,"title":"My ticket","status":"Ready","priority":"P1","size":"S",
     "accountable":["testuser"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Their ticket","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --assign testuser
  [ "$status" -eq 0 ]
  [[ "$output" == *"My ticket"* ]]
  [[ "$output" != *"Their ticket"* ]]
}

# ── 8. --json output ──────────────────────────────────────────────────────────
@test "list --json: exit code 0" {
  run atoshell list --json
  [ "$status" -eq 0 ]
}
@test "list --json: output is valid JSON array" {
  run atoshell list --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | type == "array"' > /dev/null
}
@test "list --json: contains queue tickets" {
  run atoshell list --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '[.[] | select(.id == 1)] | length')
  [ "$count" -eq 1 ]
}
@test "list --json: with --priority filter applied" {
  run atoshell list --json --priority P1
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  id=$(echo "$output" | jq '.[0].id')
  [ "$id" -eq 1 ]
}
@test "list --json: custom labels preserve ranking and filtering" {
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
    > .atoshell/config.env
  cat > .atoshell/queue.json <<'EOF'
{
  "tickets": [
    {"id": 1, "title": "Later ticket", "status": "Ready", "priority": "Later\\2", "size": "Medium Size", "type": "Task", "dependencies": [], "comments": []},
    {"id": 2, "title": "Soon ticket", "status": "Ready", "priority": "Soon \"1\"", "size": "Small-ish", "type": "Task", "dependencies": [], "comments": []},
    {"id": 3, "title": "Now ticket", "status": "Ready", "priority": "Now!", "size": "Huge", "type": "Task", "dependencies": [], "comments": []}
  ]
}
EOF

  run atoshell list --json --priority 'Now!'
  [ "$status" -eq 0 ]
  ids=$(echo "$output" | jq -r 'map(.id) | join(",")')
  [ "$ids" = "3" ]

  run atoshell list --json
  [ "$status" -eq 0 ]
  ids=$(echo "$output" | jq -r 'map(.id) | join(",")')
  [ "$ids" = "3,2,1" ]
}
@test "list --json: large queue does not exceed Windows argument limits" {
  {
    printf '{"tickets":[{"id":1,"title":"Large ticket","description":"'
    for _ in {1..40000}; do printf 'x'; done
    printf '","status":"Ready","priority":"P1","size":"S","type":"Task","dependencies":[],"comments":[]}]}'
  } > .atoshell/queue.json

  run atoshell list --json

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.[0].title')" = "Large ticket" ]
}
@test "list: human large queue does not exceed Windows argument limits" {
  {
    printf '{"tickets":[{"id":1,"title":"Large ticket","description":"'
    for _ in {1..40000}; do printf 'x'; done
    printf '","status":"Ready","priority":"P1","size":"S","type":"Task","dependencies":[],"comments":[]}]}'
  } > .atoshell/queue.json

  run atoshell list

  [ "$status" -eq 0 ]
  [[ "$output" == *"Large ticket"* ]]
}
@test "list backlog --json: contains backlog tickets" {
  run atoshell list backlog --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '[.[] | select(.id == 4)] | length')
  [ "$count" -eq 1 ]
}
@test "list -j: short flag works" {
  run atoshell list -j
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | type == "array"' > /dev/null
}

# ── 9. Empty results ──────────────────────────────────────────────────────────
@test "list: exit code 0 when queue is empty" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run atoshell list
  [ "$status" -eq 0 ]
}
@test "list --json: empty array when no tickets match filter" {
  run atoshell list --json --priority P0
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 0 ]
}

# ── 10. Short flag aliases ────────────────────────────────────────────────────
@test "list -S: short flag filters by status" {
  run atoshell list -S "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
  [[ "$output" != *"Fix login bug"* ]]
}

# ── 11. Command aliases ───────────────────────────────────────────────────────
@test "list: rekki alias works" {
  run atoshell rekki
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "list: draw alias works" {
  run atoshell draw
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}

# ── 12. --mine / -M ───────────────────────────────────────────────────────────
@test "list --mine: shows only current user's tickets" {
  printf '{"tickets":[
    {"id":1,"title":"My ticket","status":"Ready","priority":"P1","size":"S",
     "accountable":["testuser"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Their ticket","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --mine
  [ "$status" -eq 0 ]
  [[ "$output" == *"My ticket"* ]]
  [[ "$output" != *"Their ticket"* ]]
}
@test "list -M: short flag works" {
  printf '{"tickets":[
    {"id":1,"title":"My ticket","status":"Ready","priority":"P1","size":"S",
     "accountable":["testuser"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Their ticket","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list -M
  [ "$status" -eq 0 ]
  [[ "$output" == *"My ticket"* ]]
  [[ "$output" != *"Their ticket"* ]]
}

# ── 13. --agent / -A filter ───────────────────────────────────────────────────
@test "list --agent: shows only agent-assigned tickets" {
  printf '{"tickets":[
    {"id":1,"title":"Agent task","status":"Ready","priority":"P1","size":"S",
     "accountable":["[agent]"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Human task","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --agent
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent task"* ]]
  [[ "$output" != *"Human task"* ]]
}
@test "list -A: short flag filters agent tickets" {
  printf '{"tickets":[
    {"id":1,"title":"Agent task","status":"Ready","priority":"P1","size":"S",
     "accountable":["[agent]"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Human task","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list -A
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent task"* ]]
  [[ "$output" != *"Human task"* ]]
}
@test "list --agent --json: returns only agent tickets as array" {
  printf '{"tickets":[
    {"id":1,"title":"Agent task","status":"Ready","priority":"P1","size":"S",
     "accountable":["[agent]"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Human task","status":"Ready","priority":"P2","size":"M",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --agent --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  id=$(echo "$output" | jq '.[0].id')
  [ "$id" -eq 1 ]
}

# ── 14. Ready topo-sort in list output ────────────────────────────────────────
@test "list: blocker appears before blocked ticket in Ready output" {
  printf '{
    "tickets": [
      {"id":10,"title":"A needs B","status":"Ready","priority":"P1","size":"S","dependencies":[11],"comments":[]},
      {"id":11,"title":"B blocker","status":"Ready","priority":"P2","size":"S","dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell list --json
  [ "$status" -eq 0 ]
  b_idx=$(echo "$output" | jq 'to_entries[] | select(.value.id==11) | .key')
  a_idx=$(echo "$output" | jq 'to_entries[] | select(.value.id==10) | .key')
  [ "$b_idx" -lt "$a_idx" ]
}
@test "list --json: externally-blocked ticket still appears (not filtered)" {
  printf '{
    "tickets": [
      {"id":1,"title":"Fix login bug","status":"Ready","priority":"P1","size":"S","dependencies":[4],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell list --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
}
@test "list: honors configured priority order when labels are renamed" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'PRIORITY_0="Critical"' \
    'PRIORITY_1="High"' \
    'PRIORITY_2="Medium"' \
    'PRIORITY_3="Low"' \
    'USERNAME="testuser"' \
    > .atoshell/config.env
  printf '{"tickets":[
    {"id":1,"title":"High priority","status":"Ready","priority":"High","size":"S","dependencies":[],"comments":[]},
    {"id":2,"title":"Critical priority","status":"Ready","priority":"Critical","size":"L","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list --json
  [ "$status" -eq 0 ]
  first_id=$(echo "$output" | jq '.[0].id')
  [ "$first_id" -eq 2 ]
}
@test "list: missing priority and size display configured defaults" {
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
    {"id":1,"title":"Missing defaults","status":"In Progress","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json

  run atoshell list

  [ "$status" -eq 0 ]
  [[ "$output" == *"Medium"*"Three"*"Missing defaults"* ]]
  [[ "$output" != *"P2"*"M"*"Missing defaults"* ]]
}
@test "list: sparse Ready ticket still appears in default output" {
  printf '{"tickets":[
    {"id":1,"title":"Sparse ready","status":"Ready","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json

  run atoshell list

  [ "$status" -eq 0 ]
  [[ "$output" == *"Sparse ready"* ]]
}

# ── 15. Blockers scope ────────────────────────────────────────────────────────
@test "list blockers: exit code 0 with no dependencies" {
  run atoshell list blockers
  [ "$status" -eq 0 ]
}
@test "list blockers: shows nothing when no deps exist" {
  printf '{"tickets":[
    {"id":1,"title":"No deps A","status":"Ready","priority":"P1","size":"S","dependencies":[],"comments":[]},
    {"id":2,"title":"No deps B","status":"In Progress","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers
  [ "$status" -eq 0 ]
  [[ "$output" != *"No deps A"* ]]
  [[ "$output" != *"No deps B"* ]]
}
@test "list blockers: shows blocker ticket when a dep exists" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ticket","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"Blocker ticket","status":"Ready","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers
  [ "$status" -eq 0 ]
  [[ "$output" == *"#2"* ]]
}
@test "list blockers: shows what each blocker is blocking" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ticket","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"Blocker ticket","status":"Ready","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "list deps: alias works" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ticket","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"Blocker ticket","status":"Ready","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list deps
  [ "$status" -eq 0 ]
  [[ "$output" == *"#2"* ]]
}
@test "list blockers --json: exit code 0" {
  run atoshell list blockers --json
  [ "$status" -eq 0 ]
}
@test "list blockers --json: returns a JSON array" {
  run atoshell list blockers --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | type == "array"' > /dev/null
}
@test "list blockers --json: entry contains id, title, blocking array" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ticket","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"Blocker ticket","status":"Ready","priority":"P2","size":"M","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers --json
  [ "$status" -eq 0 ]
  blocking_len=$(echo "$output" | jq '[.[] | select(.id == 2)] | .[0].blocking | length')
  [ "$blocking_len" -gt 0 ]
}
@test "list blockers --json: empty array when no dependencies" {
  printf '{"tickets":[
    {"id":1,"title":"No dep ticket","status":"Ready","priority":"P1","size":"S","dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 0 ]
}
@test "list blockers: cycle flag shown for tickets in a dependency cycle" {
  printf '{"tickets":[
    {"id":1,"title":"A","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"B","status":"Ready","priority":"P2","size":"M","dependencies":[1],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers
  [ "$status" -eq 0 ]
  [[ "$output" == *"[CIRCULAR]"* ]]
}
@test "list blockers --json: cycle field is true for cyclic tickets" {
  printf '{"tickets":[
    {"id":1,"title":"A","status":"Ready","priority":"P1","size":"S","dependencies":[2],"comments":[]},
    {"id":2,"title":"B","status":"Ready","priority":"P2","size":"M","dependencies":[1],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell list blockers --json
  [ "$status" -eq 0 ]
  cycle_count=$(echo "$output" | jq '[.[] | select(.cycle == true)] | length')
  [ "$cycle_count" -gt 0 ]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "list --help: exits 0" {
  run atoshell list --help
  [ "$status" -eq 0 ]
}
@test "list --help: output contains Usage" {
  run atoshell list --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "list --help: output lists fixed disciplines" {
  run atoshell list --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid disciplines (fixed)"* ]]
  [[ "$output" == *"Frontend, Backend"* ]]
  [[ "$output" == *"match tickets to relevant capability areas"* ]]
}
