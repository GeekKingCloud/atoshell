#!/usr/bin/env bats
# Tests for: atoshell edit
#
# Fixture IDs:
#   queue   — #1 P1/S/Ready "Fix login bug", #2 P2/M/In Progress "Add dark mode",
#             #3 P3/XS/Ready "Update API docs"
#   backlog — #4 P2/XL/Backlog "Migrate to Postgres"
#   done    — #5 P0/S/Done "Initial project setup"

load '../helpers/setup'

# ── 1. Error cases ────────────────────────────────────────────────────────────
@test "edit: no id prints usage and exits 1" {
  run atoshell edit
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
@test "edit: unknown ticket id exits non-zero" {
  run atoshell edit 999 --title "nope"
  [ "$status" -ne 0 ]
}
@test "edit: no changes specified exits 1" {
  run atoshell edit 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"no changes"* ]]
}
@test "edit: unknown flag exits 1" {
  run atoshell edit 1 --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"unknown flag"* ]]
}
@test "edit: flag passed as id exits 1 with usage" {
  run atoshell edit --title "foo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"Usage:"* ]]
}
@test "edit: invalid priority exits 1" {
  run atoshell edit 1 --priority ZZ
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
}
@test "edit: invalid size exits 1" {
  run atoshell edit 1 --size XXL
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
}

# ── 2. --title / -T ───────────────────────────────────────────────────────────
@test "edit: --title sets ticket title" {
  run atoshell edit 1 --title "New title"
  [ "$status" -eq 0 ]
  title=$(jq -r '.tickets[] | select(.id==1) | .title' .atoshell/queue.json)
  [ "$title" = "New title" ]
}
@test "edit: -T short flag sets title" {
  run atoshell edit 1 -T "new title via -T"
  [ "$status" -eq 0 ]
  title=$(jq -r '.tickets[] | select(.id==1) | .title' .atoshell/queue.json)
  [ "$title" = "new title via -T" ]
}
@test "edit: human output strips terminal control sequences from title" {
  run atoshell edit 1 --title $'Danger \e]52;c;SGVsbG8=\aTitle'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Danger Title"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "edit: accountable remove warning strips terminal control sequences" {
  run atoshell edit 1 --accountable remove $'bad\e]52;c;SGVsbG8=\auser'
  [ "$status" -eq 0 ]
  [[ "$output" == *"baduser"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

# ── 3. --description / --desc / --body / -b ───────────────────────────────────
@test "edit: --description sets description" {
  run atoshell edit 1 --description "full flag desc"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.id==1) | .description' .atoshell/queue.json)
  [ "$desc" = "full flag desc" ]
}
@test "edit: --desc alias sets description" {
  run atoshell edit 1 --desc "updated via desc alias"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.id==1) | .description' .atoshell/queue.json)
  [ "$desc" = "updated via desc alias" ]
}
@test "edit: --body alias sets description" {
  run atoshell edit 1 --body "via body alias"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.id==1) | .description' .atoshell/queue.json)
  [ "$desc" = "via body alias" ]
}
@test "edit: -b short flag sets description" {
  run atoshell edit 1 -b "via -b flag"
  [ "$status" -eq 0 ]
  desc=$(jq -r '.tickets[] | select(.id==1) | .description' .atoshell/queue.json)
  [ "$desc" = "via -b flag" ]
}

# ── 4. --type / --kind / -t ───────────────────────────────────────────────────
@test "edit: --type sets ticket type" {
  run atoshell edit 1 --type Bug
  [ "$status" -eq 0 ]
  type=$(jq -r '.tickets[] | select(.id==1) | .type' .atoshell/queue.json)
  [ "$type" = "Bug" ]
}
@test "edit: --kind alias sets type" {
  run atoshell edit 1 --kind Feature
  [ "$status" -eq 0 ]
  type=$(jq -r '.tickets[] | select(.id==1) | .type' .atoshell/queue.json)
  [ "$type" = "Feature" ]
}
@test "edit: -t short flag sets type" {
  run atoshell edit 1 -t Bug
  [ "$status" -eq 0 ]
  type=$(jq -r '.tickets[] | select(.id==1) | .type' .atoshell/queue.json)
  [ "$type" = "Bug" ]
}
@test "edit: --type 0 resolves to Bug" {
  run atoshell edit 1 --type 0
  [ "$status" -eq 0 ]
  type=$(jq -r '.tickets[] | select(.id==1) | .type' .atoshell/queue.json)
  [ "$type" = "Bug" ]
}
@test "edit: --type 1 resolves to Feature" {
  run atoshell edit 1 --type 1
  [ "$status" -eq 0 ]
  type=$(jq -r '.tickets[] | select(.id==1) | .type' .atoshell/queue.json)
  [ "$type" = "Feature" ]
}

# ── 5. --priority / -p ────────────────────────────────────────────────────────
@test "edit: --priority sets priority" {
  run atoshell edit 1 --priority P0
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P0" ]
}
@test "edit: -p short flag sets priority" {
  run atoshell edit 1 -p P3
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P3" ]
}
@test "edit: priority is case-insensitive" {
  run atoshell edit 1 --priority p2
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P2" ]
}
@test "edit: --priority 0 resolves to P0" {
  run atoshell edit 1 --priority 0
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P0" ]
}
@test "edit: --priority 3 resolves to P3" {
  run atoshell edit 1 --priority 3
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P3" ]
}

# ── 6. --size / -s ────────────────────────────────────────────────────────────
@test "edit: --size sets size" {
  run atoshell edit 1 --size XL
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.id==1) | .size' .atoshell/queue.json)
  [ "$sz" = "XL" ]
}
@test "edit: -s short flag sets size" {
  run atoshell edit 1 -s M
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.id==1) | .size' .atoshell/queue.json)
  [ "$sz" = "M" ]
}
@test "edit: size is case-insensitive" {
  run atoshell edit 1 --size xl
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.id==1) | .size' .atoshell/queue.json)
  [ "$sz" = "XL" ]
}
@test "edit: --size 0 resolves to XS" {
  run atoshell edit 1 --size 0
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.id==1) | .size' .atoshell/queue.json)
  [ "$sz" = "XS" ]
}
@test "edit: --size 4 resolves to XL" {
  run atoshell edit 1 --size 4
  [ "$status" -eq 0 ]
  sz=$(jq -r '.tickets[] | select(.id==1) | .size' .atoshell/queue.json)
  [ "$sz" = "XL" ]
}

# ── 7. --status / --move / -S ─────────────────────────────────────────────────
@test "edit: --status moves ticket within queue" {
  run atoshell edit 1 --status "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "edit: --move alias works" {
  run atoshell edit 1 --move "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "edit: -S short flag moves ticket" {
  run atoshell edit 1 -S "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "edit: --status multi-word without quotes" {
  run atoshell edit 1 --status In Progress
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "edit: --status Done moves ticket to done.json" {
  run atoshell edit 1 --status Done
  [ "$status" -eq 0 ]
  in_queue=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  in_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  [ "$in_queue" -eq 0 ]
  [ "$in_done" -eq 1 ]
}

# ── 8. --disciplines ──────────────────────────────────────────────────────────
@test "edit: --dis without subcommand defaults to add" {
  run atoshell edit 1 --dis Backend
  [ "$status" -eq 0 ]
  present=$(jq '.tickets[] | select(.id==1) | .disciplines | map(ascii_downcase) | any(. == "backend")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: -d without subcommand defaults to add" {
  run atoshell edit 1 -d Frontend
  [ "$status" -eq 0 ]
  present=$(jq '.tickets[] | select(.id==1) | .disciplines | map(ascii_downcase) | any(. == "frontend")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: -d short flag sets disciplines" {
  run atoshell edit 1 -d add Frontend
  [ "$status" -eq 0 ]
  disc=$(jq -r '.tickets[] | select(.id==1) | .disciplines[0]' .atoshell/queue.json)
  [ "$disc" = "Frontend" ]
}
@test "edit: --dis add explicit works" {
  run atoshell edit 1 --dis add Backend
  [ "$status" -eq 0 ]
  present=$(jq '.tickets[] | select(.id==1) | .disciplines | map(ascii_downcase) | any(. == "backend")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: --dis remove works" {
  run atoshell edit 1 --dis add Frontend
  run atoshell edit 1 --dis remove Frontend
  [ "$status" -eq 0 ]
  present=$(jq '.tickets[] | select(.id==1) | .disciplines | map(ascii_downcase) | any(. == "frontend")' .atoshell/queue.json)
  [ "$present" = "false" ]
}
@test "edit: --dis clear removes all disciplines" {
  run atoshell edit 1 --dis add Frontend
  run atoshell edit 1 --dis clear
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .disciplines | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "edit: --dis remove warns if discipline not on ticket" {
  run atoshell edit 1 --dis remove Backend
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
}
@test "edit: --dis comma-separated adds multiple" {
  run atoshell edit 1 --dis Frontend,Backend
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .disciplines | length' .atoshell/queue.json)
  [ "$count" -ge 2 ]
}

# ── 9. --accountable ──────────────────────────────────────────────────────────
@test "edit: --accountable without subcommand defaults to add" {
  run atoshell edit 1 --accountable lyra
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "lyra")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: -a without subcommand defaults to add" {
  run atoshell edit 1 -a will
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "will")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: --assign alias works" {
  run atoshell edit 1 --assign lyra
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "lyra")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: --accountable add explicit works" {
  run atoshell edit 1 --accountable add lyra
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "lyra")' .atoshell/queue.json)
  [ "$present" = "true" ]
}
@test "edit: --accountable remove works" {
  run atoshell edit 1 --accountable add lyra
  run atoshell edit 1 --accountable remove lyra
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "lyra")' .atoshell/queue.json)
  [ "$present" = "false" ]
}
@test "edit: --accountable clear removes all" {
  run atoshell edit 1 --accountable add lyra
  run atoshell edit 1 --accountable clear
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .accountable | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "edit: --accountable remove warns if not on ticket" {
  run atoshell edit 1 --accountable remove nobody
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
}
@test "edit: --accountable me expands to current user" {
  run atoshell edit 1 --accountable me
  [ "$status" -eq 0 ]
  present=$(jq -r '.tickets[] | select(.id==1) | .accountable | any(. == "testuser")' .atoshell/queue.json)
  [ "$present" = "true" ]
}

# ── 10. --dependencies ────────────────────────────────────────────────────────
@test "edit: --depends without subcommand defaults to add" {
  run atoshell edit 1 --depends 2
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 2)' .atoshell/queue.json)
  [ "$dep" = "true" ]
}
@test "edit: -D without subcommand defaults to add" {
  run atoshell edit 1 -D 4
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 4)' .atoshell/queue.json)
  [ "$dep" = "true" ]
}
@test "edit: --dependency alias works" {
  run atoshell edit 1 --dependency 2
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 2)' .atoshell/queue.json)
  [ "$dep" = "true" ]
}
@test "edit: -D short flag adds dependency" {
  run atoshell edit 1 -D add 2
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 2)' .atoshell/queue.json)
  [ "$dep" = "true" ]
}
@test "edit: --depends add explicit works" {
  run atoshell edit 1 --depends add 2
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 2)' .atoshell/queue.json)
  [ "$dep" = "true" ]
}
@test "edit: --depends remove works" {
  run atoshell edit 1 --depends add 2
  run atoshell edit 1 --depends remove 2
  [ "$status" -eq 0 ]
  dep=$(jq '.tickets[] | select(.id==1) | .dependencies | any(. == 2)' .atoshell/queue.json)
  [ "$dep" = "false" ]
}
@test "edit: --depends clear removes all dependencies" {
  run atoshell edit 1 --depends add 2
  run atoshell edit 1 --depends clear
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .dependencies | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "edit: --depends remove warns if not on ticket" {
  run atoshell edit 1 --depends remove 99
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
}
@test "edit: dependency add rejects newly created cycles" {
  printf '{"tickets":[
    {"id":1,"title":"A","status":"Ready","priority":"P1","size":"S","dependencies":[],"comments":[]},
    {"id":2,"title":"B","status":"Ready","priority":"P2","size":"M","dependencies":[1],"comments":[]}
  ]}' > .atoshell/queue.json
  run atoshell edit 1 --depends add 2
  [ "$status" -ne 0 ]
  [[ "$output" == *"create a cycle"* ]]
}

# ── 11. Audit fields ──────────────────────────────────────────────────────────
@test "edit: stamps updated_by and updated_at" {
  run atoshell edit 1 --priority P0
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  at=$(jq -r '.tickets[] | select(.id==1) | .updated_at' .atoshell/queue.json)
  [ "$by" = "[agent]" ]
  [[ "$at" != "null" ]]
}
@test "edit: --as stamps updated_by to named agent" {
  run atoshell edit 1 --priority P0 --as agent-1
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "agent-1" ]
}
@test "edit: --as numeric shorthand normalizes to agent-N" {
  run atoshell edit 1 --priority P0 --as 10
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "agent-10" ]
}
@test "edit: --as rejects arbitrary names" {
  run atoshell edit 1 --priority P0 --as alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}

# ── 12. Command aliases ───────────────────────────────────────────────────────
@test "edit: henshu alias works" {
  run atoshell henshu 1 --priority P0
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P0" ]
}
@test "edit: mod alias works" {
  run atoshell mod 1 --priority P3
  [ "$status" -eq 0 ]
  pri=$(jq -r '.tickets[] | select(.id==1) | .priority' .atoshell/queue.json)
  [ "$pri" = "P3" ]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "edit --help: exits 0" {
  run atoshell edit --help
  [ "$status" -eq 0 ]
}
@test "edit --help: output contains Usage" {
  run atoshell edit --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "edit --help: output lists fixed disciplines" {
  run atoshell edit --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid disciplines (fixed)"* ]]
  [[ "$output" == *"Frontend, Backend"* ]]
  [[ "$output" == *"Use the narrowest accurate discipline set"* ]]
}
