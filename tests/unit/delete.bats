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
@test "delete: confirmation prompt failure leaves no lock or transaction" {
  run atoshell delete 1
  [ "$status" -eq 1 ]
  [ ! -e .atoshell/.lock ]
  [ ! -e .atoshell/.transaction ]
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
@test "delete: --yes rechecks newly added dependent under lock" {
  real_mkdir="$(command -v mkdir)"
  real_jq="$(command -v jq)"
  marker="$BATS_TEST_TMPDIR/injected-dependent"

  cat > "$BATS_TEST_TMPDIR/bin/mkdir" <<EOF
#!/usr/bin/env bash
if [[ " \$* " == *".atoshell/.lock"* && ! -e "$marker" ]]; then
  touch "$marker"
  tmp="$TEST_PROJECT/.atoshell/queue.json.tmp"
  "$real_jq" '.tickets += [{
    "id": 6,
    "uuid": "race-dependent",
    "title": "Race dependent",
    "description": "Added while delete is acquiring the state lock",
    "status": "Ready",
    "priority": "P2",
    "size": "S",
    "type": "Task",
    "disciplines": [],
    "accountable": [],
    "dependencies": [1],
    "comments": [],
    "created_by": "testuser",
    "created_at": "2026-01-06T00:00:00Z"
  }]' "$TEST_PROJECT/.atoshell/queue.json" > "\$tmp" && mv "\$tmp" "$TEST_PROJECT/.atoshell/queue.json"
fi
exec "$real_mkdir" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/mkdir"

  run atoshell delete 1 --yes
  [ "$status" -eq 0 ]

  deleted=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$deleted" -eq 0 ]
  present=$(jq '[.tickets[] | select(.id==6)] | length' .atoshell/queue.json)
  [ "$present" -eq 1 ]
  still_depends=$(jq '.tickets[] | select(.id==6) | .dependencies | any(. == 1)' .atoshell/queue.json)
  [ "$still_depends" = "false" ]
  [[ "$output" == *"Removed dependency on #1 from #6"* ]]
  [ ! -e .atoshell/.lock ]
  [ ! -e .atoshell/.transaction ]
}
@test "delete: no dependency warning when ticket has no dependents" {
  run atoshell delete 2 --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"depends on"* ]]
}

# ── 8. JSON output ───────────────────────────────────────────────────────────
@test "delete --json: outputs deletion summary object" {
  run atoshell delete 2 --yes --json
  [ "$status" -eq 0 ]
  [[ "$output" == \{* ]]
  echo "$output" | jq -e '.deleted == [2] and .removed_dependencies == []' >/dev/null
}

@test "delete -j: short flag outputs deletion summary object" {
  run atoshell delete 2 --yes -j
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.deleted == [2]' >/dev/null
}

@test "delete --json: multi-delete includes all deleted IDs" {
  run atoshell delete 1,2 --yes --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.deleted == [1,2]' >/dev/null
}

@test "delete --json: dependency cleanup is included in summary" {
  run atoshell delete 1 --yes --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.deleted == [1] and .removed_dependencies == [{ticket_id: 3, dependency_id: 1}]' >/dev/null
}

@test "delete --json: requires --yes because prompts are human-only" {
  run_split atoshell delete 1 --json
  assert_json_error_split "INVALID_ARGUMENT"
}

@test "delete --json: missing ticket emits JSON error on stderr only" {
  run_split atoshell delete 999 --yes --json
  assert_json_error_split "TICKET_NOT_FOUND"
}

@test "delete --json: duplicate ID emits JSON error before mutation" {
  run_split atoshell delete 1,1 --yes --json
  assert_json_error_split "INVALID_ARGUMENT"
  count=$(jq '[.tickets[] | select(.id==1)] | length' .atoshell/queue.json)
  [ "$count" -eq 1 ]
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
