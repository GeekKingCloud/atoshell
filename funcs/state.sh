#!/usr/bin/env bash
# Project state helper aggregator for atoshell.

_ATOSHELL_STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Internal state flags are process-owned; ignore same-named environment values.
_STATE_LOCK_HELD=false
_STATE_TRANSACTION_ACTIVE=false
_STATE_TRANSACTION_OWNS_LOCK=false

# ── State helper modules ─────────────────────────────────────────────────────
source "$_ATOSHELL_STATE_DIR/state_lock.sh"
source "$_ATOSHELL_STATE_DIR/state_transactions.sh"
source "$_ATOSHELL_STATE_DIR/state_files.sh"
