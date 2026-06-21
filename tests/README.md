# atoshell — Tests
Unit tests for the atoshell CLI using [bats-core](https://github.com/bats-core/bats-core).

## One-time setup
Install bats system-wide (required once per machine):

```bash
# macOS
brew install bash bats-core jq git

# Ubuntu/Debian
sudo apt install bats

# or see https://github.com/bats-core/bats-core
```

## Run focused tests
```bash
bats tests/unit/add.bats
```

On Windows, start with the smallest relevant file from the repo root through the Git Bash-backed Bats launcher:

```powershell
bats.cmd --print-output-on-failure tests/unit/add.bats
```

## Run all tests
```bash
bats tests/unit/
```

On Windows, reserve the full suite for a final confidence pass after focused files are green:

```powershell
bats.cmd --print-output-on-failure tests/unit
```

## Syntax check only
```bash
bash -n atoshell.sh
```

## Test layout
Each test gets a fresh isolated project directory (`$BATS_TEST_TMPDIR/myproject`)
populated from `tests/fixtures/`. Tests cannot interfere with each other.

- **`unit/atoshell.bats`**   — top-level routing, aliases, `--help`, `--quiet`, unknown commands
- **`unit/config.bats`**     — config sync helpers, non-TTY prompt guards, and text sanitization
- **`unit/helpers.bats`**    — internal helpers: config loading, ID generation, status/type/discipline resolvers, terminal-safe error helpers, `jq_inplace`
- **`unit/install.bats`**    — `atoshell install`: wrapper creation, PATH advisory, dependency checks
- **`unit/uninstall.bats`**  — `atoshell uninstall`: wrapper removal and non-TTY confirmation behavior
- **`unit/init.bats`**       — `atoshell init`: project creation, `.gitignore` integration, idempotency
- **`unit/update.bats`**     — `atoshell update`: git self-update, manual reinstall fallback, project file and config sync
- **`unit/add.bats`**        — `atoshell add`: flags, defaults, field storage, routing by status, `--import` bulk import with two-pass validation, `--json` output and structured errors
- **`unit/algorithms.bats`** — direct ranking, dependency, and blocker helper coverage
- **`unit/parser.bats`**     — parser-contract tests for unknown options, missing values, unexpected positional args, and JSON-mode stderr/stdout failures on manually parsed commands
- **`unit/package.bats`**    — npm-compatible package metadata and package dry-run coverage
- **`unit/prints.bats`**     — direct rendering coverage for board, blocker, banner, and quiet-mode behavior
- **`unit/state.bats`**      — direct state helper coverage for locks, atomic writes, transaction recovery, and concurrent ID allocation
- **`unit/show.bats`**       — `atoshell show`: ticket detail display, board view, `show next`, dep context (`blocked_by`/`blocking`) in human and JSON output, structured errors (`TICKET_NOT_FOUND`, `NO_READY_TICKETS`, `INVALID_TICKET_ID`)
- **`unit/edit.bats`**       — `atoshell edit`: all field mutations, status-driven file moves, `--as` audit stamping
- **`unit/delete.bats`**     — `atoshell delete`: single and multi-ID removal across files, dependency cleanup on deletion
- **`unit/move.bats`**       — `atoshell move`: within-file and cross-file transfers, `--as` audit stamping
- **`unit/comment.bats`**    — `atoshell comment`: add, update, and delete subcommands, `--as` comment authorship
- **`unit/take.bats`**       — `atoshell take`: assign by ID or next, `--as <agent-N|N>` numbered-agent assignment, status/accountable warnings, `--type`/`--discipline` filters, JSON output, structured errors (`TICKET_NOT_FOUND`, `NO_READY_TICKETS`, `TICKET_CLOSED`, `TICKET_ALREADY_ASSIGNED`, `TICKET_ALSO_ASSIGNED`, `INVALID_TICKET_ID`)
- **`unit/list.bats`**       — `atoshell list`: scopes, filters, topo-sort ranking, blockers, custom priority ordering
- **`unit/search.bats`**     — `atoshell search`: title, description, comments, disciplines, and metadata matching

## Fixtures
Pre-populated ticket state loaded into every test:

- **`fixtures/queue.json`**           — three active tickets spanning Ready and In Progress, varied priorities (P1–P3) and sizes (S/M/XS), one ticket with a comment, and ticket 3 depending on ticket 1 (used by dep-context tests)
- **`fixtures/backlog.json`**         — single Backlog ticket at XL size; confirms cross-file isolation and backlog scope
- **`fixtures/done.json`**            — single Done ticket at P0; confirms done scope and exclusion from queue views
- **`fixtures/meta.json`**            — local-only ID counter fixture; seeds `next_id` for deterministic creation tests
- **`fixtures/import_example.json`**  — three-ticket `--import` import fixture: one defaults-only ticket, one Bug/P0/S, one Backlog Task; 2 route to queue and 1 to backlog for predictable count assertions

Tests that need specific dependencies, accountable, disciplines, or ranking scenarios set up their own inline fixtures within the test body.

Interactive success paths are not simulated with hidden environment overrides.
Prompting behavior is covered by non-TTY guard tests; manual CLI use exercises
the real terminal path.
