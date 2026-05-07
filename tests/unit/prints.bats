#!/usr/bin/env bats
# Tests for: funcs/prints.sh rendering helpers

load '../helpers/setup'

setup() {
  setup_fixture_project
  load_atoshell_helpers
}

@test "print_banner: quiet mode suppresses banner output" {
  ATOSHELL_QUIET=1
  output=$(print_banner 'atoshell — banner')
  [ -z "$output" ]
}

@test "_print_ticket: quiet mode suppresses ticket output" {
  ATOSHELL_QUIET=1
  output=$(_print_ticket 1 "$QUEUE_FILE")
  [ -z "$output" ]
}

@test "_print_board: default view truncates columns after five tickets" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":1,"title":"Ready 1","status":"Ready","priority":"P2","size":"M"},
  {"id":2,"title":"Ready 2","status":"Ready","priority":"P2","size":"M"},
  {"id":3,"title":"Ready 3","status":"Ready","priority":"P2","size":"M"},
  {"id":4,"title":"Ready 4","status":"Ready","priority":"P2","size":"M"},
  {"id":5,"title":"Ready 5","status":"Ready","priority":"P2","size":"M"},
  {"id":6,"title":"Ready 6","status":"Ready","priority":"P2","size":"M"}
]}
EOF

  output=$(_print_board false false)

  [[ "$output" == *'-- 1 more --'* ]]
}

@test "_print_board: default view uses exact three-column divider" {
  output=$(_print_board false false)

  [[ "$output" == *'+------------------------+------------------------+------------------------+'* ]]
}

@test "_print_board: done view uses exact four-column divider" {
  output=$(_print_board true false)

  [[ "$output" == *'+------------------------+------------------------+------------------------+------------------------+'* ]]
}

@test "_print_board: full view shows all tickets without a truncation marker" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":1,"title":"Ready 1","status":"Ready","priority":"P2","size":"M"},
  {"id":2,"title":"Ready 2","status":"Ready","priority":"P2","size":"M"},
  {"id":3,"title":"Ready 3","status":"Ready","priority":"P2","size":"M"},
  {"id":4,"title":"Ready 4","status":"Ready","priority":"P2","size":"M"},
  {"id":5,"title":"Ready 5","status":"Ready","priority":"P2","size":"M"},
  {"id":6,"title":"Ready 6","status":"Ready","priority":"P2","size":"M"}
]}
EOF

  output=$(_print_board false true)

  [[ "$output" == *'#6 Ready 6'* ]]
  [[ "$output" != *'-- 1 more --'* ]]
}

@test "_print_board: empty files render empty columns" {
  printf '{"tickets":[]}\n' > "$BACKLOG_FILE"
  printf '{"tickets":[]}\n' > "$QUEUE_FILE"
  printf '{"tickets":[]}\n' > "$DONE_FILE"

  output=$(_print_board false false)

  [[ "$output" == *'(empty)'* ]]
}

@test "_print_board: default view shows the done footer count and hint" {
  output=$(_print_board false false)

  [[ "$output" == *'Done: 1 ticket(s)'* ]]
  [[ "$output" == *'Pass --done to show this column.'* ]]
}

@test "_print_board: done view shows the Done column and hides the footer hint" {
  output=$(_print_board true false)

  [[ "$output" == *'4 Done'* ]]
  [[ "$output" != *'Pass --done to show this column.'* ]]
}

@test "_print_board: strips terminal control sequences from ticket titles" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":77,"title":"Ready \u001b[31mred\u001b[0m","status":"Ready","priority":"P2","size":"M"}
]}
EOF

  output=$(_print_board false false)

  [[ "$output" == *'#77 Ready red'* ]]
  [[ "$output" != *$'\e'* ]]
}

@test "_print_board: literal tabs in titles do not break board row parsing" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":78,"title":"Ready\tTabbed","status":"Ready","priority":"P2","size":"M"}
]}
EOF

  output=$(_print_board false false)

  [[ "$output" == *'#78 Ready Tabbed'* ]]
}

@test "_blockers_json: blockers are sorted by configured priority and then id" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":2,"title":"P1 blocker","status":"Ready","priority":"P1","size":"M","dependencies":[]},
  {"id":3,"title":"P0 blocker","status":"Ready","priority":"P0","size":"M","dependencies":[]},
  {"id":10,"title":"Depends on blocker 2","status":"Ready","priority":"P2","size":"M","dependencies":[2]},
  {"id":11,"title":"Depends on blocker 3","status":"Ready","priority":"P2","size":"M","dependencies":[3]}
]}
EOF
  printf '{"tickets":[]}\n' > "$BACKLOG_FILE"
  printf '{"tickets":[]}\n' > "$DONE_FILE"

  blockers=$(_blockers_json)

  [ "$(jq '.[0].id' <<< "$blockers")" -eq 3 ]
  [ "$(jq '.[1].id' <<< "$blockers")" -eq 2 ]
}

@test "_blockers_json: cycle is true for blockers that participate in a dependency cycle" {
  cat > "$QUEUE_FILE" <<'EOF'
{"tickets":[
  {"id":1,"title":"Cycle A","status":"Ready","priority":"P1","size":"M","dependencies":[2]},
  {"id":2,"title":"Cycle B","status":"Ready","priority":"P1","size":"M","dependencies":[1]}
]}
EOF
  printf '{"tickets":[]}\n' > "$BACKLOG_FILE"
  printf '{"tickets":[]}\n' > "$DONE_FILE"

  blockers=$(_blockers_json)

  [ "$(jq '[.[] | select(.cycle == true)] | length' <<< "$blockers")" -eq 2 ]
}
