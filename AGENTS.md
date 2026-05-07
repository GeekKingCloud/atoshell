# atoshell — Agent Guide

This file is intended for AI coding agents. For human documentation see [README.md](README.md).

---

**For AI assistants:** See [STYLE.md](STYLE.md) for command patterns and project conventions.

## When Working On Atoshell Itself

When you are changing atoshell core rather than using atoshell to manage another project, treat these files as one public surface:

- `atoshell.sh`
- `bin/atoshell`
- `bin/ato`
- `VERSION`
- `README.md`
- `AGENTS.md`
- `STYLE.md`
- `tests/README.md`

If a change affects command names, aliases, help text, wrapper behavior, install/update expectations, JSON output, or the visible CLI framing, update the matching docs and tests in the same change.

Installer behavior:

- `install.sh` installs Atoshell from its canonical repository into `~/.atoshell` by default.
- The installed command names are `atoshell` and `ato`; do not add alternate branded command names.
- On Windows/Git Bash, the installer also writes `atoshell.cmd` and `ato.cmd` beside the shell launchers so PowerShell and `cmd.exe` resolve the installed commands.
- `atoshell update` uses `git pull --ff-only` for git-based installs. If the install is not a git checkout, it prints the manual reinstall command and does not execute a remote installer fallback.
- Do not add repo-source overrides or project-local paths for testing local checkouts.
- Do not create coding-agent-owned scratch or capture folders such as `codex-logs`, `.codex`, `agent-logs`, or `scratch` inside `.reef/`, `.lumberhack/`, `.atoshell/`, generated runtime folders, or worker worktrees. Tool-owned runtime logs remain in their documented tool paths. Put disposable agent captures under `$env:TEMP\codex\...` and durable agent scratch under `C:\Users\thete\.codex\scratch\...`.

## Repo Workflow For Agents

Prefer this loop when working inside the atoshell repo:

```bash
bash atoshell.sh help
bash bin/atoshell help
bats tests/unit/<file>.bats          # Unix
bats.cmd --print-output-on-failure tests/unit/<file>.bats  # Windows
```

Use the repo-local wrappers when checking shipped entrypoints, but keep `atoshell.sh` as the canonical dispatcher source.

For user-facing rendering changes, compare the runtime output to the examples in `README.md` rather than treating the docs as approximate.

## Canonical workflow

```
atoshell take next --json           # claim the highest-priority ready ticket
  → work on the task
atoshell comment <id> "<progress>"  # log findings or decisions mid-task
atoshell move <id> done             # close when complete
```

`take` auto-detects non-TTY stdin and assigns `[agent]` instead of a user name. No flag needed. Use `--as <agent-N|number>` to assign to a specific numbered agent (for example, `agent-1` or `1`) instead of the generic sentinel. `--as` is only allowed in non-interactive mode; bare positive integers are normalized to `agent-N`. Do not pass `[agent]` to `--as`; omit `--as` when the generic non-TTY actor is intended.

---

## Reading state

All structured output uses `--json` / `-j`. Prefer it over parsing human output.

| Goal                             | Command                               |
|----------------------------------|---------------------------------------|
| Best available ticket            | `atoshell show next --json`           |
| Claim it and get full details    | `atoshell take next --json`           |
| Inspect a specific ticket        | `atoshell show <id> --json`           |
| Active queue                     | `atoshell list --json`                |
| Filter by status                 | `atoshell list --status done --json`  |
| Backlog                          | `atoshell list backlog --json`        |
| Your current assignments         | `atoshell list --agent --json`        |
| Tickets blocked by dependencies  | `atoshell list blockers --json`       |
| Full-text search                 | `atoshell search "<query>" --json`    |

`show next` only surfaces tickets that are unassigned or already assigned to the current user. `take` with no ticket argument defaults to `take next`. `take next` pulls from all ranked ready tickets regardless of assignee.

### Dependency fields on `show <id>`

`show <id> --json` always includes three extra fields:

```json
{
  "blocked":    true,
  "blocked_by": [{"id": 1, "title": "Fix login bug", "status": "Ready"}],
  "blocking":   [{"id": 7, "title": "Downstream task", "status": "Backlog"}]
}
```

| Field         | Meaning                                                 |
|---------------|---------------------------------------------------------|
| `blocked`     | `true` if any dependency is not yet Done                |
| `blocked_by`  | Dependencies that are still open (not Done)             |
| `blocking`    | Non-Done tickets that list this ticket as a dependency  |

These are also shown in the human-readable `show <id>` output. The same satisfied-dependency rule applies as in the ranking algorithm: only `Done` counts as resolved.

---

## Scoping work

`take next` accepts filters to constrain which ticket is selected:

```bash
atoshell take next --disciplines Backend --priority P0,P1 --json
atoshell take next --type Bug --size XS,S --json
```

`--priority`, `--size`, and `--type` also accept numeric indices as shorthand:

| Flag          | Indices  | Labels              |
|---------------|----------|---------------------|
| `--priority`  | `0`–`3`  | P0, P1, P2, P3      |
| `--size`      | `0`–`4`  | XS, S, M, L, XL     |
| `--type`      | `0`–`2`  | Bug, Feature, Task  |

This applies to `add`, `edit`, `list`, and `take` filters.

Discipline filters accept comma-separated fixed discipline names
case-insensitively. `fe` and `be` are accepted as shorthand for `Frontend` and
`Backend`.

Filters can be combined freely. If no ticket matches, the command exits with a non-zero code and an error on stderr — treat this as "nothing to do."

---

## Disciplines

Disciplines describe the kind of work a ticket requires. They are fixed Atoshell options, not project config. Use them to filter `take next` to tickets that match your capabilities, and to tag tickets accurately when creating them via `add`, `edit`, or `add --import`.

| Discipline      | Work it covers                                                                          | Typical agent role                  |
|-----------------|-----------------------------------------------------------------------------------------|-------------------------------------|
| `Frontend`      | UI components, client-side logic, styling, browser APIs, user-facing interactions       | Frontend / fullstack agent          |
| `Backend`       | Server-side logic, REST/GraphQL APIs, services, business rules, data processing         | Backend / fullstack agent           |
| `Database`      | Schema design, migrations, queries, indexing, data modelling                            | Backend or DBA-specialist agent     |
| `Cloud`         | Cloud infrastructure, managed services (AWS/GCP/Azure), hosting, networking, scaling    | Infrastructure / cloud agent        |
| `DevOps`        | CI/CD pipelines, deployment, containerisation, monitoring, operational tooling          | DevOps / platform agent             |
| `Architecture`  | System design, technical decisions, service boundaries, cross-cutting concerns, ADRs    | Architect or senior agent           |
| `Automation`    | Scripting, workflow automation, task runners, build tooling (non-test)                  | Tooling / platform agent            |
| `QA`            | Test writing (unit/integration/e2e), testing strategy, quality gates, bug verification  | QA or general-purpose agent         |
| `Research`      | Spike work, feasibility studies, technology evaluation, documenting unknowns            | Any agent capable of investigation  |
| `Core`          | Shared libraries, foundational utilities, cross-service primitives, platform internals  | Backend or platform agent           |

A ticket may carry multiple disciplines. When tagging, use the narrowest set that accurately reflects the work — don't add disciplines speculatively.

---

## Structured errors

When `--json` is passed and a command fails, the error is written to stderr as a JSON object instead of plain text:

```json
{"error": "NO_READY_TICKETS"}
{"error": "TICKET_NOT_FOUND", "id": "42"}
{"error": "TICKET_CLOSED", "id": "3", "status": "Done"}
{"error": "INVALID_TICKET_ID", "got": "abc"}
```

This lets agents branch on failure type without parsing human-readable strings. Errors always go to stderr; stdout remains empty on failure.

| Code                       | Command                   | Meaning                                                                                |
|----------------------------|---------------------------|----------------------------------------------------------------------------------------|
| `NO_READY_TICKETS`         | `show next`, `take next`  | No unblocked ready ticket available                                                    |
| `TICKET_NOT_FOUND`         | `show`, `take`            | ID not found in any file                                                               |
| `TICKET_CLOSED`            | `take`                    | Ticket is Done — use `--force` to override                                             |
| `TICKET_ALREADY_ASSIGNED`  | `take`                    | Ticket is assigned to other users; agent is not yet on it — use `--force` to override  |
| `TICKET_ALSO_ASSIGNED`     | `take`                    | Ticket is assigned to agent and one or more others — use `--force` to suppress         |
| `INVALID_TICKET_ID`        | `show`, `take`            | Argument is not a numeric ID                                                           |
| `FILE_NOT_FOUND`           | `add --import`            | Import file path does not exist                                                        |
| `INVALID_JSON`             | `add --import`            | Input is not parseable JSON                                                            |
| `INVALID_FORMAT`           | `add --import`            | Input is valid JSON but not an array                                                   |
| `VALIDATION_FAILED`        | `add --import`            | One or more items failed pre-write validation; includes `count` and `errors` array     |
| `UNKNOWN_OPTION`           | JSON-capable commands     | Unsupported CLI option when `--json` / `-j` was requested                              |
| `UNEXPECTED_ARGUMENT`      | JSON-capable commands     | Extra or unsupported positional argument when `--json` / `-j` was requested            |
| `MISSING_ARGUMENT`         | JSON-capable commands     | Required argument or flag value is missing when `--json` / `-j` was requested          |
| `INVALID_TYPE`             | `add`, `list`, `take`     | Type value or type filter is invalid                                                   |
| `INVALID_PRIORITY`         | `add`, `list`, `take`     | Priority value or priority filter is invalid                                           |
| `INVALID_SIZE`             | `add`, `list`, `take`     | Size value or size filter is invalid                                                   |
| `INVALID_STATUS`           | `add`, `list`             | Status value is invalid                                                                |
| `INVALID_DISCIPLINE`       | `add`, `list`, `take`     | Discipline value or discipline filter is invalid                                       |
| `INVALID_DEPENDENCY`       | `add`                     | Dependency value is not a numeric ticket ID                                            |
| `DEP_NOT_FOUND`            | `add`                     | Dependency ticket ID does not exist                                                    |
| `INVALID_ACTOR`            | `add`, `take`             | `--as` value is not a positive number or `agent-N`                                     |
| `INVALID_ARGUMENT`         | `add`, `take`             | Mutually exclusive or unsupported argument combination                                 |

`VALIDATION_FAILED` carries the full error list so the caller can fix and retry:

```json
{
  "error": "VALIDATION_FAILED",
  "count": 2,
  "errors": [
    {"type": "MISSING_TITLE", "item": "[item 0]"},
    {"type": "DEP_NOT_FOUND", "item": "[item 2]", "dep": "99"}
  ]
}
```

Nested `VALIDATION_FAILED.errors[].type` values include:

| Code                    | Meaning                                                         |
|-------------------------|-----------------------------------------------------------------|
| `MISSING_TITLE`         | Imported item has no title                                      |
| `INVALID_TYPE`          | Imported item has an invalid type                               |
| `INVALID_PRIORITY`      | Imported item has an invalid priority                           |
| `INVALID_SIZE`          | Imported item has an invalid size                               |
| `INVALID_STATUS`        | Imported item has an invalid status                             |
| `INVALID_IMPORT_ID`     | Imported item uses a non-numeric batch-local `id`               |
| `INVALID_DEP_ID`        | Imported item contains a non-numeric dependency                 |
| `DEP_NOT_FOUND`         | Imported item depends on a missing ticket or batch-local id     |
| `SELF_DEPENDENCY`       | Imported item depends on itself after batch-local id remapping  |
| `DUPLICATE_IMPORT_ID`   | Import batch reuses the same batch-local `id` more than once    |
| `DEP_CYCLE`             | Import batch contains a dependency cycle                        |

---

## Contributor Guardrails

- Keep human-facing output ASCII-framed and column-aligned so `README.md` examples stay true to the actual CLI.
- Prefer `--json` for reads in tests and automation; do not parse decorative human output when a structured path exists.
- Keep machine-readable errors on stderr and leave stdout clean on failure.
- When changing ticket schema, status rules, import validation, or structured errors, update this file and the relevant unit tests in the same change.
- Do not add runtime dependencies on Reef, Lumberhack, Octopush, Goldfish, or external planning tools.

---

## Logging progress

Comments are the right place to record findings, decisions, or partial results mid-task. Author is set to `[agent]` automatically in non-TTY contexts, or to a numbered agent when the orchestrator passes `--as <agent-N|number>`.

```bash
atoshell comment <id> "Identified root cause: ..."
atoshell comment <id> --as agent-1 "Identified root cause: ..."
atoshell comment <id> "Blocked — dependency #4 must ship first"
```

---

## Moving tickets

```bash
atoshell move <id> done         # complete
atoshell move <id> in progress  # reopen
atoshell move <id> 1            # column number: 1=Backlog 2=Ready 3=In Progress 4=Done
```

Multi-word statuses do not need quotes in `move`, `edit`, `list`, or `add`. `--quiet` suppresses output.

---

## Bulk ticket intake

When an upstream process (LLM breakdown, planning bot) produces a structured list of tickets, import them in a single call:

```bash
atoshell add --import tickets.json
atoshell add --import -             # read from stdin
```

**Input format** — a JSON array of ticket objects:

```json
[
  {
    "id": 9,
    "title": "Set up CI pipeline",
    "description": "Configure GitHub Actions for lint, test, build",
    "type": "Task",
    "priority": "P1",
    "size": "M",
    "status": "Ready",
    "disciplines": ["DevOps", "Automation"],
    "accountable": ["agent-1"],
    "dependencies": []
  },
  {
    "id": 11,
    "title": "Add integration tests",
    "priority": "P2",
    "dependencies": [9]
  }
]
```

Only `title` is required. All other fields fall back to the project's configured defaults (`TYPE_2`, `PRIORITY_2`, `SIZE_2`, `STATUS_READY`; stock labels: `Task`, `P2`, `M`, `Ready`). `description` / `body` are both accepted. If an imported item includes an `id`, atoshell treats it as a batch-local reference and remaps it to a fresh local ID during import; dependencies that point at other imported items are rewritten to those new IDs automatically.

**Validation** runs before any ticket is written. Structural errors (missing title, non-existent dependency IDs, non-numeric deps) are all reported upfront and nothing is created until the batch is clean. Invalid field values (bad type/priority/size/status) are caught per-item by the standard resolvers with clear error messages.

---

## Parallel agents and dependency ordering

When multiple agents work concurrently, use **stacked branches** for tickets that have code dependencies:

- Branch off the dependency's feature branch, not `main`
- When the dependency merges, rebase the downstream branch onto `main`
- Keep the ticket dependency unresolved in atoshell until the dependency ticket is actually `Done`

```
main
└── feature/ticket-1          ← dependency branch
    └── feature/ticket-2      ← stacked downstream work
```

Review and PR state are external workflow context, not persisted ticket statuses. The orchestrator is responsible for tracking which branch to base work on and triggering rebases after merges.

`done.json` is shared project state. Only local config and ID metadata stay in gitignored files.

An orchestrator can distribute work to numbered sub-agents using `--as`:

```bash
atoshell take next --as agent-1 --json   # claim highest-priority ticket for agent-1
atoshell take next --as agent-2 --json   # claim next ticket for agent-2
atoshell take 42   --as agent-3 --json   # assign a specific ticket to agent-3
```

Sub-agents then filter their own queue with `--accountable`:

```bash
atoshell list --accountable agent-1 --json
```

For non-code dependencies (research, design decisions) the same rule applies — keep the dependency open until the output is actually final enough to count as done.

---

## Testing on Windows

On Windows, run Bats suites from the repo root with `bats.cmd` so the Bash-based test harness goes through the local Git Bash / MSYS install instead of relying on shell discovery.

If `bash.exe`, `bats.cmd`, or an installed `.cmd` launcher fails before the suite or command starts with Git Bash / MSYS errors such as `Win32 error 5`, `CreateFileMapping`, or `couldn't create signal pipe`, treat that as a sandbox/process-isolation issue rather than an Atoshell, adapter, or repo test failure. Confirm with the smallest raw Git Bash smoke check:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "echo bash-ok"
```

If that smoke check fails in the sandbox but succeeds outside it, rerun the same Atoshell/Bats command outside the sandbox or approve an escalated run. Do not add adapter-specific routing, project-local paths, alternate launchers, or code workarounds for this symptom.

When running a coding agent on Windows, prefer starting `atoshell`, `bats.cmd`, and other Git Bash-backed tool commands outside the sandbox from the start. Sandboxed Git Bash / MSYS runs can fail before startup or leave stray `bash.exe` processes behind after timeouts, which can make later retries misleading.

Do not start verification with giant combined Bats suites on Windows. They often exceed tool timeouts and waste time without producing a useful failing assertion. Prefer the smallest relevant `tests/unit/<file>.bats`, then one exact `--filter` if needed, and use direct Git Bash CLI smoke checks for the command paths you changed. If a broad suite times out, stop it, check for leftover `bash.exe` processes, and switch to focused verification instead of retrying the same large command.

When a coding agent or orchestrator needs to call `atoshell ... --as ...`, make the process genuinely non-interactive by giving the command non-TTY stdin, for example by running it from a background/non-interactive process or redirecting stdin from null in the caller.

Final confidence pass:

```bat
bats.cmd --print-output-on-failure tests/unit
```

For quick CLI checks outside the full suite, prefer explicit Git Bash commands against the shipped entrypoints:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd '/c/.../atoshell' && ./atoshell.sh help"
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd '/c/.../atoshell' && ./bin/atoshell help"
```

---

## Edge cases

| Situation                           | Behaviour                                                                                                                        |
|-------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| No ready tickets                    | `take next` / `show next` exit 1 with error on stderr — stop gracefully                                                          |
| Ticket already Done                 | `take <id> --force` to override — also suppresses all warnings; cannot be used with `next`                                       |
| Ticket has unresolved dependencies  | It will not appear in `show next` / `take next` — check `list blockers`                                                          |
| Ticket already assigned to others   | `take` exits 1 with `TICKET_ALREADY_ASSIGNED` (or `TICKET_ALSO_ASSIGNED` if agent is already on it) — use `--force` to override  |
| Ticket already In Progress          | `take` warns but still moves to In Progress — use `--force` to suppress the warning                                              |

---

## Ticket schema (JSON)

```json
{
  "id": 1,
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Fix login bug",
  "description": "Full details here",
  "status": "In Progress",
  "priority": "P1",
  "size": "S",
  "type": "Bug",
  "disciplines": ["Backend"],
  "accountable": ["[agent]"],
  "dependencies": [3],
  "comments": [
    { "author": "[agent]", "text": "Root cause found", "created_at": "..." }
  ],
  "created_by": "[agent]",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_by": "[agent]",
  "updated_at": "2024-01-02T00:00:00Z",
  "blocked":    false,
  "blocked_by": [],
  "blocking":   [{"id": 5, "title": "Deploy hotfix", "status": "Ready"}]
}
```

Timestamp fields use the project `.atoshell/config.env` setting
`ATOSHELL_TIMEZONE`. `UTC` keeps `...Z` timestamps. Use IANA timezone names such
as `ATOSHELL_TIMEZONE="America/Mexico_City"` for local timestamps with an
ISO-8601 offset such as `2026-04-23T23:00:00-06:00`.

`status` values follow the project's `config.env` labels (defaults: `Backlog`, `Ready`, `In Progress`, `Done`). When in doubt, use column numbers with `move`.

`blocked`, `blocked_by`, and `blocking` are computed at read time by `show <id> --json` — they are not stored on the ticket.
