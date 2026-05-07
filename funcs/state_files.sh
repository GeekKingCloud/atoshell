#!/usr/bin/env bash
# Project state file, ID, and ticket movement helpers for atoshell.

# ── State file setup ─────────────────────────────────────────────────────────
_ensure_files() {
  mkdir -p "$ATO_DIR"

  # _ensure_files is the canonical list of files in an atoshell directory.
  # .atoshell.example/ mirrors this structure with sample data; keep them in sync.
  [[ -f "$BACKLOG_FILE" ]] || printf '{"tickets":[]}\n' > "$BACKLOG_FILE"
  [[ -f "$QUEUE_FILE" ]]   || printf '{"tickets":[]}\n' > "$QUEUE_FILE"
  [[ -f "$DONE_FILE" ]]    || printf '{"tickets":[]}\n' > "$DONE_FILE"
  [[ -f "$META_FILE" ]]    || printf '{}\n' > "$META_FILE"

  # Seed next_id in meta.json if missing; scan existing tickets to avoid ID collisions.
  if [[ "$(jq '.next_id // null' "$META_FILE" 2>/dev/null)" == "null" ]]; then
    local seed
    seed=$(( $(jq -rs '[.[].tickets[].id] | max // 0' "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE") + 1 ))
    jq_inplace "$META_FILE" --argjson n "$seed" '.next_id = $n'
  fi
}

_setup() {
  local project_root

  project_root="$(_resolve_project)"
  _load_config "$project_root"
  _with_state_lock _ensure_files
}

_require_readable_state_files() {
  local file

  for file in "$BACKLOG_FILE" "$QUEUE_FILE" "$DONE_FILE"; do
    [[ -f "$file" ]] && continue
    printf 'Error: missing state file %s.\n' "$(_terminal_safe_line "$file")" >&2
    printf 'Run "atoshell update" to repair this project.\n' >&2
    exit 1
  done
}

_setup_readonly() {
  local project_root

  project_root="$(_resolve_project)"
  _load_config "$project_root"

  # Normal reads avoid the lock. If a writer or crash journal is visible, take
  # the lock once so transaction recovery can restore a consistent snapshot.
  if [[ -d "$(_state_lock_dir)" || -d "$(_state_transaction_dir)" ]]; then
    _with_state_lock :
  fi

  _require_readable_state_files
}

# ── Ticket file lookup and movement ──────────────────────────────────────────

# Find which file contains a ticket by id. Checks queue -> backlog -> done.
# Prints the file path to stdout, or exits with an informative error if not found.
_find_ticket_file() {
  local id="$1"
  local file
  local current_file

  for file in "$QUEUE_FILE" "$BACKLOG_FILE" "$DONE_FILE"; do
    current_file="$(_state_transaction_current_file "$file")"
    if [[ -f "$file" ]] &&
      jq -e --arg id "$id" 'any(.tickets[]; .id | tostring == $id)' "$current_file" >/dev/null 2>&1; then
      printf '%s\n' "$file"
      return
    fi
  done

  printf 'Error: ticket #%s not found.\n' "$(_terminal_safe_line "$id")" >&2
  exit 2
}

_move_ticket_json() {
  local src_file="$1"
  local dest_file="$2"
  local id="$3"
  local ticket="$4"

  jq_inplace "$dest_file" --argjson t "$ticket" '.tickets += [$t]'
  jq_inplace "$src_file" --arg id "$id" \
    'del(.tickets[] | select(.id | tostring == $id))'
}

# ── ID and UUID helpers ──────────────────────────────────────────────────────

# Claim the next ticket id from meta.json and increment the counter.
# This is the only place new IDs should be allocated.
_next_id() {
  local id meta_file

  meta_file="$(_state_transaction_current_file "$META_FILE")"
  id="$(jq '.next_id' "$meta_file")"
  jq_inplace "$META_FILE" '.next_id += 1'

  printf '%s' "$id"
}

# Generate a UUID for ticket identity.
# Prefer procfs when available, otherwise use a Bash-native v4-style fallback.
_get_uuid() {
  local part1 part2 part3 part4_low part4_high part5a part5b part5c pid_low

  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    tr -d '\r\n' < /proc/sys/kernel/random/uuid
    return 0
  fi

  pid_low=$(( BASHPID & 0xffff ))
  part1=$(( (((RANDOM & 0xffff) ^ pid_low) << 16) | (RANDOM & 0xffff) ))
  part2=$(( RANDOM & 0xffff ))
  part3=$(( RANDOM & 0x0fff ))
  part4_high=$(( 8 + (RANDOM % 4) ))
  part4_low=$(( RANDOM & 0x0fff ))
  part5a=$(( RANDOM & 0xffff ))
  part5b=$(( RANDOM & 0xffff ))
  part5c=$(( (RANDOM ^ pid_low) & 0xffff ))

  printf '%08x-%04x-4%03x-%x%03x-%04x%04x%04x' \
    "$part1" "$part2" "$part3" "$part4_high" "$part4_low" "$part5a" "$part5b" "$part5c"
}

# ── Gitignore helpers ────────────────────────────────────────────────────────
_sync_gitignore() {
  local file="$1"
  local tmp tmp_next

  [[ -f "$file" ]] || touch "$file"

  tmp="$(_mktemp_sibling "$file")"
  tmp_next="$(_mktemp_sibling "$file")"

  grep -vxF '.atoshell/archive.json' "$file" > "$tmp" || true
  grep -vxF '.atoshell/done.json' "$tmp" > "$tmp_next" || true
  mv -f "$tmp_next" "$file"
  rm -f "$tmp"

  grep -qF '.atoshell/*.env' "$file"          || printf '.atoshell/*.env\n' >> "$file"
  grep -qF '.atoshell/meta.json' "$file"      || printf '.atoshell/meta.json\n' >> "$file"
  grep -qF '.atoshell/.lock/' "$file"         || printf '.atoshell/.lock/\n' >> "$file"
  grep -qF '.atoshell/.transaction/' "$file"  || printf '.atoshell/.transaction/\n' >> "$file"
}
