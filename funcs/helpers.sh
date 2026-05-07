#!/usr/bin/env bash
# helpers.sh — compatibility aggregator for atoshell command scripts
#
# Source this file from any command script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/funcs/helpers.sh"

_ATOSHELL_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helper modules ────────────────────────────────────────────────────────────
source "$_ATOSHELL_HELPERS_DIR/path.sh"
source "$_ATOSHELL_HELPERS_DIR/terminal.sh"
source "$_ATOSHELL_HELPERS_DIR/config.sh"
source "$_ATOSHELL_HELPERS_DIR/state.sh"
source "$_ATOSHELL_HELPERS_DIR/tickets.sh"
source "$_ATOSHELL_HELPERS_DIR/prints.sh"
