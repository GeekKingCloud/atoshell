#!/usr/bin/env bats
# Tests for: funcs/helpers.sh
#
# Approach: source helpers.sh in setup() so every @test can call helper
# functions directly.  Functions that call exit (error paths) are invoked
# via `run` so bats captures the exit code in a subshell.
#
# TTY-dependent functions (ask, ask_yn, ask_pick) are not tested here.
# Board renderer (_print_board) is covered by show.bats and list.bats.

# ── Setup ─────────────────────────────────────────────────────────────────────
setup() {
  export TEST_PROJECT="$BATS_TEST_TMPDIR/myproject"
  mkdir -p "$TEST_PROJECT"
  export ATOSHELL_REPO="$(cd "$BATS_TEST_DIRNAME/../../" && pwd)"
  export ATOSHELL_DIR="$ATOSHELL_REPO"

  mkdir -p "$TEST_PROJECT/.atoshell"
  cp "$BATS_TEST_DIRNAME/../fixtures/queue.json"   "$TEST_PROJECT/.atoshell/queue.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/backlog.json" "$TEST_PROJECT/.atoshell/backlog.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/done.json" "$TEST_PROJECT/.atoshell/done.json"
  cp "$BATS_TEST_DIRNAME/../fixtures/meta.json"    "$TEST_PROJECT/.atoshell/meta.json"


  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'USERNAME="testuser"' \
    > "$TEST_PROJECT/.atoshell/config.env"

  # shellcheck source=/dev/null
  source "$ATOSHELL_REPO/funcs/helpers.sh"
  source "$ATOSHELL_REPO/funcs/algorithms.sh"
  _load_config "$TEST_PROJECT"

  cd "$TEST_PROJECT"
}

# ── 1. _require_tty ───────────────────────────────────────────────────────────
@test "_require_tty: exits 1 when stdin is not a TTY" {
  run _require_tty
  [ "$status" -eq 1 ]
}
@test "_require_tty: error message mentions stdin not a TTY" {
  run _require_tty
  [[ "$output" == *"stdin is not a TTY"* ]]
}

# ── 2. _out / _outf ───────────────────────────────────────────────────────────
@test "_out: prints string when ATOSHELL_QUIET=0" {
  ATOSHELL_QUIET=0
  result=$(_out "hello")
  [ "$result" = "hello" ]
}
@test "_out: suppresses output when ATOSHELL_QUIET=1" {
  ATOSHELL_QUIET=1
  result=$(_out "hello")
  [ -z "$result" ]
}
@test "_outf: prints formatted string when ATOSHELL_QUIET=0" {
  ATOSHELL_QUIET=0
  result=$(_outf "%s %s" "foo" "bar")
  [ "$result" = "foo bar" ]
}
@test "_outf: suppresses output when ATOSHELL_QUIET=1" {
  ATOSHELL_QUIET=1
  result=$(_outf "%s" "hello")
  [ -z "$result" ]
}

# ── 2b. Actor resolution ──────────────────────────────────────────────────────
@test "_normalize_actor: bare positive integer becomes agent-N" {
  result=$(_normalize_actor "10")
  [ "$result" = "agent-10" ]
}
@test "_normalize_actor: agent-N stays unchanged" {
  result=$(_normalize_actor "agent-10")
  [ "$result" = "agent-10" ]
}
@test "_validate_actor: accepts bare positive integer" {
  run _validate_actor "10"
  [ "$status" -eq 0 ]
}
@test "_validate_actor: accepts agent-N" {
  run _validate_actor "agent-10"
  [ "$status" -eq 0 ]
}
@test "_validate_actor: rejects empty value" {
  run _validate_actor ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as requires a non-empty value"* ]]
}
@test "_validate_actor: rejects arbitrary names" {
  run _validate_actor "alice"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}
@test "_validate_actor: strips terminal controls from invalid actor errors" {
  run _validate_actor $'bad\e]52;c;SGVsbG8=\aactor'
  [ "$status" -eq 1 ]
  [[ "$output" == *"badactor"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}
@test "_resolve_actor: defaults to [agent] in non-TTY" {
  result=$(_resolve_actor)
  [ "$result" = "[agent]" ]
}
@test "_resolve_actor: normalizes bare integer override" {
  result=$(_resolve_actor "10")
  [ "$result" = "agent-10" ]
}
@test "_resolve_actor: rejects arbitrary override names" {
  run _resolve_actor "alice"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--as must be a positive number or agent-N"* ]]
}

@test "_cli_error: strips terminal controls from human error message" {
  run _cli_error false UNKNOWN_OPTION $'unknown option "\e]52;c;SGVsbG8=\abad".' option bad
  [ "$status" -eq 1 ]
  [[ "$output" == *'unknown option "bad".'* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_resolve_type: strips terminal controls from invalid value and valid labels" {
  TYPE_0=$'Bu\e]52;c;SGVsbG8=\ag'
  run _resolve_type $'No\e]52;c;SGVsbG8=\ape'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Nope"* ]]
  [[ "$output" == *"Bug"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_resolve_priority: strips terminal controls from invalid value and valid labels" {
  PRIORITY_0=$'P\e]52;c;SGVsbG8=\a0'
  run _resolve_priority $'No\e]52;c;SGVsbG8=\ape'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Nope"* ]]
  [[ "$output" == *"P0"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_resolve_size: strips terminal controls from invalid value and valid labels" {
  SIZE_0=$'X\e]52;c;SGVsbG8=\aS'
  run _resolve_size $'No\e]52;c;SGVsbG8=\ape'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Nope"* ]]
  [[ "$output" == *"XS"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_resolve_status: strips terminal controls from invalid value and valid labels" {
  STATUS_READY=$'Re\e]52;c;SGVsbG8=\aady'
  run _resolve_status $'No\e]52;c;SGVsbG8=\ape'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Nope"* ]]
  [[ "$output" == *"Ready"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_resolve_discipline: strips terminal controls from invalid value and valid labels" {
  DISCIPLINE_LABELS=$'Frontend,Ba\e]52;c;SGVsbG8=\ackend'
  run _resolve_discipline $'No\e]52;c;SGVsbG8=\ape'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Nope"* ]]
  [[ "$output" == *"Backend"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "_timestamp: defaults to UTC Z timestamps" {
  ATOSHELL_TIMEZONE="UTC"
  result=$(_timestamp)
  [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "_timestamp: IANA timezone writes ISO offset timestamps" {
  ATOSHELL_TIMEZONE="America/Mexico_City"
  result=$(_timestamp)
  [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}-06:00$ ]]
}

# ── 3. jq_inplace ─────────────────────────────────────────────────────────────
@test "_mktemp_sibling: creates temp files beside the target" {
  local f="$TEST_PROJECT/.atoshell/queue.json"
  local tmp
  tmp="$(_mktemp_sibling "$f")"
  [ -f "$tmp" ]
  [ "$(dirname "$tmp")" = "$(dirname "$f")" ]
  rm -f "$tmp"
}
@test "jq_inplace: modifies the file in place" {
  local f="$TEST_PROJECT/.atoshell/queue.json"
  jq_inplace "$f" '.tickets = []'
  count=$(jq '.tickets | length' "$f")
  [ "$count" -eq 0 ]
}
@test "jq_inplace: result is valid JSON" {
  local f="$TEST_PROJECT/.atoshell/queue.json"
  jq_inplace "$f" '.test_key = "test_val"'
  val=$(jq -r '.test_key' "$f")
  [ "$val" = "test_val" ]
}
@test "jq_inplace: accepts extra jq args (--argjson)" {
  local f="$TEST_PROJECT/.atoshell/queue.json"
  jq_inplace "$f" --argjson n 99 '.test_num = $n'
  val=$(jq '.test_num' "$f")
  [ "$val" -eq 99 ]
}
@test "jq_inplace: does not leave sibling temp files behind" {
  local f="$TEST_PROJECT/.atoshell/queue.json"
  jq_inplace "$f" '.tickets = []'
  run find "$TEST_PROJECT/.atoshell" -maxdepth 1 -type f -name '.queue.json.tmp.*'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── 4. _resolve_project ───────────────────────────────────────────────────────
@test "_resolve_project: returns cwd when .atoshell/ exists" {
  result=$(_resolve_project)
  [ "$result" = "$TEST_PROJECT" ]
}
@test "_resolve_project: exits non-zero when no .atoshell/ found" {
  cd "$BATS_TEST_TMPDIR"
  run _resolve_project
  [ "$status" -ne 0 ]
}
@test "_resolve_project: error message mentions atoshell init" {
  cd "$BATS_TEST_TMPDIR"
  run _resolve_project
  [[ "$output" == *"atoshell init"* ]]
}
@test "_resolve_project: walk=true finds .atoshell/ in parent" {
  mkdir -p "$TEST_PROJECT/subdir"
  cd "$TEST_PROJECT/subdir"
  result=$(_resolve_project true)
  [ "$result" = "$TEST_PROJECT" ]
}
@test "_resolve_project: default does not walk up" {
  mkdir -p "$TEST_PROJECT/subdir"
  cd "$TEST_PROJECT/subdir"
  run _resolve_project
  [ "$status" -ne 0 ]
}

# ── 5. _load_config defaults ──────────────────────────────────────────────────
@test "_load_config: STATUS_READY defaults to 'Ready'" {
  [ "$STATUS_READY" = "Ready" ]
}
@test "_load_config: PRIORITY_2 defaults to 'P2'" {
  [ "$PRIORITY_2" = "P2" ]
}
@test "_load_config: SIZE_2 defaults to 'M'" {
  [ "$SIZE_2" = "M" ]
}
@test "_load_config: USERNAME loaded from config.env" {
  [ "$USERNAME" = "testuser" ]
}
@test "_load_config: sets QUEUE_FILE path" {
  [ "$QUEUE_FILE" = "$TEST_PROJECT/.atoshell/queue.json" ]
}
@test "_load_config: sets BACKLOG_FILE path" {
  [ "$BACKLOG_FILE" = "$TEST_PROJECT/.atoshell/backlog.json" ]
}
@test "_load_config: sets DONE_FILE path" {
  [ "$DONE_FILE" = "$TEST_PROJECT/.atoshell/done.json" ]
}
@test "_load_config: sets META_FILE path" {
  [ "$META_FILE" = "$TEST_PROJECT/.atoshell/meta.json" ]
}

# ── 6. _ensure_files ──────────────────────────────────────────────────────────
@test "_ensure_files: creates queue.json when missing" {
  rm "$QUEUE_FILE"
  _ensure_files
  [ -f "$QUEUE_FILE" ]
}
@test "_ensure_files: created queue.json has empty tickets array" {
  rm "$QUEUE_FILE"
  _ensure_files
  count=$(jq '.tickets | length' "$QUEUE_FILE")
  [ "$count" -eq 0 ]
}
@test "_ensure_files: creates backlog.json when missing" {
  rm "$BACKLOG_FILE"
  _ensure_files
  [ -f "$BACKLOG_FILE" ]
}
@test "_ensure_files: creates done.json when missing" {
  rm "$DONE_FILE"
  _ensure_files
  [ -f "$DONE_FILE" ]
}
@test "_ensure_files: creates meta.json when missing" {
  rm "$META_FILE"
  _ensure_files
  [ -f "$META_FILE" ]
}
@test "_ensure_files: does not overwrite existing queue.json" {
  count_before=$(jq '.tickets | length' "$QUEUE_FILE")
  _ensure_files
  count_after=$(jq '.tickets | length' "$QUEUE_FILE")
  [ "$count_before" -eq "$count_after" ]
}
@test "_ensure_files: seeds next_id from highest existing ticket when meta.json is missing" {
  rm "$META_FILE"
  _ensure_files
  [ "$(jq '.next_id' "$META_FILE")" -eq 6 ]
}

@test "_setup_readonly: does not create missing meta.json" {
  rm "$META_FILE"
  _setup_readonly
  [ ! -f "$META_FILE" ]
}

@test "_setup_readonly: does not acquire state lock" {
  _setup_readonly
  [ ! -d "$TEST_PROJECT/.atoshell/.lock" ]
}

@test "_setup_readonly: recovers stale transaction before reading" {
  before_count=$(jq '.tickets | length' "$QUEUE_FILE")

  mkdir -p "$TEST_PROJECT/.atoshell/.transaction/before" "$TEST_PROJECT/.atoshell/.transaction/after"
  printf '1\t%s\n' "$QUEUE_FILE" > "$TEST_PROJECT/.atoshell/.transaction/manifest.tsv"
  cp "$QUEUE_FILE" "$TEST_PROJECT/.atoshell/.transaction/before/1"
  jq '.tickets = []' "$QUEUE_FILE" > "$TEST_PROJECT/.atoshell/queue.partial"
  mv "$TEST_PROJECT/.atoshell/queue.partial" "$QUEUE_FILE"

  _setup_readonly

  after_count=$(jq '.tickets | length' "$QUEUE_FILE")
  [ "$after_count" -eq "$before_count" ]
  [ ! -d "$TEST_PROJECT/.atoshell/.lock" ]
  [ ! -d "$TEST_PROJECT/.atoshell/.transaction" ]
}

@test "_setup_readonly: fails when a shared ticket file is missing" {
  rm "$QUEUE_FILE"
  run _setup_readonly
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing state file"* ]]
}

# ── 7. _resolve_status ────────────────────────────────────────────────────────
@test "_resolve_status: returns 'Ready' for 'ready'" {
  result=$(_resolve_status "ready")
  [ "$result" = "Ready" ]
}
@test "_resolve_status: returns 'In Progress' for 'in progress'" {
  result=$(_resolve_status "in progress")
  [ "$result" = "In Progress" ]
}
@test "_resolve_status: returns 'Backlog' for 'Backlog'" {
  result=$(_resolve_status "Backlog")
  [ "$result" = "Backlog" ]
}
@test "_resolve_status: returns 'Done' for 'done'" {
  result=$(_resolve_status "done")
  [ "$result" = "Done" ]
}
@test "_resolve_status: exits non-zero for unknown status" {
  run _resolve_status "nonsense"
  [ "$status" -ne 0 ]
}
@test "_resolve_status: error mentions the invalid value" {
  run _resolve_status "nonsense"
  [[ "$output" == *"nonsense"* ]]
}
@test "_resolve_status: returns 'Backlog' for column number '1'" {
  result=$(_resolve_status "1")
  [ "$result" = "Backlog" ]
}
@test "_resolve_status: returns 'Ready' for column number '2'" {
  result=$(_resolve_status "2")
  [ "$result" = "Ready" ]
}
@test "_resolve_status: returns 'In Progress' for column number '3'" {
  result=$(_resolve_status "3")
  [ "$result" = "In Progress" ]
}
@test "_resolve_status: returns 'Done' for column number '4'" {
  result=$(_resolve_status "4")
  [ "$result" = "Done" ]
}

# ── 8. _status_to_file ────────────────────────────────────────────────────────
@test "_status_to_file: Ready routes to queue.json" {
  result=$(_status_to_file "Ready")
  [ "$result" = "$QUEUE_FILE" ]
}
@test "_status_to_file: In Progress routes to queue.json" {
  result=$(_status_to_file "In Progress")
  [ "$result" = "$QUEUE_FILE" ]
}
@test "_status_to_file: Backlog routes to backlog.json" {
  result=$(_status_to_file "Backlog")
  [ "$result" = "$BACKLOG_FILE" ]
}
@test "_status_to_file: Done routes to done.json" {
  result=$(_status_to_file "Done")
  [ "$result" = "$DONE_FILE" ]
}
# ── 9. _resolve_type ──────────────────────────────────────────────────────────
@test "_resolve_type: returns 'Bug' for 'bug'" {
  result=$(_resolve_type "bug")
  [ "$result" = "Bug" ]
}
@test "_resolve_type: returns 'Feature' for 'FEATURE'" {
  result=$(_resolve_type "FEATURE")
  [ "$result" = "Feature" ]
}
@test "_resolve_type: returns 'Task' for 'task'" {
  result=$(_resolve_type "task")
  [ "$result" = "Task" ]
}
@test "_resolve_type: exits non-zero for unknown type" {
  run _resolve_type "nonsense"
  [ "$status" -ne 0 ]
}
@test "_resolve_type: error mentions the invalid value" {
  run _resolve_type "nonsense"
  [[ "$output" == *"nonsense"* ]]
}
@test "_resolve_type: returns 'Bug' for index '0'" {
  result=$(_resolve_type "0")
  [ "$result" = "Bug" ]
}
@test "_resolve_type: returns 'Feature' for index '1'" {
  result=$(_resolve_type "1")
  [ "$result" = "Feature" ]
}
@test "_resolve_type: returns 'Task' for index '2'" {
  result=$(_resolve_type "2")
  [ "$result" = "Task" ]
}

# ── 10. _resolve_priority ─────────────────────────────────────────────────────
@test "_resolve_priority: returns 'P0' for 'p0'" {
  result=$(_resolve_priority "p0")
  [ "$result" = "P0" ]
}
@test "_resolve_priority: returns 'P1' for 'P1'" {
  result=$(_resolve_priority "P1")
  [ "$result" = "P1" ]
}
@test "_resolve_priority: exits non-zero for unknown priority" {
  run _resolve_priority "ZZ"
  [ "$status" -ne 0 ]
}
@test "_resolve_priority: error mentions the invalid value" {
  run _resolve_priority "ZZ"
  [[ "$output" == *"ZZ"* ]]
}
@test "_resolve_priority: returns 'P0' for index '0'" {
  result=$(_resolve_priority "0")
  [ "$result" = "P0" ]
}
@test "_resolve_priority: returns 'P1' for index '1'" {
  result=$(_resolve_priority "1")
  [ "$result" = "P1" ]
}
@test "_resolve_priority: returns 'P2' for index '2'" {
  result=$(_resolve_priority "2")
  [ "$result" = "P2" ]
}
@test "_resolve_priority: returns 'P3' for index '3'" {
  result=$(_resolve_priority "3")
  [ "$result" = "P3" ]
}

# ── 11. _resolve_size ─────────────────────────────────────────────────────────
@test "_resolve_size: returns 'XS' for 'xs'" {
  result=$(_resolve_size "xs")
  [ "$result" = "XS" ]
}
@test "_resolve_size: returns 'M' for 'M'" {
  result=$(_resolve_size "M")
  [ "$result" = "M" ]
}
@test "_resolve_size: exits non-zero for unknown size" {
  run _resolve_size "XXL"
  [ "$status" -ne 0 ]
}
@test "_resolve_size: error mentions the invalid value" {
  run _resolve_size "XXL"
  [[ "$output" == *"XXL"* ]]
}
@test "_resolve_size: returns 'XS' for index '0'" {
  result=$(_resolve_size "0")
  [ "$result" = "XS" ]
}
@test "_resolve_size: returns 'S' for index '1'" {
  result=$(_resolve_size "1")
  [ "$result" = "S" ]
}
@test "_resolve_size: returns 'M' for index '2'" {
  result=$(_resolve_size "2")
  [ "$result" = "M" ]
}
@test "_resolve_size: returns 'L' for index '3'" {
  result=$(_resolve_size "3")
  [ "$result" = "L" ]
}
@test "_resolve_size: returns 'XL' for index '4'" {
  result=$(_resolve_size "4")
  [ "$result" = "XL" ]
}

# ── 12. _resolve_discipline ───────────────────────────────────────────────────
@test "_resolve_discipline: returns 'Frontend' for 'frontend'" {
  result=$(_resolve_discipline "frontend")
  [ "$result" = "Frontend" ]
}
@test "_resolve_discipline: 'fe' alias resolves to Frontend" {
  result=$(_resolve_discipline "fe")
  [ "$result" = "Frontend" ]
}
@test "_resolve_discipline: 'be' alias resolves to Backend" {
  result=$(_resolve_discipline "be")
  [ "$result" = "Backend" ]
}
@test "_resolve_discipline: returns 'Database' for 'database'" {
  result=$(_resolve_discipline "database")
  [ "$result" = "Database" ]
}
@test "_resolve_discipline: returns 'Cloud' for 'cloud'" {
  result=$(_resolve_discipline "cloud")
  [ "$result" = "Cloud" ]
}
@test "_resolve_discipline: returns 'DevOps' for 'devops'" {
  result=$(_resolve_discipline "devops")
  [ "$result" = "DevOps" ]
}
@test "_resolve_discipline: returns 'Architecture' for 'architecture'" {
  result=$(_resolve_discipline "architecture")
  [ "$result" = "Architecture" ]
}
@test "_resolve_discipline: returns 'Automation' for 'automation'" {
  result=$(_resolve_discipline "automation")
  [ "$result" = "Automation" ]
}
@test "_resolve_discipline: returns 'Research' for 'research'" {
  result=$(_resolve_discipline "research")
  [ "$result" = "Research" ]
}
@test "_resolve_discipline: returns 'Core' for 'core'" {
  result=$(_resolve_discipline "core")
  [ "$result" = "Core" ]
}
@test "_resolve_discipline: returns 'QA' for 'qa'" {
  result=$(_resolve_discipline "qa")
  [ "$result" = "QA" ]
}
@test "_resolve_discipline: exits non-zero for unknown discipline" {
  run _resolve_discipline "nonsense"
  [ "$status" -ne 0 ]
}
@test "_resolve_discipline: exits non-zero for removed discipline 'Infra'" {
  run _resolve_discipline "Infra"
  [ "$status" -ne 0 ]
}
@test "_resolve_discipline: exits non-zero for removed discipline 'Scripting'" {
  run _resolve_discipline "Scripting"
  [ "$status" -ne 0 ]
}

# ── 13. _find_ticket_file ─────────────────────────────────────────────────────
@test "_find_ticket_file: finds ticket #1 in queue.json" {
  result=$(_find_ticket_file "1")
  [ "$result" = "$QUEUE_FILE" ]
}
@test "_find_ticket_file: finds ticket #4 in backlog.json" {
  result=$(_find_ticket_file "4")
  [ "$result" = "$BACKLOG_FILE" ]
}
@test "_find_ticket_file: finds ticket #5 in done.json" {
  result=$(_find_ticket_file "5")
  [ "$result" = "$DONE_FILE" ]
}
@test "_find_ticket_file: exits non-zero for nonexistent ticket" {
  run _find_ticket_file "999"
  [ "$status" -ne 0 ]
}
@test "_find_ticket_file: error mentions the missing ID" {
  run _find_ticket_file "999"
  [[ "$output" == *"999"* ]]
}

# ── 14. _next_id ──────────────────────────────────────────────────────────────
@test "_next_id: returns 6 (current next_id)" {
  result=$(_next_id)
  [ "$result" -eq 6 ]
}
@test "_next_id: increments next_id to 7 after call" {
  _next_id > /dev/null
  val=$(jq '.next_id' "$META_FILE")
  [ "$val" -eq 7 ]
}
@test "_next_id: sequential calls return consecutive IDs" {
  first=$(_next_id)
  second=$(_next_id)
  [ "$second" -eq $(( first + 1 )) ]
}

# ── 15. _get_uuid ─────────────────────────────────────────────────────────────
@test "_get_uuid: returns a non-empty string" {
  result=$(_get_uuid)
  [ -n "$result" ]
}
@test "_get_uuid: matches UUID format (8-4-4-4-12 hex)" {
  result=$(_get_uuid)
  [[ "$result" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}
@test "_get_uuid: two calls return different values" {
  first=$(_get_uuid)
  second=$(_get_uuid)
  [ "$first" != "$second" ]
}

# ── 16. _check_cyclic_deps ────────────────────────────────────────────────────
@test "_check_cyclic_deps: returns 0 (no cycle) for valid deps" {
  # #2 depends on #1 — no cycle
  _check_cyclic_deps "2" "1"
  [ "$?" -eq 0 ]
}
@test "_check_cyclic_deps: returns 0 when ticket has no deps" {
  _check_cyclic_deps "1"
  [ "$?" -eq 0 ]
}
@test "_check_cyclic_deps: returns 1 (cycle detected) for self-dep" {
  # Ticket depending on itself is a cycle
  run _check_cyclic_deps "1" "1"
  [ "$status" -ne 0 ]
}
@test "_check_cyclic_deps: detects A→B→A cycle" {
  # Add a dep from #2 back to itself via jq to create A→B→A
  jq_inplace "$QUEUE_FILE" '(.tickets[] | select(.id==1)).dependencies = [2]'
  # Now asking if #2 can depend on #1 would create 1→2→1
  run _check_cyclic_deps "2" "1"
  [ "$status" -ne 0 ]
}

# ── 17. _config_defaults ──────────────────────────────────────────────────────
@test "_config_defaults: output includes STATUS_READY" {
  result=$(_config_defaults)
  [[ "$result" == *"STATUS_READY"* ]]
}
@test "_config_defaults: output includes all SIZE variables" {
  result=$(_config_defaults)
  [[ "$result" == *"SIZE_0"* ]]
  [[ "$result" == *"SIZE_4"* ]]
}
@test "_config_defaults: output includes USERNAME" {
  result=$(_config_defaults)
  [[ "$result" == *"USERNAME"* ]]
}
@test "_config_defaults: output does not include DISCIPLINES" {
  result=$(_config_defaults)
  [[ "$result" != *"DISCIPLINES"* ]]
}
@test "_config_template: output includes timestamp guidance from the example config" {
  result=$(_config_template)
  [[ "$result" == *'# Controls created_at, updated_at, and ticket comment timestamps.'* ]]
  [[ "$result" == *'# Use an IANA name such as "America/Mexico_City"'* ]]
  [[ "$result" == *'ATOSHELL_TIMEZONE="UTC"'* ]]
}
