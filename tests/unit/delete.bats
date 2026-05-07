#!/usr/bin/env bats
# Tests for: atoshell delete
#
# All non-interactive: --yes/-y bypasses the ask_yn confirmation prompt.
# setup() copies fresh fixtures before every test so deletions do not
# accumulate across tests.
#
# Fixture IDs:
#   #1 #2 #3 → queue.json   #4 → backlog.json   #5 → done.json

load '../helpers/setup'

# ── 1. Basic delete ───────────────────────────────────────────────────────────
@test "delete: exit code 0" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
}
@test "delete: removes queue ticket (#1)" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "delete: removes queue ticket (#2)" {
  run atoshell delete 2 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "delete: removes backlog ticket (#4)" {
  run atoshell delete 4 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/backlog.json)
  [ "$count" -eq 0 ]
}
@test "delete: removes done ticket (#5)" {
  run atoshell delete 5 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==5)] | length' .atoshell/done.json)
  [ "$count" -eq 0 ]
}

# ── 2. Other tickets unaffected ───────────────────────────────────────────────
@test "delete: sibling queue ticket remains" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "delete: queue delete does not affect backlog" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}
@test "delete: queue delete does not affect done.json" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==5)] | length' .atoshell/done.json)
  [ "$count" -eq 1 ]
}

# ── 3. Multi-delete (comma-separated) ─────────────────────────────────────────
@test "delete: comma-separated IDs removes both" {
  run atoshell delete 1,2 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1 or .id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "delete: comma-separated IDs across files" {
  run atoshell delete 1,4 --yes
  [ "$status" -eq 0 ]
  q=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  b=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/backlog.json)
  [ "$q" -eq 0 ]
  [ "$b" -eq 0 ]
}
@test "delete: comma-separated IDs leaves untouched ticket intact" {
  run atoshell delete 1,2 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==3)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "delete: spaced comma list '1, 2' parsed correctly" {
  run atoshell delete "1, 2" --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1 or .id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "delete: all three files in one call" {
  run atoshell delete 1,4,5 --yes
  [ "$status" -eq 0 ]
  q=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  b=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/backlog.json)
  a=$(jq '[.tickets[] | select(.id==5)] | length' .atoshell/done.json)
  [ "$q" -eq 0 ]
  [ "$b" -eq 0 ]
  [ "$a" -eq 0 ]
}

# ── 4. Flag aliases ───────────────────────────────────────────────────────────
@test "delete: -y short flag bypasses confirmation" {
  run atoshell delete 1 -y
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}

# ── 5. Output content ─────────────────────────────────────────────────────────
@test "delete: output contains 'Deleted'" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleted"* ]]
}
@test "delete: output contains ticket ID" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "delete: multi-delete output contains both IDs" {
  run atoshell delete 1,2 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
  [[ "$output" == *"#2"* ]]
}

# ── 6. Error paths ────────────────────────────────────────────────────────────
@test "delete: no ID argument exits 1" {
  run atoshell delete
  [ "$status" -eq 1 ]
}
@test "delete: only --yes flag (no ID) exits 1" {
  run atoshell delete --yes
  [ "$status" -eq 1 ]
}
@test "delete: non-numeric ID exits 1" {
  run atoshell delete abc --yes
  [ "$status" -eq 1 ]
}
@test "delete: non-existent ticket exits non-zero" {
  run atoshell delete 999 --yes
  [ "$status" -ne 0 ]
}
@test "delete: multi-delete continues past missing ticket and deletes found ones" {
  run atoshell delete 999,1 --yes
  count=$(jq '[.tickets[] | select(.id == 1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "delete: multi-delete with missing ticket still reports the missing ID" {
  run atoshell delete 999,1 --yes
  [[ "$output" == *"#999"* ]]
}
@test "delete: comma list with non-numeric ID exits 1" {
  run atoshell delete 1,abc --yes
  [ "$status" -eq 1 ]
}

# ── 7. Dependency cleanup ─────────────────────────────────────────────────────
# Fixture: ticket #3 depends on #1
@test "delete: warns when deleted ticket has dependents" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"#3"* ]]
}
@test "delete: --yes auto-removes dependency from dependent ticket" {
  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]
  deps=$(jq '[.tickets[] | select(.id==3) | .dependencies[]] | length' .atoshell/queue.json)
  [ "$deps" -eq 0 ]
}
@test "delete: no dependency warning when ticket has no dependents" {
  run atoshell delete 2 --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"depends on"* ]]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "delete --help: exits 0" {
  run atoshell delete --help
  [ "$status" -eq 0 ]
}
@test "delete --help: output contains Usage" {
  run atoshell delete --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
