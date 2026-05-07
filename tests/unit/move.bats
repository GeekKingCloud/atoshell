#!/usr/bin/env bats
# Tests for: atoshell move
#
# File routing (from _status_to_file):
#   Backlog             → backlog.json
#   Ready / In Progress → queue.json
#   Done                → done.json
#
# Fixture IDs:
#   queue   — #1 Ready, #2 In Progress, #3 Ready
#   backlog — #4 Backlog
#   done    — #5 Done

load '../helpers/setup'

# ── 1. Within-file moves (queue → queue) ──────────────────────────────────────
@test "move: exit code 0" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
}
@test "move: status updated within queue.json" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "move: within-file move does not duplicate the ticket" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "move: updated_by set on within-file move" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "[agent]" ]
}
@test "move: updated_at set on within-file move" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  at=$(jq -r '.tickets[] | select(.id==1) | .updated_at' .atoshell/queue.json)
  [ "$at" != "null" ]
  [ -n "$at" ]
}

# ── 2. Cross-file moves ───────────────────────────────────────────────────────
@test "move: queue → backlog removes ticket from queue" {
  run atoshell move 1 "Backlog"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "move: queue → backlog adds ticket to backlog" {
  run atoshell move 1 "Backlog"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}
@test "move: queue → done removes ticket from queue" {
  run atoshell move 1 "Done"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "move: queue → done adds ticket to done.json" {
  run atoshell move 1 "Done"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  [ "$count" -eq 1 ]
}
@test "move: backlog → queue removes ticket from backlog" {
  run atoshell move 4 "In Progress"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/backlog.json)
  [ "$count" -eq 0 ]
}
@test "move: backlog → queue adds ticket to queue" {
  run atoshell move 4 "In Progress"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "move: done → queue (Ready) removes ticket from done.json" {
  run atoshell move 5 "Ready"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==5)] | length' .atoshell/done.json)
  [ "$count" -eq 0 ]
}
@test "move: done → queue (Ready) adds ticket to queue" {
  run atoshell move 5 "Ready"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==5)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "move: cross-file move sets correct status on destination ticket" {
  run atoshell move 4 "Ready"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==4) | .status' .atoshell/queue.json)
  [ "$st" = "Ready" ]
}
@test "move: cross-file move sets updated_by on destination ticket" {
  run atoshell move 4 "Ready"
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==4) | .updated_by' .atoshell/queue.json)
  [ "$by" = "[agent]" ]
}
@test "move: --as stamps updated_by to named agent" {
  run atoshell move 1 "In Progress" --as agent-1
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "agent-1" ]
}
@test "move: --as numeric shorthand normalizes to agent-N" {
  run atoshell move 1 "In Progress" --as 10
  [ "$status" -eq 0 ]
  by=$(jq -r '.tickets[] | select(.id==1) | .updated_by' .atoshell/queue.json)
  [ "$by" = "agent-10" ]
}
@test "move: --as rejects arbitrary names" {
  run atoshell move 1 "In Progress" --as alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}
@test "move: unrelated tickets in source file are preserved" {
  run atoshell move 1 "Done"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

# ── 3. Column number syntax ───────────────────────────────────────────────────
@test "move: column 1 maps to Backlog" {
  run atoshell move 1 1
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}
@test "move: column 2 maps to Ready" {
  run atoshell move 2 2
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==2) | .status' .atoshell/queue.json)
  [ "$st" = "Ready" ]
}
@test "move: column 3 maps to In Progress" {
  run atoshell move 1 3
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "move: column 4 maps to Done" {
  run atoshell move 1 4
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  [ "$count" -eq 1 ]
}

# ── 4. Multi-word status without quotes ───────────────────────────────────────
@test "move: multi-word status 'in progress' without quotes" {
  run atoshell move 1 in progress
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "move: multi-word removed status 'in review' exits non-zero" {
  run atoshell move 1 in review
  [ "$status" -ne 0 ]
}

# ── 5. Multi-ID (comma-separated) ─────────────────────────────────────────────
@test "move: comma-separated IDs both updated" {
  run atoshell move 1,2 "Done"
  [ "$status" -eq 0 ]
  c1=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  c2=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/done.json)
  [ "$c1" -eq 1 ]
  [ "$c2" -eq 1 ]
}
@test "move: comma-separated IDs across files" {
  run atoshell move 1,4 "Done"
  [ "$status" -eq 0 ]
  c1=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  c4=$(jq '[.tickets[] | select(.id==4)] | length' .atoshell/done.json)
  [ "$c1" -eq 1 ]
  [ "$c4" -eq 1 ]
}
@test "move: comma-separated IDs leaves unmentioned tickets untouched" {
  run atoshell move 1,2 "Done"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==3)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "move: comma-separated IDs from one file keep both ticket titles in output" {
  run atoshell move 1,2 "Done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix login bug"* ]]
  [[ "$output" == *"Add dark mode"* ]]
}
@test "move: comma-separated duplicate ID exits non-zero before writing state" {
  run atoshell move 1,1 "Done"
  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate ticket ID #1"* ]]
  c1_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  c1_queue=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$c1_done" -eq 0 ]
  [ "$c1_queue" -eq 1 ]
}
@test "move: comma-separated empty ID segment exits non-zero before writing state" {
  run atoshell move 1,,2 "Done"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty ticket ID"* ]]
  c1_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  c2_done=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/done.json)
  [ "$c1_done" -eq 0 ]
  [ "$c2_done" -eq 0 ]
}
@test "move: comma-separated leading empty ID exits non-zero before writing state" {
  run atoshell move ,1 "Done"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty ticket ID"* ]]
  c1_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  [ "$c1_done" -eq 0 ]
}
@test "move: comma-separated trailing empty ID exits non-zero before writing state" {
  run atoshell move 1, "Done"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty ticket ID"* ]]
  c1_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  [ "$c1_done" -eq 0 ]
}
@test "move: later missing ID rolls back earlier staged move" {
  run atoshell move 1,999 "Done"
  [ "$status" -ne 0 ]
  c1_done=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/done.json)
  c1_queue=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$c1_done" -eq 0 ]
  [ "$c1_queue" -eq 1 ]
}

# ── 6. Output content ─────────────────────────────────────────────────────────
@test "move: output contains [OK]" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
}
@test "move: output contains the ticket ID" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}
@test "move: output contains the destination status" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"In Progress"* ]]
}

# ── 7. Error cases ────────────────────────────────────────────────────────────
@test "move: no arguments exits non-zero" {
  run atoshell move
  [ "$status" -ne 0 ]
}
@test "move: no status argument exits non-zero" {
  run atoshell move 1
  [ "$status" -ne 0 ]
}
@test "move: nonexistent ticket ID exits non-zero" {
  run atoshell move 999 "Ready"
  [ "$status" -ne 0 ]
}
@test "move: unknown status exits non-zero" {
  run atoshell move 1 "Nonsense"
  [ "$status" -ne 0 ]
}

# ── 8. Command aliases ────────────────────────────────────────────────────────
@test "move: ido alias works" {
  run atoshell ido 1 "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}
@test "move: shift alias works" {
  run atoshell shift 1 "In Progress"
  [ "$status" -eq 0 ]
  st=$(jq -r '.tickets[] | select(.id==1) | .status' .atoshell/queue.json)
  [ "$st" = "In Progress" ]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "move --help: exits 0" {
  run atoshell move --help
  [ "$status" -eq 0 ]
}
@test "move --help: output contains Usage" {
  run atoshell move --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
