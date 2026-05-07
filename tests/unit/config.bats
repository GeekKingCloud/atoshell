#!/usr/bin/env bats
# Tests for: config sync, prompt helpers, and text sanitization

load '../helpers/setup'

setup() {
  setup_fixture_project
  load_atoshell_helpers
}

_stage_tool() {
  local real="$1" dest="$2"
  local shell
  shell="$(type -P bash)"
  cat > "$dest" <<EOF
#!$shell
exec "$real" "\$@"
EOF
  chmod +x "$dest"
}

_cat_only_path() {
  local dir="$BATS_TEST_TMPDIR/cat_only_bin"
  mkdir -p "$dir"
  _stage_tool "$(type -P cat)" "$dir/cat"
  printf '%s' "$dir"
}

@test "_ensure_config: creates missing config from local template" {
  rm -f "$CONFIG_FILE"
  _ensure_config "$CONFIG_FILE"
  [ -f "$CONFIG_FILE" ]
  grep -qF 'STATUS_READY="Ready"' "$CONFIG_FILE"
  grep -qF '#USERNAME="Your Name"' "$CONFIG_FILE"
}
@test "_config_template: matches packaged example config" {
  local generated="$BATS_TEST_TMPDIR/generated-config.env"
  _config_template > "$generated"

  diff -u "$ATOSHELL_REPO/.atoshell.example/config.env" "$generated"
}

@test "_sync_config_vars: appends missing keys to a sparse config" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    > "$CONFIG_FILE"

  _sync_config_vars "$CONFIG_FILE"

  grep -qF 'STATUS_READY="Ready"' "$CONFIG_FILE"
  grep -qF 'TYPE_2="Task"' "$CONFIG_FILE"
}

@test "_sync_config_vars: removes stale DISCIPLINES config key" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'DISCIPLINES="Frontend,Backend"' \
    '#DISCIPLINES="Frontend,Backend"' \
    > "$CONFIG_FILE"

  _sync_config_vars "$CONFIG_FILE"

  ! grep -q 'DISCIPLINES=' "$CONFIG_FILE"
  grep -qF 'STATUS_READY="Ready"' "$CONFIG_FILE"
}

@test "_sync_config_vars: repeated runs do not duplicate appended keys" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    > "$CONFIG_FILE"

  _sync_config_vars "$CONFIG_FILE"
  _sync_config_vars "$CONFIG_FILE"

  [ "$(grep -c '^STATUS_READY=' "$CONFIG_FILE")" -eq 1 ]
  [ "$(grep -c '^TYPE_2=' "$CONFIG_FILE")" -eq 1 ]
}

@test "_sync_config_vars: commented keys count as existing" {
  printf '%s\n' \
    '#USERNAME="Your Name"' \
    'STATUS_BACKLOG="Backlog"' \
    > "$CONFIG_FILE"

  _sync_config_vars "$CONFIG_FILE"

  [ "$(grep -c 'USERNAME=' "$CONFIG_FILE")" -eq 1 ]
  [ "$(grep -c '^USERNAME=' "$CONFIG_FILE")" -eq 0 ]
}

@test "_sync_config_vars: non-TTY mode keeps the empty default" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    > "$CONFIG_FILE"

  _sync_config_vars "$CONFIG_FILE"

  grep -qF 'USERNAME=""' "$CONFIG_FILE"
}

@test "_ensure_config: fallback without packaged template uses generated defaults" {
  local old_path="$PATH"
  local fake_root="$BATS_TEST_TMPDIR/fake-root"
  local cat_path
  cat_path="$(_cat_only_path)"
  mkdir -p "$fake_root/.atoshell.example"
  rm -f "$CONFIG_FILE"
  export ATOSHELL_DIR="$fake_root"
  export PATH="$cat_path"

  _ensure_config "$CONFIG_FILE"

  export PATH="$old_path"
  export ATOSHELL_DIR="$ATOSHELL_REPO"
  [ -f "$CONFIG_FILE" ]
  grep -qF '# .atoshell/config.env' "$CONFIG_FILE"
  grep -qF '# Controls created_at, updated_at, and ticket comment timestamps.' "$CONFIG_FILE"
  grep -qF '# Use an IANA name such as "America/Mexico_City"' "$CONFIG_FILE"
  grep -qF 'STATUS_READY="Ready"' "$CONFIG_FILE"
}

@test "_load_config: warns when USERNAME is set to me" {
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    'USERNAME="me"' \
    > "$CONFIG_FILE"

  run _load_config "$TEST_PROJECT"

  [ "$status" -eq 0 ]
  [[ "$output" == *'USERNAME=me conflicts with the "me" accountable shorthand'* ]]
}
@test "_load_config: ignores inherited USERNAME and uses undefined when config username is not set" {
  export USERNAME="host-user"
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  [ "$USERNAME" = "undefined" ]
}
@test "_load_config: does not call git or use inherited USERNAME for username fallback" {
  local old_path="$PATH"
  local marker="$BATS_TEST_TMPDIR/git-called"
  local fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  export USERNAME="host-user"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/git" <<EOF
#!/usr/bin/env bash
touch "$marker"
printf 'Git User\n'
EOF
  chmod +x "$fake_bin/git"
  export PATH="$fake_bin:$PATH"
  printf '%s\n' \
    'STATUS_BACKLOG="Backlog"' \
    'STATUS_READY="Ready"' \
    'STATUS_IN_PROGRESS="In Progress"' \
    'STATUS_DONE="Done"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  export PATH="$old_path"
  [ ! -e "$marker" ]
  [ "$USERNAME" = "undefined" ]
}

@test "_load_config: ignores stale DISCIPLINES config value" {
  printf '%s\n' \
    'DISCIPLINES="Infra"' \
    'DISCIPLINE_LABELS="Infra"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  run _resolve_discipline "Infra"
  [ "$status" -ne 0 ]
  result=$(_resolve_discipline "Frontend")
  [ "$result" = "Frontend" ]
}

@test "_load_config: treats quoted config values as inert text" {
  local marker="$BATS_TEST_TMPDIR/config-executed"
  printf '%s\n' \
    'USERNAME="$(touch '"$marker"')"' \
    'STATUS_READY="Ready Now"' \
    "STATUS_DONE='Done Later'" \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  [ ! -e "$marker" ]
  [ "$USERNAME" = '$(touch '"$marker"')' ]
  [ "$STATUS_READY" = "Ready Now" ]
  [ "$STATUS_DONE" = "Done Later" ]
}

@test "_load_config: ignores unsafe unquoted config syntax" {
  local marker="$BATS_TEST_TMPDIR/config-executed"
  printf '%s\n' \
    'STATUS_READY=$(touch '"$marker"')' \
    'USERNAME=valid_user' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  [ ! -e "$marker" ]
  [ "$STATUS_READY" = "Ready" ]
  [ "$USERNAME" = "valid_user" ]
}

@test "_load_config: ignores unknown config keys" {
  printf '%s\n' \
    'STATUS_READY="Ready Now"' \
    'NOT_A_CONFIG_KEY="ignored"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  [ "$STATUS_READY" = "Ready Now" ]
  [ -z "${NOT_A_CONFIG_KEY+x}" ]
}

@test "_load_config: builds valid label JSON without jq startup pipelines" {
  printf '%s\n' \
    'PRIORITY_0="P\"0"' \
    'PRIORITY_1="P\\1"' \
    'SIZE_0="Extra Small"' \
    'SIZE_1="Tab	Size"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  [ "$(jq -r '.[0]' <<< "$PRIORITY_LABELS_JSON")" = 'P"0' ]
  [ "$(jq -r '.[1]' <<< "$PRIORITY_LABELS_JSON")" = 'P\1' ]
  [ "$(jq -r '.[0]' <<< "$SIZE_LABELS_JSON")" = "Extra Small" ]
  [ "$(jq -r '.[1]' <<< "$SIZE_LABELS_JSON")" = $'Tab\tSize' ]
}

@test "_load_config: label JSON escapes non-tab control characters" {
  printf '%s\n' \
    $'PRIORITY_0="Esc\ePriority"' \
    > "$CONFIG_FILE"

  _load_config "$TEST_PROJECT"

  echo "$PRIORITY_LABELS_JSON" | jq -e . > /dev/null
  [ "$(jq -r '.[0]' <<< "$PRIORITY_LABELS_JSON")" = $'Esc\ePriority' ]
}

@test "_sanitize_line: keeps escape bytes, trims whitespace, and flattens newlines" {
  result=$(_sanitize_line $'  \e[31mHello\e[0m \n world  ')
  [ "$result" = $'\e[31mHello\e[0m  world' ]
}

@test "_sanitize_text: keeps escape bytes and preserves newlines" {
  result=$(_sanitize_text $'\e[31mHello\e[0m\nworld')
  [ "$result" = $'\e[31mHello\e[0m\nworld' ]
}

@test "ask: exits non-zero when stdin is not a TTY" {
  run ask 'Title'
  [ "$status" -ne 0 ]
  [[ "$output" == *"stdin is not a TTY"* ]]
}
