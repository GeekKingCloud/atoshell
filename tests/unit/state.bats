#!/usr/bin/env bats

load '../helpers/setup'

_ticket_file_count() {
  local id="$1"
  jq -s --arg id "$id" '[.[].tickets[] | select(.id | tostring == $id)] | length' \
    "$TEST_PROJECT/.atoshell/queue.json" \
    "$TEST_PROJECT/.atoshell/backlog.json" \
    "$TEST_PROJECT/.atoshell/done.json"
}

@test "state lock: acquire and release use project lock directory" {
  load_atoshell_helpers

  _state_lock_acquire
  [ -d "$TEST_PROJECT/.atoshell/.lock" ]
  [ -f "$TEST_PROJECT/.atoshell/.lock/meta" ]

  _state_lock_release
  [ ! -e "$TEST_PROJECT/.atoshell/.lock" ]
}
@test "state helpers: ignore inherited internal control flags" {
  export _STATE_LOCK_HELD=true
  export _STATE_TRANSACTION_ACTIVE=true
  export _STATE_TRANSACTION_OWNS_LOCK=true

  load_atoshell_helpers

  [ "$_STATE_LOCK_HELD" = false ]
  [ "$_STATE_TRANSACTION_ACTIVE" = false ]
  [ "$_STATE_TRANSACTION_OWNS_LOCK" = false ]
  jq_inplace "$QUEUE_FILE" '.tickets = []'
  [ "$(jq '.tickets | length' "$QUEUE_FILE")" -eq 0 ]
  [ ! -e "$TEST_PROJECT/.atoshell/.lock" ]
  [ ! -e "$TEST_PROJECT/.atoshell/.transaction" ]
}

@test "state lock: old lock with dead owner is recovered" {
  load_atoshell_helpers
  mkdir -p "$TEST_PROJECT/.atoshell/.lock"
  printf 'pid=999999\ncreated_at_epoch=%s\ncommand=old\ncwd=%s\n' "$(( $(date +%s) - 301 ))" "$TEST_PROJECT" \
    > "$TEST_PROJECT/.atoshell/.lock/meta"

  _state_lock_acquire

  [ -d "$TEST_PROJECT/.atoshell/.lock" ]
  grep -q "pid=$$" "$TEST_PROJECT/.atoshell/.lock/meta"
  _state_lock_release
}

@test "state lock: old lock with live owner is not recovered" {
  load_atoshell_helpers
  sleep 60 &
  local owner_pid="$!"
  mkdir -p "$TEST_PROJECT/.atoshell/.lock"
  printf 'pid=%s\ncreated_at_epoch=%s\ncommand=sleep\ncwd=%s\n' "$owner_pid" "$(( $(date +%s) - 301 ))" "$TEST_PROJECT" \
    > "$TEST_PROJECT/.atoshell/.lock/meta"

  _state_lock_reap_stale

  [ -d "$TEST_PROJECT/.atoshell/.lock" ]
  grep -q "pid=$owner_pid" "$TEST_PROJECT/.atoshell/.lock/meta"
  rm -rf "$TEST_PROJECT/.atoshell/.lock"
  kill "$owner_pid" 2>/dev/null || true
  wait "$owner_pid" 2>/dev/null || true
}

@test "state lock: old lock with reused-looking unrelated PID is recovered" {
  load_atoshell_helpers
  sleep 60 &
  local owner_pid="$!" owner_args
  owner_args="$(_state_lock_owner_args "$owner_pid")"
  if [[ -z "$owner_args" ]]; then
    kill "$owner_pid" 2>/dev/null || true
    wait "$owner_pid" 2>/dev/null || true
    skip "process argument inspection is unavailable in this shell"
  fi
  mkdir -p "$TEST_PROJECT/.atoshell/.lock"
  printf 'pid=%s\ncreated_at_epoch=%s\ncommand=not-this-process\ncwd=%s\n' "$owner_pid" "$(( $(date +%s) - 301 ))" "$TEST_PROJECT" \
    > "$TEST_PROJECT/.atoshell/.lock/meta"

  _state_lock_reap_stale

  [ ! -e "$TEST_PROJECT/.atoshell/.lock" ]
  kill "$owner_pid" 2>/dev/null || true
  wait "$owner_pid" 2>/dev/null || true
}

@test "state lock: invalid old metadata is recovered only after stale age" {
  load_atoshell_helpers
  mkdir -p "$TEST_PROJECT/.atoshell/.lock"
  printf 'pid=not-a-pid\ncreated_at_epoch=not-a-time\ncommand=bad\ncwd=%s\n' "$TEST_PROJECT" \
    > "$TEST_PROJECT/.atoshell/.lock/meta"
  touch -d '10 seconds ago' "$TEST_PROJECT/.atoshell/.lock/meta"

  _state_lock_reap_stale
  [ -d "$TEST_PROJECT/.atoshell/.lock" ]

  touch -d '10 minutes ago' "$TEST_PROJECT/.atoshell/.lock/meta"
  _state_lock_reap_stale
  [ ! -e "$TEST_PROJECT/.atoshell/.lock" ]
}

@test "state lock: error output includes owner metadata" {
  load_atoshell_helpers
  mkdir -p "$TEST_PROJECT/.atoshell/.lock"
  printf 'pid=%s\ncreated_at_epoch=%s\ncommand=holder\ncwd=%s\n' "$$" "$(date +%s)" "$TEST_PROJECT" \
    > "$TEST_PROJECT/.atoshell/.lock/meta"

  run _state_lock_print_error

  [ "$status" -eq 0 ]
  [[ "$output" == *"atoshell state is locked"* ]]
  [[ "$output" == *"pid=$$"* ]]
  [[ "$output" == *"command=holder"* ]]
  [[ "$output" == *"cwd=$TEST_PROJECT"* ]]
  rm -rf "$TEST_PROJECT/.atoshell/.lock"
}

@test "state jq_inplace: bare update is atomic without transaction journal" {
  load_atoshell_helpers

  jq_inplace "$QUEUE_FILE" '.tickets = []'

  [ ! -e "$TEST_PROJECT/.atoshell/.transaction" ]
  [ "$(jq '.tickets | length' "$QUEUE_FILE")" -eq 0 ]
}

@test "state jq_inplace: failed bare update preserves file and releases lock" {
  load_atoshell_helpers
  local before after
  before=$(cat "$QUEUE_FILE")

  run jq_inplace "$QUEUE_FILE" '.tickets = ('

  [ "$status" -ne 0 ]
  after=$(cat "$QUEUE_FILE")
  [ "$after" = "$before" ]
  [ ! -e "$TEST_PROJECT/.atoshell/.lock" ]
  [ ! -e "$TEST_PROJECT/.atoshell/.transaction" ]
}

@test "state transaction: rollback restores before files" {
  load_atoshell_helpers
  local before_count staged_count after_count
  before_count=$(jq '.tickets | length' "$QUEUE_FILE")

  _state_lock_acquire
  _state_transaction_begin
  jq_inplace "$QUEUE_FILE" '.tickets = []'
  staged_count=$(jq '.tickets | length' "$(_state_transaction_current_file "$QUEUE_FILE")")
  _state_transaction_recover
  after_count=$(jq '.tickets | length' "$QUEUE_FILE")
  _state_lock_release

  [ "$staged_count" -eq 0 ]
  [ "$after_count" -eq "$before_count" ]
}

@test "state transaction: commit updates files by rename and removes journal" {
  load_atoshell_helpers

  _state_lock_acquire
  _state_transaction_begin
  jq_inplace "$QUEUE_FILE" '.tickets = []'
  _state_transaction_commit

  [ "$(jq '.tickets | length' "$QUEUE_FILE")" -eq 0 ]
  [ ! -e "$TEST_PROJECT/.atoshell/.transaction" ]
  [ -z "$(compgen -G "$TEST_PROJECT/.atoshell/.queue.json.tmp.*" || true)" ]
}

@test "state transaction: startup recovery rolls back incomplete commit" {
  load_atoshell_helpers
  local before_count after_count
  before_count=$(jq '.tickets | length' "$QUEUE_FILE")

  mkdir -p "$TEST_PROJECT/.atoshell/.transaction/before" "$TEST_PROJECT/.atoshell/.transaction/after"
  printf '1\t%s\n' "$QUEUE_FILE" > "$TEST_PROJECT/.atoshell/.transaction/manifest.tsv"
  cp "$QUEUE_FILE" "$TEST_PROJECT/.atoshell/.transaction/before/1"
  jq '.tickets = []' "$QUEUE_FILE" > "$TEST_PROJECT/.atoshell/queue.partial"
  mv "$TEST_PROJECT/.atoshell/queue.partial" "$QUEUE_FILE"

  _state_lock_acquire
  after_count=$(jq '.tickets | length' "$QUEUE_FILE")
  _state_lock_release

  [ "$after_count" -eq "$before_count" ]
}

@test "state transaction: recovery ignores manifest paths outside state files" {
  load_atoshell_helpers
  local victim="$BATS_TEST_TMPDIR/victim"
  printf 'safe\n' > "$victim"

  mkdir -p "$TEST_PROJECT/.atoshell/.transaction/before" "$TEST_PROJECT/.atoshell/.transaction/after"
  printf '1\t%s\n' "$victim" > "$TEST_PROJECT/.atoshell/.transaction/manifest.tsv"
  printf 'pwned\n' > "$TEST_PROJECT/.atoshell/.transaction/before/1"

  _state_lock_acquire
  _state_lock_release

  [ "$(cat "$victim")" = "safe" ]
  [ ! -e "$TEST_PROJECT/.atoshell/.transaction" ]
}

@test "state transaction: concurrent add commands allocate unique ids" {
  local out_dir="$BATS_TEST_TMPDIR/concurrent"
  mkdir -p "$out_dir"

  local pids=() pid n failed=0
  for n in 1 2; do
    atoshell add "Concurrent $n" --description "Created concurrently" --json > "$out_dir/$n.json" 2> "$out_dir/$n.err" &
    pids+=("$!")
  done
  for n in "${!pids[@]}"; do
    pid="${pids[$n]}"
    if wait "$pid"; then
      printf '0\n' > "$out_dir/$(( n + 1 )).status"
    else
      printf '%s\n' "$?" > "$out_dir/$(( n + 1 )).status"
      failed=1
    fi
  done

  if [[ "$failed" -ne 0 ]]; then
    for n in 1 2; do
      printf 'add %s exit %s\n' "$n" "$(cat "$out_dir/$n.status")" >&2
      cat "$out_dir/$n.err" >&2
    done
  fi
  [ "$failed" -eq 0 ]
  jq -s '[.[].id] | length == 2 and (unique | length == 2)' "$out_dir"/*.json | grep -q true
  [ "$(jq '.next_id' "$TEST_PROJECT/.atoshell/meta.json")" -eq 8 ]
}

@test "state movement: move leaves ticket in exactly one status file" {
  run atoshell move 4 ready
  [ "$status" -eq 0 ]
  [ "$(_ticket_file_count 4)" -eq 1 ]
  jq -e '.tickets[] | select(.id == 4 and .status == "Ready")' "$TEST_PROJECT/.atoshell/queue.json" > /dev/null
}

@test "state movement: take leaves ticket in exactly one status file" {
  run atoshell take 4 --force
  [ "$status" -eq 0 ]
  [ "$(_ticket_file_count 4)" -eq 1 ]
  jq -e '.tickets[] | select(.id == 4 and .status == "In Progress")' "$TEST_PROJECT/.atoshell/queue.json" > /dev/null
}

@test "state movement: edit status leaves ticket in exactly one status file" {
  run atoshell edit 4 --status ready
  [ "$status" -eq 0 ]
  [ "$(_ticket_file_count 4)" -eq 1 ]
  jq -e '.tickets[] | select(.id == 4 and .status == "Ready")' "$TEST_PROJECT/.atoshell/queue.json" > /dev/null
}
