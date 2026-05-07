#!/usr/bin/env bats
# Tests for: parser contracts on manually parsed commands

load '../helpers/setup'

@test "add: unknown option exits non-zero" {
  run atoshell add --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "comment: unknown option exits non-zero" {
  run atoshell comment 1 --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "move: unknown option exits non-zero" {
  run atoshell move 1 --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "search: unknown option exits non-zero" {
  run atoshell search --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "show: unknown option exits non-zero" {
  run atoshell show 1 --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "show: unexpected extra positional argument exits non-zero" {
  run atoshell show 1 extra
  [ "$status" -ne 0 ]
  [[ "$output" == *'unexpected argument'* ]]
}

@test "take: unknown option exits non-zero" {
  run atoshell take 1 --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "take: unexpected extra positional argument exits non-zero" {
  run atoshell take 1 extra
  [ "$status" -ne 0 ]
  [[ "$output" == *'unexpected argument'* ]]
}

@test "add: missing --import value exits cleanly" {
  run atoshell add --import
  [ "$status" -ne 0 ]
  [[ "$output" == *'--import requires'* ]]
  [[ "$output" != *'unbound variable'* ]]
}

@test "list: missing --priority value exits cleanly" {
  run atoshell list --priority
  [ "$status" -ne 0 ]
  [[ "$output" == *'--priority requires'* ]]
  [[ "$output" != *'unbound variable'* ]]
}

@test "take: missing --type value exits cleanly" {
  run atoshell take next --type
  [ "$status" -ne 0 ]
  [[ "$output" == *'--type requires'* ]]
  [[ "$output" != *'unbound variable'* ]]
}

@test "update: unknown option exits non-zero" {
  run atoshell update --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "init: unknown option strips terminal controls from human error" {
  run atoshell init $'--bad\e]52;c;SGVsbG8=\aopt'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--badopt"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "comment: unknown option strips terminal controls from human error" {
  run atoshell comment 1 $'--bad\e]52;c;SGVsbG8=\aopt'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--badopt"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "show: non-numeric ID strips terminal controls from human error" {
  run atoshell show $'bad\e]52;c;SGVsbG8=\aid'
  [ "$status" -ne 0 ]
  [[ "$output" == *"badid"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "take: non-numeric ID strips terminal controls from human error" {
  run atoshell take $'bad\e]52;c;SGVsbG8=\aid'
  [ "$status" -ne 0 ]
  [[ "$output" == *"badid"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "top-level: unknown command strips terminal controls from human error" {
  run atoshell $'bad\e]52;c;SGVsbG8=\acmd'
  [ "$status" -ne 0 ]
  [[ "$output" == *"badcmd"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "delete: non-numeric ID strips terminal controls from human error" {
  run atoshell delete $'bad\e]52;c;SGVsbG8=\aid'
  [ "$status" -ne 0 ]
  [[ "$output" == *"badid"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "move: unknown option strips terminal controls from human error" {
  run atoshell move $'--bad\e]52;c;SGVsbG8=\aopt'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--badopt"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "update: unexpected argument strips terminal controls from human error" {
  run atoshell update $'bad\e]52;c;SGVsbG8=\aarg'
  [ "$status" -ne 0 ]
  [[ "$output" == *"badarg"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "edit: invalid accountable subcommand strips terminal controls from human error" {
  run atoshell edit 1 --accountable $'bad\e]52;c;SGVsbG8=\asub' value
  [ "$status" -ne 0 ]
  [[ "$output" == *"badsub"* ]]
  [[ "$output" != *$'\e'* ]]
  [[ "$output" != *$'\a'* ]]
}

@test "list --json: invalid priority emits JSON error on stderr only" {
  run_split atoshell list --json --priority ZZ
  assert_json_error_split INVALID_PRIORITY
}

@test "list --json: invalid priority is JSON even when --json comes last" {
  run_split atoshell list --priority ZZ --json
  assert_json_error_split INVALID_PRIORITY
}

@test "take --json: empty priority filter value emits JSON error on stderr only" {
  run_split atoshell take next --json --priority P1,,P2
  assert_json_error_split INVALID_PRIORITY
}

@test "add --json: invalid type emits JSON error on stderr only" {
  run_split atoshell add --json --type nope "Bad type"
  assert_json_error_split INVALID_TYPE
}

@test "add --json: invalid discipline emits JSON error on stderr only" {
  run_split atoshell add --json --disciplines nonsense "Bad discipline"
  assert_json_error_split INVALID_DISCIPLINE
}

@test "add --json: non-numeric dependency emits JSON error on stderr only" {
  run_split atoshell add --json --dependencies abc "Bad dep"
  assert_json_error_split INVALID_DEPENDENCY
}

@test "add --json: missing dependency emits JSON error on stderr only" {
  run_split atoshell add --json --dependencies 999 "Missing dep"
  assert_json_error_split DEP_NOT_FOUND
}

@test "add --json: missing title emits JSON error on stderr only" {
  run_split atoshell add --json
  assert_json_error_split MISSING_ARGUMENT
}

@test "add --json: interactive simple mode emits JSON error on stderr only" {
  run_split atoshell add --json --simple
  assert_json_error_split INVALID_ARGUMENT
}

@test "add --json: interactive multi mode emits JSON error on stderr only" {
  run_split atoshell add --json --multi
  assert_json_error_split INVALID_ARGUMENT
}

@test "add --json: import with interactive mode emits JSON error on stderr only" {
  run_split atoshell add --json --import tickets.json --multi
  assert_json_error_split INVALID_ARGUMENT
}

@test "add --json: title without description emits JSON error on stderr only" {
  run_split atoshell add --json "Title only"
  assert_json_error_split MISSING_ARGUMENT
}

@test "JSON-capable commands: unknown option emits JSON error on stderr only" {
  run_split atoshell add --json --bogus
  assert_json_error_split UNKNOWN_OPTION

  run_split atoshell list --json --bogus
  assert_json_error_split UNKNOWN_OPTION

  run_split atoshell take 1 --json --bogus
  assert_json_error_split UNKNOWN_OPTION

  run_split atoshell search --json query --bogus
  assert_json_error_split UNKNOWN_OPTION
}

@test "show --json: unknown option emits JSON error on stderr only" {
  run_split atoshell show --json --bogus
  assert_json_error_split UNKNOWN_OPTION
}

@test "search --json: missing query emits JSON error on stderr only" {
  run_split atoshell search --json
  assert_json_error_split MISSING_ARGUMENT
}
