#!/usr/bin/env bats
# Tests for: npm-compatible package metadata

load '../helpers/setup'

@test "package: metadata exposes atoshell and ato bin entries" {
  jq -e \
    '.name == "atoshell"
     and .version == "2.2.1"
     and .license == "GPL-3.0-only"
     and .bin.atoshell == "bin/atoshell.js"
     and .bin.ato == "bin/atoshell.js"' \
    "$ATOSHELL_REPO/package.json" >/dev/null
}

@test "package: VERSION matches package.json version" {
  run bash -c 'printf "%s" "$(cat "$1")"' _ "$ATOSHELL_REPO/VERSION"
  [ "$status" -eq 0 ]
  [ "$output" = "$(jq -r '.version' "$ATOSHELL_REPO/package.json")" ]
}

_node_bash_path() {
  local bash_path
  bash_path="$(command -v bash)"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$bash_path"
  else
    printf '%s' "$bash_path"
  fi
}

@test "package: node launcher prints version" {
  command -v node >/dev/null 2>&1 || skip "node not available"

  run node "$ATOSHELL_REPO/bin/atoshell.js" version
  [ "$status" -eq 0 ]
  [ "$output" = "atoshell 2.2.1" ]
}

@test "package: node launcher honors ATOSHELL_BASH override" {
  command -v node >/dev/null 2>&1 || skip "node not available"
  command -v bash >/dev/null 2>&1 || skip "bash not available"

  run env ATOSHELL_BASH="$(_node_bash_path)" node "$ATOSHELL_REPO/bin/atoshell.js" version
  [ "$status" -eq 0 ]
  [ "$output" = "atoshell 2.2.1" ]
}

@test "package: node launcher explains missing Bash dependency" {
  command -v node >/dev/null 2>&1 || skip "node not available"

  run env ATOSHELL_BASH="$BATS_TEST_TMPDIR/missing-bash" node "$ATOSHELL_REPO/bin/atoshell.js" version
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: failed to launch "*"/missing-bash:"* ]]
  [[ "$output" == *"Atoshell package installs require Bash 4.3 or newer."* ]]
  [[ "$output" == *"On Windows, install Git Bash or set ATOSHELL_BASH to a Bash executable."* ]]
}

@test "package: dry-run tarball includes runtime files and excludes test files" {
  command -v npm >/dev/null 2>&1 || skip "npm not available"

  run npm pack "$ATOSHELL_REPO" --dry-run --json --pack-destination "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]

  printf '%s' "$output" > "$BATS_TEST_TMPDIR/npm-pack.json"
  jq -e '
    .[0].files
    | map(.path) as $paths
    | ($paths | index("package.json"))
    and ($paths | index("atoshell.sh"))
    and ($paths | index("bin/atoshell.js"))
    and ($paths | index("bin/atoshell"))
    and ($paths | index("bin/ato"))
    and ($paths | index("funcs/helpers.sh"))
    and ($paths | index(".atoshell.example/config.env"))
    and ($paths | index(".assets/logo-with-background.svg"))
    and ($paths | index("README.md"))
    and ($paths | index("LICENSE"))
    and all($paths[]; startswith("tests/") | not)
    and all($paths[]; startswith(".github/") | not)
  ' "$BATS_TEST_TMPDIR/npm-pack.json" >/dev/null
}
