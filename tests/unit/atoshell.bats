#!/usr/bin/env bats
# Tests for: atoshell.sh dispatcher
#
# Covers: help output, unknown-command error, no-arg non-interactive error,
# --quiet/-q global flag, and command-level aliases not tested in individual
# command suites (tasu/fab/new, kesu/wipe, kaku/mark/note, toru/snatch).

load '../helpers/setup'

# ── 1. help ───────────────────────────────────────────────────────────────────
@test "atoshell help: exit code 0" {
  run atoshell help
  [ "$status" -eq 0 ]
}
@test "atoshell help: output contains 'Usage'" {
  run atoshell help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "atoshell help: output lists key commands" {
  run atoshell help
  [ "$status" -eq 0 ]
  [[ "$output" == *"add"* ]]
  [[ "$output" == *"show"* ]]
  [[ "$output" == *"list"* ]]
}
@test "atoshell help: move help references columns 1-4" {
  run atoshell help
  [ "$status" -eq 0 ]
  [[ "$output" == *"column 1-4"* ]]
  [[ "$output" != *"column 1-5"* ]]
}
@test "atoshell --help: exit code 0" {
  run atoshell --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "atoshell -h: exit code 0" {
  run atoshell -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "atoshell version: prints repo version" {
  run atoshell version
  [ "$status" -eq 0 ]
  [ "$output" = "atoshell 2.0.0" ]
}
@test "atoshell --version: prints repo version" {
  run atoshell --version
  [ "$status" -eq 0 ]
  [ "$output" = "atoshell 2.0.0" ]
}
@test "atoshell -v: prints repo version" {
  run atoshell -v
  [ "$status" -eq 0 ]
  [ "$output" = "atoshell 2.0.0" ]
}
@test "repo bin/atoshell wrapper routes to dispatcher" {
  run bash "$ATOSHELL_REPO/bin/atoshell" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
@test "repo bin/ato wrapper routes to dispatcher" {
  run bash "$ATOSHELL_REPO/bin/ato" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. Unknown command ────────────────────────────────────────────────────────
@test "atoshell unknown command: exits non-zero" {
  run atoshell foobar_unknown
  [ "$status" -ne 0 ]
}
@test "atoshell unknown command: output mentions the unknown command" {
  run atoshell foobar_unknown
  [[ "$output" == *"foobar_unknown"* ]] || [[ "$output" == *"Unknown"* ]]
}

# ── 3. No-arg non-interactive mode ────────────────────────────────────────────
@test "atoshell (no args, no TTY): exits non-zero" {
  run atoshell
  [ "$status" -ne 0 ]
}
@test "atoshell (no args, no TTY): output mentions command is required" {
  run atoshell
  [[ "$output" == *"command"* ]] || [[ "$output" == *"non-interactive"* ]]
}

# ── 4. --quiet / -q global flag ───────────────────────────────────────────────
@test "atoshell move (no --quiet): output contains [OK]" {
  run atoshell move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
}
@test "atoshell --quiet move: suppresses [OK] output" {
  run atoshell --quiet move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[OK]"* ]]
}
@test "atoshell -q move: short flag suppresses [OK] output" {
  run atoshell -q move 1 "In Progress"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[OK]"* ]]
}
@test "atoshell move --quiet: trailing quiet flag also suppresses output" {
  run atoshell move 1 "In Progress" --quiet
  [ "$status" -eq 0 ]
  [[ "$output" != *"[OK]"* ]]
}

# ── 5. add aliases ────────────────────────────────────────────────────────────
@test "atoshell tasu: routes to add" {
  run atoshell tasu "Tasu ticket" --body "desc"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Tasu ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "atoshell fab: routes to add" {
  run atoshell fab "Fab ticket" --body "desc"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Fab ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "atoshell new: routes to add" {
  run atoshell new "New ticket" --body "desc"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="New ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}
@test "atoshell open: routes to add" {
  run atoshell open "Open ticket" --body "desc"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.title=="Open ticket")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

# ── 6. delete aliases ─────────────────────────────────────────────────────────
@test "atoshell kesu: routes to delete" {
  run atoshell kesu 1 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}
@test "atoshell wipe: routes to delete" {
  run atoshell wipe 2 --yes
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==2)] | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}

# ── 7. comment aliases ────────────────────────────────────────────────────────
@test "atoshell kaku: routes to comment" {
  run atoshell kaku 1 "Kaku comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .comments | length' .atoshell/queue.json)
  [ "$count" -ge 1 ]
}
@test "atoshell mark: routes to comment" {
  run atoshell mark 1 "Mark comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .comments | length' .atoshell/queue.json)
  [ "$count" -ge 1 ]
}
@test "atoshell note: routes to comment" {
  run atoshell note 1 "Note comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .comments | length' .atoshell/queue.json)
  [ "$count" -ge 1 ]
}
