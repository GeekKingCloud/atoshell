#!/usr/bin/env bats
# Tests for: atoshell add
#
# Non-interactive constraint: every test that creates a ticket must supply
# both a non-empty title (positional arg) AND --body "..." so the script
# hits the non-interactive branch:
#   elif [[ -n "$title" && -n "$description" ]]; then _create_ticket
#
# Fixtures contain IDs 1–5; meta.json fixture seeds next_id at 6,
# so the first new ticket in every test always gets ID 6.

load '../helpers/setup'

# ── 1. Basic silent-mode creation ─────────────────────────────────────────────
@test "add: exit code 0 for basic creation" {
  run atoshell add "Basic ticket" --body "A description"
  [ "$status" -eq 0 ]
}

@test "add: ticket appears in queue.json" {
  run atoshell add "Appears in queue" --body "desc"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Appears in queue")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: title stored correctly" {
  run atoshell add "Exact title check" --body "desc"
  [ "$status" -eq 0 ]
  title=$(jq -r '.tickets[] | select(.title=="Exact title check") | .title' .atoshell/queue.json)
  [ "$title" = "Exact title check" ]
}

@test "add: multi-word positional args concatenated with space" {
  run atoshell add My multi word title --body "desc"
  [ "$status" -eq 0 ]
  title=$(jq -r '.tickets[] | select(.title=="My multi word title") | .title' .atoshell/queue.json)
  [ "$title" = "My multi word title" ]
}

# ── 2. Defaults ───────────────────────────────────────────────────────────────
@test "add: type defaults to Task" {
  run atoshell add "Default type" --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Default type") | .type' .atoshell/queue.json)
  [ "$tp" = "Task" ]
}
@test "add: --type sets ticket type" {
  run atoshell add "A bug ticket" --type Bug --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="A bug ticket") | .type' .atoshell/queue.json)
  [ "$tp" = "Bug" ]
}
@test "add: --type is case-insensitive" {
  run atoshell add "A feature ticket" --type feature --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="A feature ticket") | .type' .atoshell/queue.json)
  [ "$tp" = "Feature" ]
}
@test "add: --kind is alias for --type" {
  run atoshell add "Kind alias" --kind Bug --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Kind alias") | .type' .atoshell/queue.json)
  [ "$tp" = "Bug" ]
}
@test "add: -t is short flag for --type" {
  run atoshell add "Short type flag" -t Feature --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Short type flag") | .type' .atoshell/queue.json)
  [ "$tp" = "Feature" ]
}
@test "add: --type rejects unknown type" {
  run atoshell add "Bad type" --type InvalidType --body "desc"
  [ "$status" -ne 0 ]
}
@test "add: --type 0 resolves to Bug" {
  run atoshell add "Type index 0" --type 0 --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Type index 0") | .type' .atoshell/queue.json)
  [ "$tp" = "Bug" ]
}
@test "add: --type 1 resolves to Feature" {
  run atoshell add "Type index 1" --type 1 --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Type index 1") | .type' .atoshell/queue.json)
  [ "$tp" = "Feature" ]
}
@test "add: --type 2 resolves to Task" {
  run atoshell add "Type index 2" --type 2 --body "desc"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Type index 2") | .type' .atoshell/queue.json)
  [ "$tp" = "Task" ]
}

@test "add: priority defaults to P2" {
  run atoshell add "Default prio" --body "desc"
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="Default prio") | .priority' .atoshell/queue.json)
  [ "$prio" = "P2" ]
}

@test "add: size defaults to M" {
  run atoshell add "Default size" --body "desc"
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="Default size") | .size' .atoshell/queue.json)
  [ "$sz" = "M" ]
}

@test "add: status defaults to Ready" {
  run atoshell add "Default status" --body "desc"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.title=="Default status") | .status' .atoshell/queue.json)
  [ "$st" = "Ready" ]
}

@test "add: dependencies defaults to empty array" {
  run atoshell add "Default deps" --body "desc"
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Default deps") | .dependencies | length' .atoshell/queue.json)
  [ "$len" -eq 0 ]
}

@test "add: accountable defaults to empty array" {
  run atoshell add "Default accountable" --body "desc"
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Default accountable") | .accountable | length' .atoshell/queue.json)
  [ "$len" -eq 0 ]
}

@test "add: disciplines defaults to empty array" {
  run atoshell add "Default disciplines" --body "desc"
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Default disciplines") | .disciplines | length' .atoshell/queue.json)
  [ "$len" -eq 0 ]
}

@test "add: comments defaults to empty array" {
  run atoshell add "Default comments" --body "desc"
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Default comments") | .comments | length' .atoshell/queue.json)
  [ "$len" -eq 0 ]
}

@test "add: created_at is set and non-null" {
  run atoshell add "Has timestamp" --body "desc"
  [ "$status" -eq 0 ]
  ts=$(jq -r '.tickets[] | select(.title=="Has timestamp") | .created_at' .atoshell/queue.json)
  [ -n "$ts" ]
  [ "$ts" != "null" ]
}

@test "add: created_at honors IANA ATOSHELL_TIMEZONE" {
  printf '%s\n' 'ATOSHELL_TIMEZONE="America/Mexico_City"' >> .atoshell/config.env
  run atoshell add "Has Mexico City timestamp" --body "desc"
  [ "$status" -eq 0 ]
  ts=$(jq -r '.tickets[] | select(.title=="Has Mexico City timestamp") | .created_at' .atoshell/queue.json)
  [[ "$ts" =~ -06:00$ ]]
}

@test "add: created_by is [agent] when stdin is not a TTY" {
  run atoshell add "Has author" --body "desc"
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.title=="Has author") | .created_by' .atoshell/queue.json)
  [ "$by" = "[agent]" ]
}
@test "add: --as stamps created_by to named agent" {
  run atoshell add "Has named author" --body "desc" --as agent-1
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.title=="Has named author") | .created_by' .atoshell/queue.json)
  [ "$by" = "agent-1" ]
}
@test "add: --as numeric shorthand normalizes to agent-N" {
  run atoshell add "Has numeric author" --body "desc" --as 10
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.title=="Has numeric author") | .created_by' .atoshell/queue.json)
  [ "$by" = "agent-10" ]
}
@test "add: --as rejects arbitrary names" {
  run atoshell add "Has invalid author" --body "desc" --as alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}

# ── 3. Description aliases ────────────────────────────────────────────────────
@test "add: --body stores description" {
  run atoshell add "Body flag" --body "body text"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Body flag") | .description' .atoshell/queue.json)
  [ "$desc" = "body text" ]
}

@test "add: --description stores description" {
  run atoshell add "Desc flag" --description "description text"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Desc flag") | .description' .atoshell/queue.json)
  [ "$desc" = "description text" ]
}

@test "add: --desc stores description" {
  run atoshell add "Desc alias" --desc "desc alias text"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Desc alias") | .description' .atoshell/queue.json)
  [ "$desc" = "desc alias text" ]
}

@test "add: -b short flag stores description" {
  run atoshell add "Short desc" -b "short desc text"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Short desc") | .description' .atoshell/queue.json)
  [ "$desc" = "short desc text" ]
}

# ── 4. Priority ───────────────────────────────────────────────────────────────
@test "add: --priority P0 stored correctly" {
  run atoshell add "P0 ticket" --body "desc" --priority P0
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="P0 ticket") | .priority' .atoshell/queue.json)
  [ "$prio" = "P0" ]
}

@test "add: --priority P1 stored correctly" {
  run atoshell add "P1 ticket" --body "desc" --priority P1
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="P1 ticket") | .priority' .atoshell/queue.json)
  [ "$prio" = "P1" ]
}

@test "add: --priority P2 stored correctly" {
  run atoshell add "P2 ticket" --body "desc" --priority P2
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="P2 ticket") | .priority' .atoshell/queue.json)
  [ "$prio" = "P2" ]
}

@test "add: --priority P3 stored correctly" {
  run atoshell add "P3 ticket" --body "desc" --priority P3
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="P3 ticket") | .priority' .atoshell/queue.json)
  [ "$prio" = "P3" ]
}

@test "add: -p short flag stores priority" {
  run atoshell add "Short prio" --body "desc" -p P1
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="Short prio") | .priority' .atoshell/queue.json)
  [ "$prio" = "P1" ]
}
@test "add: --priority 0 resolves to P0" {
  run atoshell add "Prio index 0" --body "desc" --priority 0
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="Prio index 0") | .priority' .atoshell/queue.json)
  [ "$prio" = "P0" ]
}
@test "add: --priority 3 resolves to P3" {
  run atoshell add "Prio index 3" --body "desc" --priority 3
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="Prio index 3") | .priority' .atoshell/queue.json)
  [ "$prio" = "P3" ]
}

# ── 5. Size ───────────────────────────────────────────────────────────────────
@test "add: --size XS stored correctly" {
  run atoshell add "XS ticket" --body "desc" --size XS
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="XS ticket") | .size' .atoshell/queue.json)
  [ "$sz" = "XS" ]
}

@test "add: --size S stored correctly" {
  run atoshell add "S ticket" --body "desc" --size S
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="S ticket") | .size' .atoshell/queue.json)
  [ "$sz" = "S" ]
}

@test "add: --size M stored correctly" {
  run atoshell add "M ticket" --body "desc" --size M
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="M ticket") | .size' .atoshell/queue.json)
  [ "$sz" = "M" ]
}

@test "add: --size L stored correctly" {
  run atoshell add "L ticket" --body "desc" --size L
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="L ticket") | .size' .atoshell/queue.json)
  [ "$sz" = "L" ]
}

@test "add: --size XL stored correctly" {
  run atoshell add "XL ticket" --body "desc" --size XL
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="XL ticket") | .size' .atoshell/queue.json)
  [ "$sz" = "XL" ]
}

@test "add: -s short flag stores size" {
  run atoshell add "Short size" --body "desc" -s S
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="Short size") | .size' .atoshell/queue.json)
  [ "$sz" = "S" ]
}
@test "add: --size 0 resolves to XS" {
  run atoshell add "Size index 0" --body "desc" --size 0
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="Size index 0") | .size' .atoshell/queue.json)
  [ "$sz" = "XS" ]
}
@test "add: --size 4 resolves to XL" {
  run atoshell add "Size index 4" --body "desc" --size 4
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.title=="Size index 4") | .size' .atoshell/queue.json)
  [ "$sz" = "XL" ]
}

# ── 6. Status routing ─────────────────────────────────────────────────────────
@test "add: --status Ready routes to queue.json" {
  run atoshell add "Ready ticket" --body "desc" --status "Ready"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Ready ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: --status 'In Progress' routes to queue.json with correct status" {
  run atoshell add "WIP ticket" --body "desc" --status "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.title=="WIP ticket") | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}

@test "add: --status Backlog routes to backlog.json" {
  run atoshell add "Backlog ticket" --body "desc" --status "Backlog"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Backlog ticket")] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}

@test "add: --status 'In Review' is rejected" {
  run atoshell add "Review ticket" --body "desc" --status "In Review"
  [ "$status" -ne 0 ]
}

@test "add: --status Done routes to done.json" {
  run atoshell add "Done ticket" --body "desc" --status "Done"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Done ticket")] | length' .atoshell/done.json)
  [ "$count" -eq 1 ]
}

@test "add: -S short flag routes to correct file" {
  run atoshell add "Short status" --body "desc" -S "Backlog"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Short status")] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}

# ── 7. Disciplines ────────────────────────────────────────────────────────────
@test "add: single discipline stored" {
  run atoshell add "One disc" --body "desc" --disciplines "Frontend"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="One disc") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Frontend" ]
}

@test "add: comma-separated disciplines stores both" {
  run atoshell add "Two discs" --body "desc" --disciplines "Frontend,Backend"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Two discs") | .disciplines | length' .atoshell/queue.json)
  [ "$count" -eq 2 ]
}

@test "add: --discipline alias works" {
  run atoshell add "Disc alias" --body "desc" --discipline "Backend"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Disc alias") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Backend" ]
}

@test "add: --dis alias works" {
  run atoshell add "Dis alias" --body "desc" --dis "Backend"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Dis alias") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Backend" ]
}

@test "add: -d short flag works" {
  run atoshell add "Short disc" --body "desc" -d "Core"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Short disc") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Core" ]
}

@test "add: discipline is case-insensitive (frontend -> Frontend)" {
  run atoshell add "Case disc" --body "desc" --disciplines "frontend"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Case disc") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Frontend" ]
}

@test "add: 'fe' alias resolves to Frontend" {
  run atoshell add "Fe alias" --body "desc" --disciplines "fe"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Fe alias") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Frontend" ]
}

@test "add: 'be' alias resolves to Backend" {
  run atoshell add "Be alias" --body "desc" --disciplines "be"
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.title=="Be alias") | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Backend" ]
}

@test "add: duplicate disciplines are deduplicated" {
  run atoshell add "Dedup discs" --body "desc" --disciplines "Frontend,Frontend"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Dedup discs") | .disciplines | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: invalid discipline exits with non-zero" {
  run atoshell add "Bad disc" --body "desc" --disciplines "NotADiscipline"
  [ "$status" -ne 0 ]
}

# ── 8. Accountable ────────────────────────────────────────────────────────────
@test "add: single accountable stored" {
  run atoshell add "One accountable" --body "desc" --accountable "lyra"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="One accountable") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "lyra" ]
}

@test "add: comma-separated accountable stores both" {
  run atoshell add "Two accountable" --body "desc" --accountable "lyra,will"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Two accountable") | .accountable | length' .atoshell/queue.json)
  [ "$count" -eq 2 ]
}

@test "add: --assign alias works" {
  run atoshell add "Assign alias" --body "desc" --assign "dave"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="Assign alias") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "dave" ]
}

@test "add: -a short flag works" {
  run atoshell add "Short assign" --body "desc" -a "eve"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="Short assign") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "eve" ]
}

@test "add: 'me' resolves to testuser" {
  run atoshell add "Me accountable" --body "desc" --accountable "me"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="Me accountable") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "testuser" ]
}

@test "add: 'agent' resolves to [agent] in accountable" {
  run atoshell add "Agent accountable" --body "desc" --accountable "agent"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="Agent accountable") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "[agent]" ]
}

@test "add: accountable [agent] stored correctly" {
  run atoshell add "Agent accountable check" --body "desc" --accountable "agent"
  [ "$status" -eq 0 ]
  asn=$(jq -r '.tickets[] | select(.title=="Agent accountable check") | .accountable[0]' .atoshell/queue.json)
  [ "$asn" = "[agent]" ]
}

@test "add: duplicate accountable are deduplicated" {
  run atoshell add "Dedup accountable" --body "desc" --accountable "lyra,lyra"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Dedup accountable") | .accountable | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: 'me' and named accountable both stored" {
  run atoshell add "Mixed accountable" --body "desc" --accountable "me,lyra"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Mixed accountable") | .accountable | length' .atoshell/queue.json)
  [ "$count" -eq 2 ]
  # jq unique sorts alphabetically — check membership, not position
  has_user=$(jq -r '.tickets[] | select(.title=="Mixed accountable") | .accountable | contains(["testuser"])' .atoshell/queue.json)
  [ "$has_user" = "true" ]
}

# ── 9. Dependencies ───────────────────────────────────────────────────────────
@test "add: single dependency stored as JSON number" {
  run atoshell add "One dep" --body "desc" --dependencies "1"
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="One dep") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" = "1" ]
}

@test "add: comma-separated dependencies stores both" {
  run atoshell add "Two deps" --body "desc" --dependencies "1,2"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Two deps") | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 2 ]
}

@test "add: --dependency alias works" {
  run atoshell add "Dep alias" --body "desc" --dependency "1"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Dep alias") | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: --depends alias works" {
  run atoshell add "Depends alias" --body "desc" --depends "1"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Depends alias") | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: -D short flag works" {
  run atoshell add "Short dep" --body "desc" -D "1"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Short dep") | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: dependency on queue ticket (#1) works" {
  run atoshell add "Dep queue" --body "desc" --dependencies "1"
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Dep queue") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" = "1" ]
}

@test "add: dependency on backlog ticket (#4) works" {
  run atoshell add "Dep backlog" --body "desc" --dependencies "4"
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Dep backlog") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" = "4" ]
}

@test "add: dependency on done ticket (#5) works" {
  run atoshell add "Dep archive" --body "desc" --dependencies "5"
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Dep archive") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" = "5" ]
}

@test "add: duplicate dependency IDs are deduplicated" {
  run atoshell add "Dedup deps" --body "desc" --dependencies "1,1"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.title=="Dedup deps") | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "add: non-numeric dependency ID exits with non-zero" {
  run atoshell add "Bad dep id" --body "desc" --dependencies "abc"
  [ "$status" -ne 0 ]
}

@test "add: non-existent ticket dependency exits with non-zero" {
  run atoshell add "Missing dep" --body "desc" --dependencies "999"
  [ "$status" -ne 0 ]
}

# ── 10. ID assignment ─────────────────────────────────────────────────────────
@test "add: first new ticket gets ID 6" {
  run atoshell add "First ticket" --body "desc"
  [ "$status" -eq 0 ]
  id=$(jq '.tickets[] | select(.title=="First ticket") | .id' .atoshell/queue.json)
  [ "$id" -eq 6 ]
}

@test "add: second new ticket gets ID 7" {
  run atoshell add "First ticket" --body "desc"
  run atoshell add "Second ticket" --body "desc"
  [ "$status" -eq 0 ]
  id=$(jq '.tickets[] | select(.title=="Second ticket") | .id' .atoshell/queue.json)
  [ "$id" -eq 7 ]
}

# ── 11. UUID ──────────────────────────────────────────────────────────────────
@test "add: created ticket has a non-null uuid field" {
  run atoshell add "UUID ticket" --body "desc"
  [ "$status" -eq 0 ]
  uuid=$(jq -r '.tickets[] | select(.title=="UUID ticket") | .uuid' .atoshell/queue.json)
  [ -n "$uuid" ]
  [ "$uuid" != "null" ]
}
@test "add: uuid matches UUID format" {
  run atoshell add "UUID format" --body "desc"
  [ "$status" -eq 0 ]
  uuid=$(jq -r '.tickets[] | select(.title=="UUID format") | .uuid' .atoshell/queue.json)
  [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# ── 12. Output content ────────────────────────────────────────────────────────
@test "add: output contains ticket ID #6" {
  run atoshell add "Output ticket" --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#6"* ]]
}

@test "add: output contains ticket title" {
  run atoshell add "Output title check" --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Output title check"* ]]
}

@test "add: human output strips terminal control sequences from title" {
  run atoshell add $'Danger \e]52;c;SGVsbG8=\aTitle' --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Danger Title"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "add: output contains status" {
  run atoshell add "Output status" --body "desc" --status "Ready"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ready"* ]]
}

@test "add: output contains Accountable when accountable set" {
  run atoshell add "Output accountable" --body "desc" --accountable "lyra"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Accountable:"* ]]
}

@test "add: output contains Disciplines when disciplines set" {
  run atoshell add "Output discs" --body "desc" --disciplines "Frontend"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disciplines:"* ]]
}

@test "add: output contains Depends when dependencies set" {
  run atoshell add "Output deps" --body "desc" --dependencies "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Depends:"* ]]
}

@test "add: output omits Accountable when no accountable" {
  run atoshell add "No accountable" --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Accountable:"* ]]
}

@test "add: output omits Disciplines when no disciplines" {
  run atoshell add "No discs" --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Disciplines:"* ]]
}

@test "add: output omits Depends when no dependencies" {
  run atoshell add "No deps" --body "desc"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Depends:"* ]]
}

# ── 13. TTY gate (interactive paths rejected without TTY) ─────────────────────
@test "add: no args exits 1 with TTY error message" {
  # Redirect stderr to stdout so bats captures the error message
  run bash -c 'atoshell add 2>&1'
  [ "$status" -eq 1 ]
  [[ "$output" == *"stdin is not a TTY"* ]]
}

@test "add: title only (no body) falls through to interactive and exits 1" {
  run atoshell add "Title only"
  [ "$status" -eq 1 ]
}

@test "add: --simple exits 1 without TTY" {
  run atoshell add --simple "Title"
  [ "$status" -eq 1 ]
}

@test "add: --multi exits 1 without TTY" {
  run atoshell add --multi
  [ "$status" -eq 1 ]
}

@test "add: --multi --simple exits 1 without TTY" {
  run atoshell add --multi --simple
  [ "$status" -eq 1 ]
}

@test "add: import validation strips terminal control sequences from human errors" {
  cat > tickets.json <<JSON
[
  {"title":"Bad type","type":"Bad\u001b]52;c;SGVsbG8=\u0007Type"}
]
JSON
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"BadType"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

# ── 14. Combinations ──────────────────────────────────────────────────────────
@test "add: priority + size + status + description all together" {
  run atoshell add "Combo basic" --body "full desc" --priority P1 --size L --status "Backlog"
  [ "$status" -eq 0 ]
  prio=$(jq -r '.tickets[] | select(.title=="Combo basic") | .priority' .atoshell/backlog.json)
  sz=$(jq -r '.tickets[] | select(.title=="Combo basic") | .size' .atoshell/backlog.json)
  st=$(jq -r '.tickets[] | select(.title=="Combo basic") | .status' .atoshell/backlog.json)
  desc=$(jq -r '.tickets[] | select(.title=="Combo basic") | .description' .atoshell/backlog.json)
  [ "$prio" = "P1" ]
  [ "$sz" = "L" ]
  [ "$st" = "Backlog" ]
  [ "$desc" = "full desc" ]
}

@test "add: accountable + disciplines + dependencies together" {
  run atoshell add "Combo full" --body "desc" \
    --accountable "me,lyra" \
    --disciplines "fe,be" \
    --dependencies "1,4"
  [ "$status" -eq 0 ]
  asn_count=$(jq '.tickets[] | select(.title=="Combo full") | .accountable | length' .atoshell/queue.json)
  disc_count=$(jq '.tickets[] | select(.title=="Combo full") | .disciplines | length' .atoshell/queue.json)
  dep_count=$(jq '.tickets[] | select(.title=="Combo full") | .dependencies | length' .atoshell/queue.json)
  [ "$asn_count" -eq 2 ]
  [ "$disc_count" -eq 2 ]
  [ "$dep_count" -eq 2 ]
}

# ── 15. --import ──────────────────────────────────────────────────────────
_write_json() { printf '%s' "$1" > tickets.json; }
_assert_validation_type() {
  local expected="$1"
  [ "$status" -ne 0 ]
  [ "$(printf '%s\n' "$output" | jq -r '.error')" = "VALIDATION_FAILED" ]
  printf '%s\n' "$output" | jq -e --arg type "$expected" \
    '.errors[] | select(.type == $type)' >/dev/null
}

@test "add --import: exit code 0 for valid batch" {
  _write_json '[{"title":"Batch one","description":"desc"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
}
@test "add --import: creates ticket in queue.json" {
  _write_json '[{"title":"JSON ticket","description":"desc"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="JSON ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "add --import: creates multiple tickets" {
  _write_json '[{"title":"First","description":"a"},{"title":"Second","description":"b"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  c1=$(jq '[.tickets[] | select(.title=="First")] | length' .atoshell/queue.json)
  c2=$(jq '[.tickets[] | select(.title=="Second")] | length' .atoshell/queue.json)
  [ "$c1" -eq 1 ]
  [ "$c2" -eq 1 ]
}
@test "add --import: sequential IDs assigned" {
  _write_json '[{"title":"Seq A","description":"d"},{"title":"Seq B","description":"d"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  id_a=$(jq '.tickets[] | select(.title=="Seq A") | .id' .atoshell/queue.json)
  id_b=$(jq '.tickets[] | select(.title=="Seq B") | .id' .atoshell/queue.json)
  [ "$(( id_b - id_a ))" -eq 1 ]
}
@test "add --import: description field stored" {
  _write_json '[{"title":"Desc test","description":"my desc"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Desc test") | .description' .atoshell/queue.json)
  [ "$desc" = "my desc" ]
}
@test "add --import: body alias for description is accepted" {
  _write_json '[{"title":"Body test","body":"my body"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.title=="Body test") | .description' .atoshell/queue.json)
  [ "$desc" = "my body" ]
}
@test "add --import: defaults applied when fields omitted" {
  _write_json '[{"title":"Defaults only"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Defaults only") | .type' .atoshell/queue.json)
  pr=$(jq -r '.tickets[] | select(.title=="Defaults only") | .priority' .atoshell/queue.json)
  sz=$(jq -r '.tickets[] | select(.title=="Defaults only") | .size' .atoshell/queue.json)
  st=$(jq -r '.tickets[] | select(.title=="Defaults only") | .status' .atoshell/queue.json)
  [ "$tp" = "Task" ]
  [ "$pr" = "P2" ]
  [ "$sz" = "M" ]
  [ "$st" = "Ready" ]
}
@test "add --import: omitted fields use configured defaults" {
  printf '%s\n' \
    'STATUS_BACKLOG="Parked"' \
    'STATUS_READY="Queued"' \
    'STATUS_IN_PROGRESS="Doing"' \
    'STATUS_DONE="Shipped"' \
    'TYPE_0="Defect"' \
    'TYPE_1="Capability"' \
    'TYPE_2="Chore"' \
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
  _write_json '[{"title":"Configured defaults"}]'

  run atoshell add --import tickets.json

  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Configured defaults") | .type' .atoshell/queue.json)
  pr=$(jq -r '.tickets[] | select(.title=="Configured defaults") | .priority' .atoshell/queue.json)
  sz=$(jq -r '.tickets[] | select(.title=="Configured defaults") | .size' .atoshell/queue.json)
  st=$(jq -r '.tickets[] | select(.title=="Configured defaults") | .status' .atoshell/queue.json)
  [ "$tp" = "Chore" ]
  [ "$pr" = "Medium" ]
  [ "$sz" = "Three" ]
  [ "$st" = "Queued" ]
}
@test "add --import: custom type stored" {
  _write_json '[{"title":"Bug import","type":"Bug"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="Bug import") | .type' .atoshell/queue.json)
  [ "$tp" = "Bug" ]
}
@test "add --import: custom priority stored" {
  _write_json '[{"title":"P0 import","priority":"P0"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  pr=$(jq -r '.tickets[] | select(.title=="P0 import") | .priority' .atoshell/queue.json)
  [ "$pr" = "P0" ]
}
@test "add --import: status routes to correct file" {
  _write_json '[{"title":"Backlog import","status":"Backlog"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Backlog import")] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}
@test "add --import: disciplines array stored" {
  _write_json '[{"title":"Disc import","disciplines":["Backend","DevOps"]}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Disc import") | .disciplines | length' .atoshell/queue.json)
  [ "$len" -eq 2 ]
}
@test "add --import: accountable array stored" {
  _write_json '[{"title":"Acct import","accountable":["lyra","will"]}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  len=$(jq '.tickets[] | select(.title=="Acct import") | .accountable | length' .atoshell/queue.json)
  [ "$len" -eq 2 ]
}
@test "add --import: valid dependency stored" {
  _write_json '[{"title":"Dep import","dependencies":[1]}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Dep import") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" -eq 1 ]
}
@test "add --import: explicit source ids are remapped and internal dependencies follow the new ids" {
  _write_json '[{"id":1,"title":"Imported A","dependencies":[2]},{"id":2,"title":"Imported B"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  id_a=$(jq '.tickets[] | select(.title=="Imported A") | .id' .atoshell/queue.json)
  id_b=$(jq '.tickets[] | select(.title=="Imported B") | .id' .atoshell/queue.json)
  dep_a=$(jq '.tickets[] | select(.title=="Imported A") | .dependencies[0]' .atoshell/queue.json)
  [ "$id_a" -eq 6 ]
  [ "$id_b" -eq 7 ]
  [ "$dep_a" -eq 7 ]
}
@test "add --import: explicit source ids can still depend on an existing external ticket" {
  _write_json '[{"id":1,"title":"Imported ext dep","dependencies":[5]}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Imported ext dep") | .dependencies[0]' .atoshell/queue.json)
  [ "$dep" -eq 5 ]
}
@test "add --import: explicit source ids support forward references later in the batch" {
  _write_json '[{"id":9,"title":"Forward source dep","dependencies":[11]},{"id":10,"title":"Middle source item"},{"id":11,"title":"Later source target"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Forward source dep") | .dependencies[0]' .atoshell/queue.json)
  target_id=$(jq '.tickets[] | select(.title=="Later source target") | .id' .atoshell/queue.json)
  [ "$dep" -eq "$target_id" ]
  [ "$target_id" -eq 8 ]
}
@test "add --import: dependency on a later ticket in the same batch passes" {
  _write_json '[{"title":"Forward dep","dependencies":[8]},{"title":"Middle item"},{"title":"Later target"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.title=="Forward dep") | .dependencies[0]' .atoshell/queue.json)
  target_id=$(jq '.tickets[] | select(.title=="Later target") | .id' .atoshell/queue.json)
  [ "$dep" -eq 8 ]
  [ "$target_id" -eq 8 ]
}
@test "add --import: empty array exits 0 and creates no tickets" {
  _write_json '[]'
  before=$(jq '.tickets | length' .atoshell/queue.json)
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  after=$(jq '.tickets | length' .atoshell/queue.json)
  [ "$before" -eq "$after" ]
}
@test "add --import: stdin mode works with -" {
  run bash -c 'printf '"'"'[{"title":"Stdin ticket"}]'"'"' | atoshell add --import -'
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Stdin ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "add --import: created_by is [agent] in non-TTY context" {
  _write_json '[{"title":"Agent import"}]'
  run atoshell add --import tickets.json
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.title=="Agent import") | .created_by' .atoshell/queue.json)
  [ "$by" = "[agent]" ]
}

# ── 15b. --import validation ───────────────────────────────────────────────
@test "add --import: missing title fails validation" {
  _write_json '[{"description":"no title here"}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"title"* ]]
}
@test "add --import: missing title prevents any ticket being created" {
  before=$(jq '.tickets | length' .atoshell/queue.json)
  _write_json '[{"description":"no title"}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  after=$(jq '.tickets | length' .atoshell/queue.json)
  [ "$before" -eq "$after" ]
}
@test "add --import: non-existent dependency fails validation" {
  _write_json '[{"title":"Bad dep","dependencies":[999]}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"999"* ]]
}
@test "add --import: truly missing dependency in a batch fails validation" {
  _write_json '[{"title":"Bad dep","dependencies":[9]},{"title":"Present peer"}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"9"* ]]
}
@test "add --import: non-existent dep prevents any ticket being created" {
  before=$(jq '.tickets | length' .atoshell/queue.json)
  _write_json '[{"title":"Bad dep","dependencies":[999]}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  after=$(jq '.tickets | length' .atoshell/queue.json)
  [ "$before" -eq "$after" ]
}
@test "add --import: self-dependency fails validation" {
  _write_json '[{"title":"Self dep","dependencies":[6]}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot depend on itself"* ]]
}
@test "add --import: cyclic dependency within the batch fails validation" {
  _write_json '[{"title":"Cycle A","dependencies":[7]},{"title":"Cycle B","dependencies":[6]}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"dependency cycle"* ]]
}
@test "add --import: duplicate explicit import ids fail validation" {
  _write_json '[{"id":9,"title":"Dup A"},{"id":9,"title":"Dup B"}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"ambiguous"* ]]
}
@test "add --import: multiple validation errors all reported" {
  _write_json '[{"description":"no title A"},{"description":"no title B"}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
  # Error count message should mention 2
  [[ "$output" == *"2"* ]]
}
@test "add --import: non-numeric dependency string fails validation" {
  _write_json '[{"title":"Bad dep str","dependencies":["abc"]}]'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
}
@test "add --import: invalid enum creates nothing and leaves no transaction residue" {
  _write_json '[{"title":"Bad enum","priority":"NotPriority"}]'
  run atoshell add --import tickets.json --json
  [ "$status" -ne 0 ]
  [ "$(printf '%s\n' "$output" | jq -r '.error')" = "VALIDATION_FAILED" ]
  [ "$(printf '%s\n' "$output" | jq -r '.errors[0].type')" = "INVALID_PRIORITY" ]
  count=$(jq '[.tickets[] | select(.title=="Bad enum")] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
  [ ! -e .atoshell/.transaction ]
}
@test "add --import: explicit empty enum is invalid before transaction starts" {
  _write_json '[{"title":"Empty enum","type":""}]'
  run atoshell add --import tickets.json --json
  [ "$status" -ne 0 ]
  [ "$(printf '%s\n' "$output" | jq -r '.error')" = "VALIDATION_FAILED" ]
  [ "$(printf '%s\n' "$output" | jq -r '.errors[0].type')" = "INVALID_TYPE" ]
  count=$(jq '[.tickets[] | select(.title=="Empty enum")] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
  [ ! -e .atoshell/.transaction ]
}
@test "add --import --json: invalid size reports INVALID_SIZE validation type" {
  _write_json '[{"title":"Bad size","size":"Huge"}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type INVALID_SIZE
}
@test "add --import --json: invalid status reports INVALID_STATUS validation type" {
  _write_json '[{"title":"Bad status","status":"Maybe"}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type INVALID_STATUS
}
@test "add --import --json: missing title reports MISSING_TITLE validation type" {
  _write_json '[{"description":"no title here"}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type MISSING_TITLE
}
@test "add --import --json: non-numeric import id reports INVALID_IMPORT_ID validation type" {
  _write_json '[{"id":"abc","title":"Bad id"}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type INVALID_IMPORT_ID
}
@test "add --import --json: non-numeric dependency reports INVALID_DEP_ID validation type" {
  _write_json '[{"title":"Bad dep str","dependencies":["abc"]}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type INVALID_DEP_ID
}
@test "add --import --json: missing dependency reports DEP_NOT_FOUND validation type" {
  _write_json '[{"title":"Bad dep","dependencies":[999]}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type DEP_NOT_FOUND
}
@test "add --import --json: self dependency reports SELF_DEPENDENCY validation type" {
  _write_json '[{"title":"Self dep","dependencies":[6]}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type SELF_DEPENDENCY
}
@test "add --import --json: duplicate import ids report DUPLICATE_IMPORT_ID validation type" {
  _write_json '[{"id":9,"title":"Dup A"},{"id":9,"title":"Dup B"}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type DUPLICATE_IMPORT_ID
}
@test "add --import --json: dependency cycle reports DEP_CYCLE validation type" {
  _write_json '[{"title":"Cycle A","dependencies":[7]},{"title":"Cycle B","dependencies":[6]}]'
  run atoshell add --import tickets.json --json
  _assert_validation_type DEP_CYCLE
}
@test "add --import: file not found exits non-zero" {
  run atoshell add --import /no/such/file.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
@test "add --import: non-array JSON input exits non-zero" {
  _write_json '{"title":"Not an array"}'
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
}
@test "add --import: invalid JSON exits non-zero" {
  printf 'not json at all' > tickets.json
  run atoshell add --import tickets.json
  [ "$status" -ne 0 ]
}

# ── 16. --import fixture file ─────────────────────────────────────────────
@test "add --import: import_example fixture creates correct ticket count" {
  run atoshell add --import "$ATOSHELL_REPO/tests/fixtures/import_example.json"
  [ "$status" -eq 0 ]
  q=$(jq '.tickets | length' .atoshell/queue.json)
  b=$(jq '.tickets | length' .atoshell/backlog.json)
  # fixture starts with 3 queue tickets; 2 more (Defaults + Bug) added = 5
  [ "$q" -eq 5 ]
  # fixture starts with 1 backlog ticket; 1 more (Backlog task) added = 2
  [ "$b" -eq 2 ]
}
@test "add --import: import_example fixture stores field values correctly" {
  run atoshell add --import "$ATOSHELL_REPO/tests/fixtures/import_example.json"
  [ "$status" -eq 0 ]
  tp=$(jq -r '.tickets[] | select(.title=="[fixture] Bug ticket") | .type' .atoshell/queue.json)
  [ "$tp" = "Bug" ]
}
# ── 17. --json output ────────────────────────────────────────────────────────
@test "add --json: exits 0" {
  run atoshell add "JSON test ticket" --body "desc" --json
  [ "$status" -eq 0 ]
}
@test "add --json: output is valid JSON" {
  run atoshell add "JSON test ticket" --body "desc" --json
  [ "$status" -eq 0 ]
  jq -e '.' <<< "$output" > /dev/null
}
@test "add --json: output contains correct title" {
  run atoshell add "JSON test ticket" --body "desc" --json
  [ "$status" -eq 0 ]
  title=$(jq -r '.title' <<< "$output")
  [ "$title" = "JSON test ticket" ]
}
@test "add --json: preserves raw terminal control sequences in title" {
  run atoshell add $'JSON \e]52;c;SGVsbG8=\aTitle' --body "desc" --json
  [ "$status" -eq 0 ]
  title=$(jq -r '.title' <<< "$output")
  [[ "$title" == *$'\e'* ]]
  [[ "$title" == *$'\a'* ]]
}
@test "add --json: output contains numeric id" {
  run atoshell add "JSON test ticket" --body "desc" --json
  [ "$status" -eq 0 ]
  id=$(jq -r '.id' <<< "$output")
  [[ "$id" =~ ^[0-9]+$ ]]
}
@test "add --json: output contains status field" {
  run atoshell add "JSON test ticket" --body "desc" --json
  [ "$status" -eq 0 ]
  st=$(jq -r '.status' <<< "$output")
  [ -n "$st" ]
}
@test "add --json: honours --type flag in output" {
  run atoshell add "JSON test ticket" --body "desc" --type Bug --json
  [ "$status" -eq 0 ]
  tp=$(jq -r '.type' <<< "$output")
  [ "$tp" = "Bug" ]
}
@test "add --json: --import outputs a JSON array" {
  run atoshell add --import "$ATOSHELL_REPO/tests/fixtures/import_example.json" --json
  [ "$status" -eq 0 ]
  t=$(jq -r 'type' <<< "$output")
  [ "$t" = "array" ]
}
@test "add --json: --import array length matches import count" {
  run atoshell add --import "$ATOSHELL_REPO/tests/fixtures/import_example.json" --json
  [ "$status" -eq 0 ]
  len=$(jq 'length' <<< "$output")
  [ "$len" -eq 3 ]
}
@test "add --json: file not found emits FILE_NOT_FOUND error code" {
  run_split atoshell add --import /no/such/file.json --json
  assert_json_error_split "FILE_NOT_FOUND"
}
@test "add --json: file not found error is valid JSON" {
  run_split atoshell add --import /no/such/file.json --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "FILE_NOT_FOUND" ]
}
@test "add --json: invalid format emits INVALID_FORMAT error code" {
  printf '{"title":"not an array"}' > tickets.json
  run_split atoshell add --import tickets.json --json
  assert_json_error_split "INVALID_FORMAT"
}
@test "add --json: invalid JSON emits INVALID_JSON error code" {
  printf 'not json at all' > tickets.json
  run_split atoshell add --import tickets.json --json
  assert_json_error_split "INVALID_JSON"
}
@test "add --json: validation failure emits VALIDATION_FAILED error code" {
  printf '[{"description":"no title"}]' > tickets.json
  run_split atoshell add --import tickets.json --json
  assert_json_error_split "VALIDATION_FAILED"
}
@test "add --json: validation failure error is valid JSON" {
  printf '[{"description":"no title"}]' > tickets.json
  run_split atoshell add --import tickets.json --json
  [ "$status" -ne 0 ]
  err=$(jq -r '.error' "$BATS_TEST_TMPDIR/stderr")
  [ "$err" = "VALIDATION_FAILED" ]
}
@test "add --json: validation failure error includes count field" {
  printf '[{"description":"A"},{"description":"B"}]' > tickets.json
  run_split atoshell add --import tickets.json --json
  [ "$status" -ne 0 ]
  count=$(jq -r '.count' "$BATS_TEST_TMPDIR/stderr")
  [ "$count" -eq 2 ]
}
@test "add --json: validation failure error includes errors array" {
  printf '[{"description":"no title"}]' > tickets.json
  run_split atoshell add --import tickets.json --json
  [ "$status" -ne 0 ]
  len=$(jq '.errors | length' "$BATS_TEST_TMPDIR/stderr")
  [ "$len" -ge 1 ]
}
# ── --help flag ──────────────────────────────────────────────────────────────
@test "add --help: exits 0" {
  run atoshell add --help
  [ "$status" -eq 0 ]
}
@test "add --help: output contains Usage" {
  run atoshell add --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "add --help: output lists fixed disciplines" {
  run atoshell add --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid disciplines (fixed)"* ]]
  [[ "$output" == *"Frontend, Backend"* ]]
  [[ "$output" == *"Use the narrowest accurate discipline set"* ]]
}
