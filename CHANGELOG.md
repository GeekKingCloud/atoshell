# Changelog

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

- Installer targets `~/.atoshell` and writes launchers under the standard user-local bin path.
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
