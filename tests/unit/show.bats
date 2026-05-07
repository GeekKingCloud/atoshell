#!/usr/bin/env bats
# Tests for: atoshell show

load '../helpers/setup'

# ── 1. Basic field output ─────────────────────────────────────────────────────
@test "show: exit code 0 for valid ticket" {
  run atoshell show 1
  [ "$status" -eq 0 ]
}
@test "show: title appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "show: ID appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "show: status appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ready"* ]]
}
@test "show: priority appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"P1"* ]]
}
@test "show: size appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"S"* ]]
}
@test "show: description appears in output" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"special characters"* ]]
}

# ── 2. Ticket location routing ────────────────────────────────────────────────
@test "show: finds ticket in queue.json" {
  run atoshell show 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "show: finds ticket in backlog.json" {
  run atoshell show 4
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrate to Postgres"* ]]
}
@test "show: finds ticket in done.json" {
  run atoshell show 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initial project setup"* ]]
}

# ── 3. Optional fields ────────────────────────────────────────────────────────
@test "show: type field appears when set" {
  printf '{
    "tickets": [
      {"id":1,"title":"Typed ticket","status":"Ready","priority":"P1","size":"S",
       "type":"Bug","dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Bug"* ]]
}
@test "show: type field absent when not set" {
  printf '{
    "tickets": [
      {"id":1,"title":"No type","status":"Ready","priority":"P1","size":"S",
       "type":"","disciplines":[],"accountable":[],"dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Type:"* ]]
}
@test "show: disciplines appear when set" {
  printf '{
    "tickets": [
      {"id":1,"title":"Disc ticket","status":"Ready","priority":"P1","size":"S",
       "disciplines":["Backend","Database"],"dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disciplines:"* ]]
  [[ "$output" == *"Backend"* ]]
  [[ "$output" == *"Database"* ]]
}
@test "show: disciplines absent when empty" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Disciplines:"* ]]
}
@test "show: accountable appear with @ prefix when set" {
  printf '{
    "tickets": [
      {"id":1,"title":"Assigned ticket","status":"Ready","priority":"P1","size":"S",
       "accountable":["lyra","will"],"dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"@lyra"* ]]
  [[ "$output" == *"@will"* ]]
}
@test "show: accountable absent when empty" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Accountable:"* ]]
}
@test "show: dependencies appear with # prefix when set" {
  printf '{
    "tickets": [
      {"id":1,"title":"Has dep","status":"Ready","priority":"P1","size":"S",
       "dependencies":[4],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"#4"* ]]
  [[ "$output" == *"Dependencies:"* ]]
}
@test "show: depends line absent when no dependencies" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Dependencies:"* ]]
}

# ── 4. Comments ───────────────────────────────────────────────────────────────
@test "show: comments section appears when ticket has comments" {
  run atoshell show 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Comments"* ]]
}
@test "show: comment text appears in output" {
  run atoshell show 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Design spec attached"* ]]
}
@test "show: comment author appears in output" {
  run atoshell show 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"lyra"* ]]
}
@test "show: comments section absent when ticket has no comments" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Comments"* ]]
}
@test "show: comment text field is displayed" {
  printf '{
    "tickets": [
      {"id":1,"title":"Text comment","status":"Ready","priority":"P1","size":"S",
       "dependencies":[],"comments":[{"author":"carol","text":"Uses text field"}]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uses text field"* ]]
}
@test "show: multiple comments all appear" {
  printf '{
    "tickets": [
      {"id":1,"title":"Multi comments","status":"Ready","priority":"P1","size":"S",
       "dependencies":[],"comments":[
         {"author":"lyra","body":"First comment"},
         {"author":"will","body":"Second comment"}
       ]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"First comment"* ]]
  [[ "$output" == *"Second comment"* ]]
}

# ── 5. --details flag ─────────────────────────────────────────────────────────
@test "show --details: exit code 0" {
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
}
@test "show --details: shows created_by field" {
  printf '{
    "tickets": [
      {"id":1,"title":"Detailed","status":"Ready","priority":"P1","size":"S",
       "created_by":"testuser","created_at":"2026-01-01T00:00:00Z",
       "dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created:"* ]]
  [[ "$output" == *"testuser"* ]]
}
@test "show --details: shows created_at timestamp" {
  printf '{
    "tickets": [
      {"id":1,"title":"Detailed","status":"Ready","priority":"P1","size":"S",
       "created_by":"testuser","created_at":"2026-01-01T00:00:00Z",
       "dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-01-01"* ]]
}
@test "show --details: shows updated_by and updated_at when present" {
  printf '{
    "tickets": [
      {"id":1,"title":"Edited","status":"Ready","priority":"P1","size":"S",
       "created_by":"lyra","created_at":"2026-01-01T00:00:00Z",
       "updated_by":"will","updated_at":"2026-02-01T00:00:00Z",
       "dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
  [[ "$output" == *"Edited:"* ]]
  [[ "$output" == *"will"* ]]
  [[ "$output" == *"2026-02-01"* ]]
}
@test "show --details: edited line absent when no updated_at" {
  printf '{
    "tickets": [
      {"id":1,"title":"Never edited","status":"Ready","priority":"P1","size":"S",
       "created_by":"lyra","created_at":"2026-01-01T00:00:00Z",
       "dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
  [[ "$output" != *"Edited:"* ]]
}
@test "show --details: comment timestamp shown when present" {
  printf '{
    "tickets": [
      {"id":1,"title":"Cmt ts","status":"Ready","priority":"P1","size":"S",
       "dependencies":[],"comments":[
         {"author":"lyra","body":"A comment","created_at":"2026-03-01T12:00:00Z"}
       ]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1 --details
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-03-01"* ]]
}
@test "show (no --details): created timestamp not shown" {
  printf '{
    "tickets": [
      {"id":1,"title":"No ts","status":"Ready","priority":"P1","size":"S",
       "created_by":"testuser","created_at":"2026-01-01T00:00:00Z",
       "dependencies":[],"comments":[]}
    ]
  }' > .atoshell/queue.json
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Created:"* ]]
}

# ── 6. --json output ──────────────────────────────────────────────────────────
@test "show --json: exit code 0" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
}
@test "show --json: output is valid JSON" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.' > /dev/null
}
@test "show --json: id field matches requested ticket" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 1 ]
}
@test "show --json: title field is correct" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  title=$(echo "$output" | jq -r '.title')
  [ "$title" = "Fix login bug" ]
}
@test "show: human output strips terminal control sequences from stored text" {
  jq '.tickets[0].title = "Danger \u001b[?25lTitle \u001b]52;c;SGVsbG8=\u0007Done" |
      .tickets[0].description = "Desc \u001b[31mred\u001b[0m \u0007 bell" |
      .tickets[0].comments = [{"author":"agent","text":"Comment \u001b]0;pwn\u0007text"}]' \
    .atoshell/queue.json > .atoshell/queue.tmp
  mv .atoshell/queue.tmp .atoshell/queue.json

  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Danger Title Done"* ]]
  [[ "$output" == *"Desc red  bell"* ]]
  [[ "$output" == *"Comment text"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}
@test "show --json: preserves raw stored terminal control sequences" {
  jq '.tickets[0].title = "Danger \u001b[?25lTitle \u001b]52;c;SGVsbG8=\u0007Done" |
      .tickets[0].description = "Desc \u001b[31mred\u001b[0m \u0007 bell" |
      .tickets[0].comments = [{"author":"agent","text":"Comment \u001b]0;pwn\u0007text"}]' \
    .atoshell/queue.json > .atoshell/queue.tmp
  mv .atoshell/queue.tmp .atoshell/queue.json

  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  title=$(printf '%s' "$output" | jq -r '.title')
  description=$(printf '%s' "$output" | jq -r '.description')
  comment=$(printf '%s' "$output" | jq -r '.comments[0].text')
  [[ "$title" == *$'\e'* ]]
  [[ "$title" == *$'\a'* ]]
  [[ "$description" == *$'\e'* ]]
  [[ "$comment" == *$'\e'* ]]
}
@test "show --json: works for backlog ticket" {
  run atoshell show 4 --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 4 ]
}
@test "show --json: works for done ticket" {
  run atoshell show 5 --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 5 ]
}
@test "show -j: short flag works identically to --json" {
  run atoshell show 1 -j
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.id' > /dev/null
}

# ── 7. Board subcommand ───────────────────────────────────────────────────────
@test "show board: exit code 0" {
  run atoshell show board
  [ "$status" -eq 0 ]
}
@test "show board: displays column headers" {
  run atoshell show board
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backlog"* ]]
  [[ "$output" == *"Ready"* ]]
}
@test "show board: shows a ready ticket" {
  run atoshell show board
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "show board: accepts baord misspelling" {
  run atoshell show baord
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ready"* ]]
}
@test "show board --done: includes Done column" {
  run atoshell show board --done
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
}
@test "show board --done: shows all Done tickets" {
  cat > .atoshell/done.json <<'EOF'
{"tickets":[
  {"id":10,"title":"Done 1","status":"Done","priority":"P2","size":"M"},
  {"id":11,"title":"Done 2","status":"Done","priority":"P2","size":"M"},
  {"id":12,"title":"Done 3","status":"Done","priority":"P2","size":"M"},
  {"id":13,"title":"Done 4","status":"Done","priority":"P2","size":"M"},
  {"id":14,"title":"Done 5","status":"Done","priority":"P2","size":"M"},
  {"id":15,"title":"Done 6","status":"Done","priority":"P2","size":"M"}
]}
EOF
  run atoshell show board --done
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done 6"* ]]
  [[ "$output" != *"-- 1 more --"* ]]
  [[ "$output" != *"Pass --done"* ]]
}
@test "show board --full: includes Done column" {
  run atoshell show board --full
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
  [[ "$output" != *"Pass --done"* ]]
}
@test "show board --all: aliases --full" {
  run atoshell show board --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
  [[ "$output" != *"Pass --done"* ]]
}
@test "show board -f: aliases --full" {
  run atoshell show board -f
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
  [[ "$output" != *"Pass --done"* ]]
}

# ── 8. Error cases ────────────────────────────────────────────────────────────
@test "show: no argument exits non-zero" {
  run atoshell show
  [ "$status" -ne 0 ]
}
@test "show: non-numeric ID exits non-zero" {
  run atoshell show abc
  [ "$status" -ne 0 ]
}
@test "show: nonexistent ID exits non-zero" {
  run atoshell show 999
  [ "$status" -ne 0 ]
}
@test "show: error message for missing ID mentions usage" {
  run atoshell show
  [[ "$output" == *"atoshell show"* ]] || [[ "$output" == *"Usage"* ]]
}
@test "show: error message for nonexistent ID mentions the ID" {
  run atoshell show 999
  [[ "$output" == *"999"* ]]
}

# ── 9. show next ──────────────────────────────────────────────────────────────
@test "show next: exit code 0 when ready ticket available" {
  run atoshell show next
  [ "$status" -eq 0 ]
}
@test "show next: shows the highest-priority unblocked ready ticket" {
  run atoshell show next
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" == *"#1"* ]]
}
@test "show next: ticket fields appear in output" {
  run atoshell show next
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status:"* ]]
  [[ "$output" == *"Priority:"* ]]
  [[ "$output" == *"Size:"* ]]
}
@test "show next: includes unassigned tickets" {
  printf '{"tickets":[
    {"id":1,"title":"Unassigned","status":"Ready","priority":"P1","size":"S",
     "accountable":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unassigned"* ]]
}
@test "show next: includes tickets assigned to current user" {
  printf '{"tickets":[
    {"id":1,"title":"Mine","status":"Ready","priority":"P1","size":"S",
     "accountable":["testuser"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mine"* ]]
}
@test "show next: skips tickets assigned only to others" {
  printf '{"tickets":[
    {"id":1,"title":"Theirs","status":"Ready","priority":"P0","size":"S",
     "accountable":["lyra"],"dependencies":[],"comments":[]},
    {"id":2,"title":"Unassigned","status":"Ready","priority":"P1","size":"S",
     "accountable":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unassigned"* ]]
  [[ "$output" != *"Theirs"* ]]
}
@test "show next: exits non-zero when no available ready tickets" {
  printf '{"tickets":[
    {"id":1,"title":"Taken","status":"Ready","priority":"P1","size":"S",
     "accountable":["lyra"],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error:"* ]]
}
@test "show next: exits non-zero when queue is empty" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run atoshell show next
  [ "$status" -ne 0 ]
}
@test "show next --json: exit code 0" {
  run atoshell show next --json
  [ "$status" -eq 0 ]
}
@test "show next --json: output is valid JSON" {
  run atoshell show next --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.' > /dev/null
}
@test "show next --json: returns highest-priority available ready ticket" {
  run atoshell show next --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 1 ]
}
@test "show next --json: priority ordering — P0 returned before P1" {
  printf '{"tickets":[
    {"id":10,"title":"Low","status":"Ready","priority":"P1","size":"S",
     "accountable":[],"dependencies":[],"comments":[]},
    {"id":11,"title":"Urgent","status":"Ready","priority":"P0","size":"XL",
     "accountable":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 11 ]
}
@test "show next --json: skips ready tickets blocked by in-progress deps" {
  printf '{"tickets":[
    {"id":1,"title":"Blocked ready","status":"Ready","priority":"P0","size":"S",
     "accountable":[],"dependencies":[8],"comments":[]},
    {"id":2,"title":"Actually ready","status":"Ready","priority":"P1","size":"S",
     "accountable":[],"dependencies":[],"comments":[]},
    {"id":8,"title":"Active dep","status":"In Progress","priority":"P1","size":"M",
     "accountable":[],"dependencies":[],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell show next --json
  [ "$status" -eq 0 ]
  id=$(echo "$output" | jq '.id')
  [ "$id" -eq 2 ]
}

# ── 10. Command aliases ───────────────────────────────────────────────────────
@test "show: read alias works" {
  run atoshell read 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}
@test "show: yomu alias works" {
  run atoshell yomu 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
}

# ── 11. Dependency context (blocked_by / blocking) ───────────────────────────
# Fixture: ticket 3 (Ready, queue.json) depends on ticket 1 (Ready).
# → show 3: blocked=true,  blocked_by=[{id:1}], blocking=[]
# → show 1: blocked=false, blocked_by=[],        blocking=[{id:3}]
@test "show --json: output includes 'blocked' field" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("blocked")' > /dev/null
}
@test "show --json: output includes 'blocked_by' array" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.blocked_by | arrays' > /dev/null
}
@test "show --json: output includes 'blocking' array" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.blocking | arrays' > /dev/null
}
@test "show --json: blocked=false when ticket has no unresolved dependencies" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  blocked=$(echo "$output" | jq '.blocked')
  [ "$blocked" = "false" ]
}
@test "show --json: blocked=true when a dependency is not Done" {
  run atoshell show 3 --json
  [ "$status" -eq 0 ]
  blocked=$(echo "$output" | jq '.blocked')
  [ "$blocked" = "true" ]
}
@test "show --json: blocked_by contains the open dependency" {
  run atoshell show 3 --json
  [ "$status" -eq 0 ]
  dep_id=$(echo "$output" | jq '.blocked_by[0].id')
  [ "$dep_id" -eq 1 ]
}
@test "show --json: blocked_by includes dependency status" {
  run atoshell show 3 --json
  [ "$status" -eq 0 ]
  dep_status=$(echo "$output" | jq -r '.blocked_by[0].status')
  [ "$dep_status" = "Ready" ]
}
@test "show --json: blocked_by includes open dependencies across state files" {
  jq '(.tickets[] | select(.id==3)).dependencies = [1,4,5]' \
    .atoshell/queue.json > "$BATS_TEST_TMPDIR/q.json"
  mv "$BATS_TEST_TMPDIR/q.json" .atoshell/queue.json

  run atoshell show 3 --json

  [ "$status" -eq 0 ]
  ids=$(echo "$output" | jq -r '.blocked_by | map(.id) | join(",")')
  statuses=$(echo "$output" | jq -r '.blocked_by | map(.status) | join(",")')
  [ "$ids" = "1,4" ]
  [ "$statuses" = "Ready,Backlog" ]
}
@test "show --json: blocked_by is empty when all deps are Done" {
  # Create a ticket that depends on #5 (Done) — should not be blocked
  run atoshell add "Dep on done" --body "desc" --dependencies "5"
  run atoshell show 6 --json
  [ "$status" -eq 0 ]
  len=$(echo "$output" | jq '.blocked_by | length')
  [ "$len" -eq 0 ]
}
@test "show --json: blocked=false when satisfied dependency exists" {
  run atoshell add "Dep on done" --body "desc" --dependencies "5"
  run atoshell show 6 --json
  [ "$status" -eq 0 ]
  blocked=$(echo "$output" | jq '.blocked')
  [ "$blocked" = "false" ]
}
@test "show --json: blocking contains tickets that depend on this one" {
  run atoshell show 1 --json
  [ "$status" -eq 0 ]
  len=$(echo "$output" | jq '.blocking | length')
  [ "$len" -ge 1 ]
  id=$(echo "$output" | jq '.blocking[0].id')
  [ "$id" -eq 3 ]
}
@test "show --json: blocking is empty when no tickets depend on this one" {
  run atoshell show 4 --json
  [ "$status" -eq 0 ]
  len=$(echo "$output" | jq '.blocking | length')
  [ "$len" -eq 0 ]
}
@test "show --json: done tickets do not appear in blocking" {
  # ticket 5 is Done; nothing depends on it in fixtures
  run atoshell show 5 --json
  [ "$status" -eq 0 ]
  len=$(echo "$output" | jq '.blocking | length')
  [ "$len" -eq 0 ]
}
@test "show --json: Done dependents do not appear in blocking" {
  jq '.tickets += [{
    "id":6,
    "title":"Done dependent",
    "status":"Done",
    "priority":"P2",
    "size":"M",
    "dependencies":[1],
    "comments":[]
  }]' .atoshell/done.json > "$BATS_TEST_TMPDIR/done.json"
  mv "$BATS_TEST_TMPDIR/done.json" .atoshell/done.json

  run atoshell show 1 --json

  [ "$status" -eq 0 ]
  present=$(echo "$output" | jq '[.blocking[] | select(.id == 6)] | length')
  [ "$present" -eq 0 ]
}
@test "show: human output shows Blocked by when ticket is blocked" {
  run atoshell show 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"Blocked by:"* ]]
}
@test "show: human Blocked by line contains the blocking dep ID" {
  run atoshell show 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "show: human output shows Blocking when ticket has non-Done dependents" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Blocking:"* ]]
}
@test "show: human output omits Blocked by when ticket is not blocked" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" != *"Blocked by:"* ]]
}
@test "show: human output omits Blocking when nothing depends on this ticket" {
  run atoshell show 4
  [ "$status" -eq 0 ]
  [[ "$output" != *"Blocking:"* ]]
}
@test "show: dotted separator present when ticket has blocking context" {
  run atoshell show 1
  [ "$status" -eq 0 ]
  [[ "$output" == *". . ."* ]]
}
@test "show: dotted separator absent when no blocking context" {
  run atoshell show 2
  [ "$status" -eq 0 ]
  [[ "$output" != *". . ."* ]]
}

# ── 12. Structured errors (--json mode) ──────────────────────────────────────
@test "show --json: ticket not found emits TICKET_NOT_FOUND error code" {
  run_split atoshell show 999 --json
  assert_json_error_split "TICKET_NOT_FOUND"
}
@test "show --json: ticket not found error is valid JSON" {
  run_split atoshell show 999 --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "TICKET_NOT_FOUND" ]
}
@test "show --json: ticket not found error includes id field" {
  run_split atoshell show 999 --json
  [ "$status" -ne 0 ]
  id_field=$(jq -r '.id' "$BATS_TEST_TMPDIR/stderr")
  [ "$id_field" = "999" ]
}
@test "show next --json: no ready tickets emits NO_READY_TICKETS error code" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run_split atoshell show next --json
  assert_json_error_split "NO_READY_TICKETS"
}
@test "show next --json: no ready tickets error is valid JSON" {
  printf '{"tickets":[]}\n' > .atoshell/queue.json
  run_split atoshell show next --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "NO_READY_TICKETS" ]
}
@test "show --json: non-numeric ID emits INVALID_TICKET_ID error code" {
  run_split atoshell show abc --json
  assert_json_error_split "INVALID_TICKET_ID"
}
@test "show --json: non-numeric ID error includes got field" {
  run_split atoshell show abc --json
  [ "$status" -ne 0 ]
  got=$(jq -r '.got' "$BATS_TEST_TMPDIR/stderr")
  [ "$got" = "abc" ]
}
# ── --help flag ──────────────────────────────────────────────────────────────
@test "show --help: exits 0" {
  run atoshell show --help
  [ "$status" -eq 0 ]
}
@test "show --help: output contains Usage" {
  run atoshell show --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
