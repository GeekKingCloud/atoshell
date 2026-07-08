# Changelog

## [2.2.3]

### Changed

- Aligned README command guidance, command descriptions, help/menu text, and column spacing with the shared Atoshell style.
- Tightened workflow shard names and package smoke behavior so CI output stays descriptive and failures preserve useful exit status.
- Expanded the style guide with measured alignment rules for command menus, help output, dispatcher headers, README tables, and related agent docs.
- Reworked project config sync to regenerate `config.env` from the canonical template, preserving supported values while restoring explanatory comments and dropping stale unsupported keys.

### Tests

- Pruned brittle docs-adjacent assertions while keeping functional coverage for help/menu rendering, package metadata, command contracts, and visible CLI output.
- Consolidated removed-scope and discipline test coverage, refined command parity checks, and pinned drift-prone help/menu alignment rows.
- Covered template-based config sync so updates no longer append sparse `Added by atoshell update` fragments.

## [2.2.2]

### Changed

- Documented dependency-budget ranking for `show next` / `take next`, including the cleanup-budget model used to promote blockers for valuable tickets.
- Added JSON output for `edit`, `comment`, `move`, and `delete`, with structured errors for their non-interactive automation paths.

### Fixed

- Rejected `show board --json` with a structured error instead of mixing a human board view with JSON mode.
- Kept `show next --json` from marking dependency-free ready tickets as blocked in the default fixture.
- Kept `edit --json --depends add <missing>` on the structured `DEP_NOT_FOUND` error path.
- Kept `move --json` multi-ticket failures from leaving a pending transaction marker.
- Kept package metadata/version tests aligned with the current `VERSION` file.

## [2.2.1]

### Fixed

- Updated the README logo background to match GitHub's `rgb(33, 40, 48)` surface color.
- Released a patch version because npm package versions are immutable, so the README/logo fix also validates the new GitHub release-triggered npm publishing workflow.

## [2.2.0]

### Changed

- Added npm-compatible package metadata for Bun/npm global installs.
- Added package-manager guidance for package-installed update and uninstall paths.
- Added GitHub release-triggered npm publishing through trusted publishing/OIDC.
- Switched the README logo to a dark-background asset so it remains legible on npm's light package page.

### Tests

- Added npm/Bun package smoke coverage and grouped Linux, macOS, and Windows smoke checks under an OS smoke matrix.
- Added package dry-run coverage for the README logo asset.

## [2.1.2]

### Changed

- Added contributor and security guidance for open-source project hygiene.
- Added social preview source and exported image assets.
- Changed the default CLI install checkout from `~/.atoshell` to `~/atoshell`.
- Normalized shared `funcs/` headers, section banners, and spacing to match the
  project style guide.
- Clarified `STYLE.md` guidance for data-only helper modules, section banners,
  and directly-sourceable modules.

### Fixed

- Kept config synchronization from treating comments or shebang lines in
  `funcs/config_vars.sh` as project config defaults.

## [2.1.1]

### Fixed

- Shortened `edit`, `comment`, and `delete` write-lock windows so interactive
  prompts no longer hold the shared state lock.
- Revalidated mutable ticket, comment, dependency, discipline, and accountable
  state under lock before committing edits or deletes.
- Fixed invalid dependency removals such as `edit --dependencies remove abc` so
  they fail validation instead of silently succeeding as no-ops.
- Avoided stamping edit audit fields when a valid remove operation only emits
  warnings and makes no ticket changes.
- Kept `delete --yes` dependency cleanup correct when dependents appear between
  preflight and lock acquisition.

### Changed

- Split bulk import planning and validation helpers out of `add.sh` into
  `funcs/add_import.sh`.
- Added `_outln` for literal line output and moved pre-rendered/user-controlled
  command messages away from formatted `_outf` calls.

### Tests

- Added regression coverage for prompt-failure lock cleanup, edit remove
  revalidation, delete dependency cleanup under lock, install fast-forward
  updates, and literal `_outln` output.
- Verified the full Bats suite: 1,035 tests passing.

## [2.1.0]

### Changed

- Raised the supported shell baseline to Bash 4.3+ across runtime, installer,
  documentation, and CI smoke coverage.
- Added Linux, macOS, and Windows smoke checks for repo-local and installed
  launchers.
- Made smoke-test dependency setup self-contained for GitHub-hosted runners.
- Updated GitHub Actions checkout usage to the Node 24-compatible action.
- Clarified install and update guidance for Linux, Git Bash, and macOS Homebrew
  Bash.
- `list` now accepts board column numbers `1`-`4` as scope aliases and keeps
  `queue` as the explicit active-queue scope.
- `show board --full` / `-f` now wraps full ticket titles across multiple board
  lines; `--all` keeps the previous full-board behavior.
- Removed the one-letter `list q` and `list d` scope aliases.
- Removed the `edit --move` alias; use `edit --status` / `-S` instead.

### Fixed

- Guarded Bash 4.3 empty-array expansion behavior across ticket mutation paths.
- Tightened comma-separated argument validation so empty fields fail before
  partially mutating ticket state.
- Preserved `agent-1` style accountable values while still supporting `agent`
  as shorthand for `[agent]`.
- Avoided unnecessary fallback noise in macOS smoke setup when Homebrew
  dependencies are already installed.

## [2.0.0]

Initial public release of Atoshell. This is the first supported release; earlier
v1 history is intentionally omitted because v1 was withdrawn before this release
track.

### Current Status

- Standalone terminal ticket manager for project-local `.atoshell/` state.
- Shared workflow state lives in `queue.json`, `backlog.json`, and `done.json`.
- Local-only project settings live in `config.env`, with local ID metadata in `meta.json`.
- Supported installed command names are `atoshell` and `ato`.
- Version output is backed by the checked-in `VERSION` file.
- Bash 4.3+ is the supported shell baseline; stock macOS `/bin/bash` exits early with modern Bash install guidance.

### Workflow

- Default workflow columns are `Backlog`, `Ready`, `In Progress`, and `Done`.
- Tickets support title, description, status, priority, size, type, disciplines, accountable users, dependencies, comments, UUIDs, and audit timestamps.
- Direct commands cover initialization, ticket CRUD, listing, search, claiming, comments, moves, install, update, uninstall, help, and version output.
- `take next` claims the highest-ranked ready ticket, with filters for type, priority, size, and fixed discipline tags.
- Dependencies are considered satisfied only when the dependency ticket is `Done`.
- `show <id>` reports computed `blocked`, `blocked_by`, and `blocking` dependency context.
- `list blockers` surfaces dependency-focused queue state.

### Automation

- `--json` / `-j` provides structured output for automation-friendly reads and mutations.
- Failed JSON-mode commands write structured error objects to stderr while keeping stdout clean.
- Non-TTY runs attribute work to `[agent]` by default.
- `--as <agent-N|number>` supports numbered agent attribution in non-interactive orchestrator contexts.
- Bulk import accepts JSON arrays from files or stdin and validates the full batch before writing tickets.
- Bulk import uses project-configured type, priority, size, and ready-status defaults for omitted fields.

### Configuration

- Project config is parsed as data, not sourced as shell code.
- New project config creation uses the packaged template or generated defaults.
- Status, type, priority, and size labels are configurable through `.atoshell/config.env`.
- Discipline tags are fixed Atoshell options: `Frontend`, `Backend`, `Database`, `Cloud`, `DevOps`, `Architecture`, `Automation`, `QA`, `Research`, and `Core`.
- Discipline parsing is case-insensitive and supports `fe` / `be` shorthand for `Frontend` / `Backend`.
- `ATOSHELL_TIMEZONE` controls audit timestamp formatting and supports UTC or IANA timezone names.

### Install And Update

- Installer targets the user home directory and writes launchers under the standard user-local bin path.
- Windows Git Bash installs also write `atoshell.cmd` and `ato.cmd` for PowerShell and `cmd.exe`.
- Git-based installs update with `git pull --ff-only`.
- Non-git installs print the manual reinstall command instead of executing a remote installer fallback.
- `update --walk` can search parent directories for a project to update.
- `uninstall` removes installed launchers without touching project ticket data.
- `uninstall` removes both shell launchers and Windows `.cmd` launchers.

### Documentation And Tests

- README documents installation, commands, configuration, disciplines, data storage, JSON schema, and agent workflows.
- AGENTS.md documents agent-facing workflow, orchestration, and JSON-contract guidance.
- STYLE.md documents contributor conventions and source-of-truth rules.
- Bats coverage exercises command routing, config helpers, install/update/uninstall, ticket CRUD, comments, ranking, dependency context, filters, search, import validation, JSON output, and structured errors.
- CI runs syntax checks, named Linux Bats shards, and a Windows Git Bash smoke path for launcher behavior.
