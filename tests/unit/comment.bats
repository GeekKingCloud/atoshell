#!/usr/bin/env bats
# Tests for: atoshell comment
#
# Non-interactive constraint:
#   add    — positional text after ticket ID skips _require_tty
#   delete — always non-interactive
#   update — inline text after comm_id skips _require_tty
#   TTY gate — triggered when text is absent and stdin is not a TTY → exit 1
#
# Fixture state:
#   Ticket #1 (queue)   — 0 comments
#   Ticket #2 (queue)   — 1 comment {author:"lyra", text:"Design spec attached"}
#   Ticket #4 (backlog) — 0 comments
#   Ticket #5 (done) — 0 comments

load '../helpers/setup'

# ── 1. Add — basic ────────────────────────────────────────────────────────────
@test "comment add: exit code 0" {
  run atoshell comment 1 "hello world"
  [ "$status" -eq 0 ]
}

@test "comment add: comment appears in ticket's .comments array" {
  run atoshell comment 1 "check comment"
  [ "$status" -eq 0 ]
  count=$(jq '[.tickets[] | select(.id==1) | .comments[] | select(.text=="check comment")] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "comment add: .text stored correctly" {
  run atoshell comment 1 "stored text"
  [ "$status" -eq 0 ]
  text=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].text' .atoshell/queue.json)
  [ "$text" = "stored text" ]
}

@test "comment add: .author is [agent] when stdin is not a TTY" {
  run atoshell comment 1 "author check"
  [ "$status" -eq 0 ]
  author=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].author' .atoshell/queue.json)
  [ "$author" = "[agent]" ]
}
@test "comment add: --as stamps named agent author" {
  run atoshell comment 1 --as agent-1 "author check"
  [ "$status" -eq 0 ]
  author=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].author' .atoshell/queue.json)
  [ "$author" = "agent-1" ]
}
@test "comment add: --as numeric shorthand normalizes to agent-N" {
  run atoshell comment 1 --as 10 "author check"
  [ "$status" -eq 0 ]
  author=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].author' .atoshell/queue.json)
  [ "$author" = "agent-10" ]
}
@test "comment add: --as rejects arbitrary names" {
  run atoshell comment 1 --as alice "author check"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}

@test "comment add: .created_at is non-null" {
  run atoshell comment 1 "ts check"
  [ "$status" -eq 0 ]
  ts=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].created_at' .atoshell/queue.json)
  [ -n "$ts" ]
  [ "$ts" != "null" ]
}

@test "comment add: works on queue ticket (#1)" {
  run atoshell comment 1 "queue comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==1) | .comments | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
}

@test "comment add: works on backlog ticket (#4)" {
  run atoshell comment 4 "backlog comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==4) | .comments | length' .atoshell/backlog.json)
  [ "$count" -eq 1 ]
}

@test "comment add: works on done ticket (#5)" {
  run atoshell comment 5 "done comment"
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==5) | .comments | length' .atoshell/done.json)
  [ "$count" -eq 1 ]
}

@test "comment add: multi-word positional args concatenated with space" {
  run atoshell comment 1 hello world foo
  [ "$status" -eq 0 ]
  text=$(jq -r '.tickets[] | select(.id==1) | .comments[-1].text' .atoshell/queue.json)
  [ "$text" = "hello world foo" ]
}

# ── 2. Add — error paths ──────────────────────────────────────────────────────
@test "comment add: no ticket ID exits 1" {
  run atoshell comment
  [ "$status" -eq 1 ]
}

@test "comment add: non-numeric ID exits 1" {
  run atoshell comment abc "some text"
  [ "$status" -eq 1 ]
}

@test "comment add: non-existent ticket exits non-zero" {
  run atoshell comment 999 "some text"
  [ "$status" -ne 0 ]
}

@test "comment add: no text without TTY exits 1" {
  run atoshell comment 1
  [ "$status" -eq 1 ]
}

# ── 3. Delete — basic ─────────────────────────────────────────────────────────
# Ticket #2 has 1 fixture comment: {author:"lyra", text:"Design spec attached"}

@test "comment delete: exit code 0" {
  run atoshell comment 2 delete 1
  [ "$status" -eq 0 ]
}

@test "comment delete: comment count decrements" {
  run atoshell comment 2 delete 1
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==2) | .comments | length' .atoshell/queue.json)
  [ "$count" -eq 0 ]
}

@test "comment delete: correct comment removed, other remains" {
  # Add a second comment so ticket #2 has two total
  atoshell comment 2 "second comment"
  # Delete comment #1 (the fixture lyra comment)
  run atoshell comment 2 delete 1
  [ "$status" -eq 0 ]
  count=$(jq '.tickets[] | select(.id==2) | .comments | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
  text=$(jq -r '.tickets[] | select(.id==2) | .comments[0].text' .atoshell/queue.json)
  [ "$text" = "second comment" ]
}

# ── 4. Delete — error paths ───────────────────────────────────────────────────
@test "comment delete: comm_id out of range exits 1" {
  run atoshell comment 2 delete 99
  [ "$status" -eq 1 ]
}

@test "comment delete: comm_id 0 exits 1" {
  run atoshell comment 2 delete 0
  [ "$status" -eq 1 ]
}

@test "comment delete: non-numeric comm_id exits 1" {
  run atoshell comment 2 delete abc
  [ "$status" -eq 1 ]
  [[ "$output" == *"comment number must be"* ]]
}

# ── 5. Update — basic ─────────────────────────────────────────────────────────
@test "comment update: exit code 0" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1 "updated text"
  [ "$status" -eq 0 ]
}

@test "comment update: .text changed to new value" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1 "new value"
  [ "$status" -eq 0 ]
  text=$(jq -r '.tickets[] | select(.id==1) | .comments[0].text' .atoshell/queue.json)
  [ "$text" = "new value" ]
}

@test "comment update: .updated_at is set on the comment" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1 "updated text"
  [ "$status" -eq 0 ]
  updated_at=$(jq -r '.tickets[] | select(.id==1) | .comments[0].updated_at' .atoshell/queue.json)
  [ -n "$updated_at" ]
  [ "$updated_at" != "null" ]
}

# ── 6. Update — error paths ───────────────────────────────────────────────────
@test "comment update: comm_id out of range exits 1" {
  run atoshell comment 1 edit 99 "new text"
  [ "$status" -eq 1 ]
}

@test "comment update: non-numeric comm_id exits 1" {
  run atoshell comment 1 edit abc "new text"
  [ "$status" -eq 1 ]
  [[ "$output" == *"comment number must be"* ]]
}

@test "comment update: no inline text without TTY exits 1" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1
  [ "$status" -eq 1 ]
}

# ── 7. Output content ─────────────────────────────────────────────────────────
@test "comment add: output contains ticket ID (#1)" {
  run atoshell comment 1 "output check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#1"* ]]
}

@test "comment add: output contains author name" {
  run atoshell comment 1 "output check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[agent]"* ]]
}
@test "comment edit: --as is rejected with cleanup message" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1 --as agent-1 "new text"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as only applies when adding a new comment"* ]]
}
@test "comment delete: --as is rejected with cleanup message" {
  run atoshell comment 2 delete 1 --as agent-1
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as only applies when adding a new comment"* ]]
}

@test "comment delete: output contains 'deleted'" {
  run atoshell comment 2 delete 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted"* ]]
}

@test "comment update: output contains 'updated'" {
  atoshell comment 1 "original text"
  run atoshell comment 1 edit 1 "new text"
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated"* ]]
}

# ── --help flag ──────────────────────────────────────────────────────────────
@test "comment --help: exits 0" {
  run atoshell comment --help
  [ "$status" -eq 0 ]
}
@test "comment --help: output contains Usage" {
  run atoshell comment --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
