<p align="center">
  <img src="branding/logo.svg" alt="atoshell" width="400">
</p>

A lightweight, curl-installable, agentic-first terminal ticket tracker. Manage tasks in plain JSON files — no account, no cloud, no setup friction.

## Install
```bash
curl -fsSL https://raw.githubusercontent.com/GeekKingCloud/atoshell/main/install.sh | bash
```

Requires: `bash`, `jq`, `git`

Check the installed CLI version with `atoshell version` or `atoshell -v`.

On Windows, run the installer from Git Bash. It installs the `atoshell` and `ato`
shell launchers and also writes `atoshell.cmd` and `ato.cmd` so PowerShell and
`cmd.exe` can invoke the same installed CLI names.

## Quick start
```bash
cd /path/to/project
atoshell init                  # set up .atoshell/ in the current directory
atoshell add "Fix the thing"   # create a ticket
atoshell show board            # ASCII kanban view (3 active columns by default)
atoshell list                  # list active tickets
atoshell take next             # assign the best ticket (priority/size considered) to me and move to 'In Progress'
atoshell move 1 in progress    # move ticket #1 (workflow transition)
atoshell move 1 3              # same — column 3 = In Progress
atoshell move 1 4              # mark done (column 4)
atoshell edit 1 --priority p1  # also works via edit
```

Run `atoshell` with no arguments for an interactive menu:

```
+--------------------------------------------------+
|            atoshell — Menu                       |
+--------------------------------------------------+

  0) init        — Initialise .atoshell/ in current directory
  1) add         — Create a new ticket
  2) show        — Show a ticket, next ready ticket, or kanban board
  3) edit        — Edit ticket properties
  4) delete      — Delete a ticket
  5) list        — List tickets with optional filters
  6) move        — Move ticket(s) to a new status (workflow transition)
  7) take        — Assign yourself to a ticket and move it to In Progress
  8) comment     — Add a comment to a ticket
  9) search      — Search ticket content
  10) update     — Update atoshell
  11) uninstall  — Remove atoshell
  12) install    — Install atoshell on this machine
  13) version    — Print the atoshell version
```

Menu items start at 0 (init) rather than 1 for consistency with common CLI patterns.

---

## Commands

### `init`
Aliases: `kido`, `boot`

Set up `.atoshell/` in the current directory. If `.atoshell/` already exists, delegates to `update` instead.

```bash
atoshell init
```

---

### `add [title]`
Aliases: `tasu`, `fab`, `new`, `open`

Create a new ticket. If no title is given, opens an interactive prompt.

```bash
atoshell add "Fix login bug"
atoshell add "Fix login bug" --priority P1 --size S --description "Details here"
atoshell add "Auth spike" --disciplines Backend --assign lyra,me
atoshell add "Agent import" --body "Created by orchestrator" --as agent-1
atoshell add --multi                 # keep adding tickets until title is left blank
atoshell add --stream --simple       # rapid-fire: just enter titles, all defaults applied
atoshell add --import tickets.json   # import a batch from a JSON array file
atoshell add --import -              # same, reading from stdin
```

| Flag / Aliases                              | Description                                          | Default    |
|---------------------------------------------|------------------------------------------------------|------------|
| `--multi` / `--stream`                      | Keep adding tickets until title is left blank        |            |
| `--simple`                                  | Title-only mode — skip all prompts, apply defaults   |            |
| `--import <file>`                           | Import from a JSON array (`-` reads stdin)           |            |
| `--description` / `--desc`, `--body`, `-b`  | Ticket description                                   | _(empty)_  |
| `--type` / `--kind`, `-t`                   | Ticket type (`Bug`/`Feature`/`Task` or `0`–`2`)      | `Task`     |
| `--priority` / `-p`                         | Priority level (`P0`–`P3` or `0`–`3`)                | `P2`       |
| `--size` / `-s`                             | Size estimate (`XS`/`S`/`M`/`L`/`XL` or `0`–`4`)     | `M`        |
| `--status` / `-S`                           | Status to assign (multi-word, no quotes needed)      | `Ready`    |
| `--disciplines` / `--dis`, `-d`             | Fixed discipline tags (comma-separated)              |            |
| `--accountable` / `--assign`, `-a`          | Accountable users (`me` = you, `agent` = `[agent]`)  |            |
| `--dependencies` / `--depends`, `-D`        | Comma-separated dependency IDs                       |            |
| `--as <agent-N\|number>`                    | Set `created_by` to a numbered agent in non-TTY mode |            |
| `--json` / `-j`                             | Output created ticket as JSON (agent-friendly)       |            |

`--as` is only allowed in non-interactive mode and only accepts `agent-N` or a bare positive number. Omit `--as` to use the default non-TTY `[agent]` actor.

`--json` is non-interactive. It cannot be combined with `--multi` / `--stream`
or `--simple`. Single-ticket JSON creation requires both an explicit title and
description (`--description`, `--desc`, `--body`, or `-b`); use `--import` for
batch JSON creation where only `title` is required per item.

> `--discipline` and `--dependency` are also valid aliases. `fe` and `be` are accepted as shorthand for `Frontend` and `Backend`. When a ticket is deleted, any tickets that depend on it are flagged and you are prompted to remove the dangling reference.

Use the narrowest accurate discipline set when adding tickets. See [Disciplines](#disciplines) for the fixed labels and when to use each one.

**`--import` format** — a JSON array where only `title` is required:

```json
[
  {"id": 9, "title": "Set up CI", "priority": "P1", "disciplines": ["DevOps"]},
  {"id": 11, "title": "Write tests", "dependencies": [9]}
]
```

If an imported item includes an `id`, atoshell treats it as an import-local reference only. New local IDs are assigned on import, and any dependencies that point at other items in the same batch are rewritten to the new IDs automatically. Items without an `id` keep the existing behavior: dependencies may reference the batch's soon-to-be-assigned local IDs.

Omitted type, priority, size, and status fields use the project's configured defaults (`TYPE_2`, `PRIORITY_2`, `SIZE_2`, and `STATUS_READY`).

All items are validated before anything is written. Errors across the whole batch are reported together.

---

### `show <id|next|board>`
Aliases: `yomu`, `read`

Show a single ticket in full, the next best ready ticket, or the kanban board.

```bash
atoshell show 5
atoshell show 5 --details   # include created/edited timestamps
atoshell show 5 --json      # output as JSON (agent-friendly)
atoshell show next          # best unblocked ready ticket with no assignee or assigned to you
atoshell show next --json
atoshell show board         # ASCII kanban (3 active columns)
atoshell show board --full  # add a 4th Done column (--all is an alias)
atoshell show board --all   # same as --full
atoshell show board --done  # same as --full for board
```

**Ticket view** (`show <id>` / `show next`):

| Flag         | Aliases  | Description                                             |
|--------------|----------|---------------------------------------------------------|
| `--details`  |          | Show created/edited timestamps for ticket and comments  |
| `--json`     | `-j`     | Output ticket as JSON                                   |

**Board view** (`show board`):

**Dependency Context** (`show <id>`):

Both human-readable and JSON output include dependency context:
- **blocked**: `true` when any dependency is still open
- **blocked_by**: unresolved dependency objects with `id`, `title`, and `status`
- **blocking**: open dependent ticket objects with `id`, `title`, and `status`

Example:
```bash
$ atoshell show 5
#5: Fix login bug [Bug • P1 • M • Ready]
Created by: Lyra (2 hours ago)
Dependencies: #3
............................................................
Blocked by:   #3 Add auth service [In Progress]
Blocking:     #7
```


| Flag      | Aliases        | Description                              |
|-----------|----------------|------------------------------------------|
| `--full`  | `--all`, `-f`  | Add Done column and show all per column  |
| `--done`  |                | Include Done column                      |

---

### `edit <id> [flags]`
Aliases: `henshu`, `mod`

Edit any property of a ticket. Multiple flags can be combined in a single command.

```bash
atoshell edit 7 --title "Revised title"
atoshell edit 7 --description change      # opens interactive multi-line prompt
atoshell edit 7 --type Bug --priority P1
atoshell edit 7 --status "in progress"
atoshell edit 7 --status done
atoshell edit 7 --disciplines add Backend --disciplines remove Frontend
atoshell edit 7 --accountable add me,lyra --dependencies add 3,5
atoshell edit 7 --priority P1 --as agent-1
```

Flags can be combined freely in a single command.

| Flag / Aliases                              | Values                       | Description                                           |
|---------------------------------------------|------------------------------|-------------------------------------------------------|
| `--title` / `-T`                            | `<text>` or `change`         | Update title; `change` prompts interactively          |
| `--description` / `--desc`, `--body`, `-b`  | `<text>` or `change`         | Update description; `change` opens multi-line prompt  |
| `--type` / `--kind`, `-t`                   | `<name>` or `0`–`2`          | Set ticket type (`0`=Bug, `1`=Feature, `2`=Task)      |
| `--priority` / `-p`                         | `<value>` or `0`–`3`         | Set priority (`P0`–`P3`)                              |
| `--size` / `-s`                             | `<value>` or `0`–`4`         | Set size (`XS`/`S`/`M`/`L`/`XL`)                      |
| `--status` / `--move`, `-S`                 | `<status>`                   | New status (multi-word, no quotes needed)             |
| `--disciplines` / `--dis`, `-d`             | `add\|remove\|clear <vals>`  | Manage fixed discipline tags (comma-separated)        |
| `--accountable` / `--assign`, `-a`          | `add\|remove\|clear <vals>`  | Manage accountable; `me` = your name                  |
| `--dependencies` / `--depends`, `-D`        | `add\|remove\|clear <vals>`  | Manage dependencies (comma-separated IDs)             |
| `--as <agent-N\|number>`                    | `agent-N` or `N`             | Set `updated_by` to a numbered agent in non-TTY mode  |

Removing a discipline, accountable, or dependency that isn't on the ticket prints a warning but does not fail.
`--as` is only allowed in non-interactive mode and only accepts `agent-N` or a bare positive number.
`fe` and `be` are accepted as shorthand for `Frontend` and `Backend` in discipline values.
See [Disciplines](#disciplines) for the fixed labels and when to use each one.

---

### `delete <id[,id,...]> [--yes]`
Aliases: `kesu`, `wipe`

Delete one or more tickets permanently. Prompts for confirmation per ticket unless `--yes` is passed.

When deleting multiple IDs, missing tickets are reported and skipped — the remaining IDs are still processed. If other tickets list a deleted ticket as a dependency, you will be prompted to remove the dangling reference. `--yes` removes them automatically.

```bash
atoshell delete 5
atoshell delete 3,7,12
atoshell delete 3,7,12 --yes  # skip all confirmation prompts; auto-removes dangling dependencies
```

| Flag     | Alias  | Description                                                   |
|----------|--------|---------------------------------------------------------------|
| `--yes`  | `-y`   | Skip confirmation prompts; auto-remove dangling dependencies  |

---

### `list [scope] [filters]`
Aliases: `rekki`, `draw`

List tickets. Defaults to the active queue if no scope is given. Ready tickets are always returned in ranked priority order.

```bash
atoshell list                                    # active queue (Ready + In Progress)
atoshell list ready                              # shows all tickets in ready column (status)
atoshell list done                               # shows completed tickets
atoshell list --mine                             # tickets accountable to you
atoshell list --accountable lyra
atoshell list --priority P0,P1
atoshell list --priority 0,1                    # numeric shorthand: P0,P1
atoshell list --type Bug --disciplines Backend
atoshell list backlog --size XS,S --priority P2
atoshell list --status done                      # filter by status — no scope needed, no quotes needed
```

**Scopes:**
- File-based: `queue` / `q` (default), `backlog` / `bl`, `done`
- Status-based: `ready` / `rd`, `in-progress` / `ip`, `done` / `d`, `blockers` / `deps`

**Filters:**
| Flag                                        | Example                            |
|---------------------------------------------|------------------------------------|
| `--mine` / `--me` / `-M`                    | `list --mine`                      |
| `--accountable <user>` / `--assign` / `-a`  | `list --accountable lyra`          |
| `--agent` / `-A`                            | `list --agent`                     |
| `--priority <values>` / `-p`                | `list --priority P0,P1` or `0,1`   |
| `--size <values>` / `-s`                    | `list --size S,M` or `1,2`         |
| `--type <values>` / `-t`                    | `list --type Bug,Feature` or `0,1` |
| `--disciplines <values>` / `-d`             | `list --disciplines Backend`       |
| `--status <value>` / `-S`                   | `list --status in progress`        |

Filters can be combined freely: `atoshell list --mine --disciplines Backend --priority P0`

Discipline filters use the fixed labels from [Disciplines](#disciplines) and accept comma-separated names case-insensitively.

**Output flags:**
| Flag      | Aliases  | Description                            |
|-----------|----------|----------------------------------------|
| `--json`  | `-j`     | Output as JSON array (agent-friendly)  |

---

### `move <id[,id,...]> <status|column>`
Aliases: `ido`, `shift`

Move one or more tickets to a new status. Status can be a name (multi-word without quotes) or a column number.

| Column  | Status       |
|---------|--------------|
| `1`     | Backlog      |
| `2`     | Ready        |
| `3`     | In Progress  |
| `4`     | Done         |

```bash
atoshell move 8 ready
atoshell move 3,7 in progress      # multi-word, no quotes needed
atoshell move 8 3                  # column number — In Progress
atoshell move 5 4                  # Done
atoshell move 3,7,12 done --quiet
```

| Flag       | Alias  | Description      |
|------------|--------|------------------|
| `--quiet`  | `-q`   | Suppress output  |

Column numbers are shown in the board headers: `atoshell show board`

---

### `take [id|next]`
Aliases: `toru`, `snatch`, `grab`

Assign yourself to a ticket and move it to In Progress. With no argument, `take` defaults to `next` and takes the highest-priority ready ticket automatically.

```bash
atoshell take 7
atoshell take
atoshell take next
atoshell take next --json
atoshell take next --disciplines Backend --priority P0,P1
atoshell take 5 --force           # override done guard
atoshell take next --as agent-1   # orchestrator: claim on behalf of a numbered sub-agent
atoshell take next --as 1         # shorthand for agent-1
```

| Flag / Aliases                           | Description                                                                      |
|------------------------------------------|----------------------------------------------------------------------------------|
| `--as <agent-N\|number>`                 | Assign to a numbered agent (e.g. `agent-1` or `1`) instead of the default actor  |
| `--type <values>` / `--kind` / `-t`      | Filter `next` by ticket type (`Bug`, `Feature`, `Task` or `0`-`2`)               |
| `--priority <values>` / `-p`             | Filter `next` by priority (`P0`-`P3` or `0`-`3`, comma-separated)                |
| `--size <values>` / `-s`                 | Filter `next` by size (`XS`-`XL` or `0`-`4`, comma-separated)                    |
| `--disciplines <values>` | `--dis`, `-d` | Filter `next` by fixed discipline tags                                           |
| `--json` / `-j`                          | Output ticket as JSON after taking                                               |
| `--force` / `-F`                         | Override done guard — assign even if Done (`id` only)                            |

**Notes:**
- Filters only apply to `take next`; use fixed discipline labels from [Disciplines](#disciplines).
- In a non-TTY context (agent/CI), assigns to `[agent]` instead of the current user. Use `--as <agent-N|number>` to assign to a specific numbered agent instead.
- `--as` is only allowed in non-interactive mode and only accepts `agent-N` or a bare positive number. Omit `--as` to use `[agent]`.
- Warns if the ticket is already In Progress — use `--force` to suppress.
- Errors and does nothing if the ticket is Done — use `--force` to override, or use `atoshell move` / `atoshell edit` to reopen it first. `--force` cannot be combined with `next`.
- Exits 1 if the ticket is currently assigned to other users — use `--force` to override.

---

### `comment <id>`
Aliases: `kaku`, `mark`, `note`

Add, edit, or remove comments on a ticket. Author is set to `$USERNAME` when run interactively, or `[agent]` when stdin is not a TTY (piped input). Use `--as <agent-N|number>` in non-interactive mode when an orchestrator needs the comment attributed to a specific numbered agent.

```bash
atoshell comment 5                        # interactive prompt
atoshell comment 5 "Looks good"           # inline text
atoshell comment 5 --as agent-1 "Root cause found"
atoshell comment 5 edit 2 "Updated text"  # edit comment #2
atoshell comment 5 edit 2                 # edit comment #2 interactively
atoshell comment 5 delete 2               # delete comment #2
```

`--as` is only allowed in non-interactive mode and only accepts `agent-N` or a bare positive number. Omit `--as` to use `[agent]`.

---

### `search <query>`
Aliases: `hiku`, `crawl`, `find`

Search across ticket text and common metadata: title, description, comments, disciplines, accountable, type, priority, size, and status.

```bash
atoshell search "login"
atoshell search "P0"
atoshell search "login" --json  # output as JSON array (agent-friendly)
```

| Flag      | Alias  | Description                            |
|-----------|--------|----------------------------------------|
| `--json`  | `-j`   | Output matching tickets as JSON array  |

---

### `update`
Aliases: `noru`, `migrate`, `patch`

Pull the latest atoshell CLI and sync project files and config. Git-based installs update with `git pull --ff-only`; non-git installs print the manual reinstall command instead of executing a remote installer. Creates any missing `.atoshell/` files and adds new config vars introduced since the last update.

```bash
atoshell update
atoshell update --walk  # search parent directories for a project to update
```

| Flag             | Description                                                                          |
|------------------|--------------------------------------------------------------------------------------|
| `--walk`         | Search parent directories for a project to update (default: current directory only)  |
| `--help` / `-h`  | Show update usage help and exit                                                      |

---

### `version`

Print the atoshell CLI version from the checked-in `VERSION` file.

```bash
atoshell version
atoshell --version
atoshell -v
```

---

### `uninstall`
Aliases: `nuku`, `flush`, `purge`

Remove atoshell. Your `.atoshell/` project data is never touched.

```bash
atoshell uninstall
```

---

## Configuration
Each project's `.atoshell/config.env` controls how atoshell behaves for that project.

### Username
Set your name so all tickets and comments are attributed correctly, and so `me` resolves to you when filtering or setting accountable. If `USERNAME` is not set in `config.env`, Atoshell uses `undefined`.

```bash
USERNAME="Ian"
```

### Status names
Rename to match your workflow.

```bash
STATUS_BACKLOG="Backlog"
STATUS_READY="Ready"
STATUS_IN_PROGRESS="In Progress"
STATUS_DONE="Done"
```

### Disciplines
Discipline tags are fixed Atoshell options, not project config. They are used for tagging and filtering work consistently across projects. CLI flags accept comma-separated names case-insensitively; `fe` and `be` are shorthand for `Frontend` and `Backend`.

| Discipline      | Use for                                                                                 |
|-----------------|-----------------------------------------------------------------------------------------|
| `Frontend`      | UI components, client-side logic, styling, browser APIs, user-facing interactions       |
| `Backend`       | Server-side logic, REST/GraphQL APIs, services, business rules, data processing         |
| `Database`      | Schema design, migrations, queries, indexing, data modelling                            |
| `Cloud`         | Cloud infrastructure, managed services (AWS/GCP/Azure), hosting, networking, scaling    |
| `DevOps`        | CI/CD pipelines, deployment, containerisation, monitoring, operational tooling          |
| `Architecture`  | System design, technical decisions, service boundaries, cross-cutting concerns, ADRs    |
| `Automation`    | Scripting, workflow automation, task runners, build tooling (non-test)                  |
| `QA`            | Test writing (unit/integration/e2e), testing strategy, quality gates, bug verification  |
| `Research`      | Spike work, feasibility studies, technology evaluation, documenting unknowns            |
| `Core`          | Shared libraries, foundational utilities, cross-service primitives, platform internals  |

A ticket may carry multiple disciplines. Use the narrowest set that accurately reflects the work.

### Ticket types
Three configurable types — rename to match your workflow.

```bash
TYPE_0="Bug"
TYPE_1="Feature"
TYPE_2="Task"
```

### Priority labels
Rename the four priority levels. Order is highest → lowest.

```bash
PRIORITY_0="P0"  # highest
PRIORITY_1="P1"
PRIORITY_2="P2"  # default for new tickets
PRIORITY_3="P3"  # lowest
```

Example — severity labels:
```bash
PRIORITY_0="Critical"
PRIORITY_1="High"
PRIORITY_2="Medium"
PRIORITY_3="Low"
```

### Size labels
Rename the five size levels. Order is smallest → largest.

```bash
SIZE_0="XS"
SIZE_1="S"
SIZE_2="M"   # default for new tickets
SIZE_3="L"
SIZE_4="XL"
```

Example — use story points:
```bash
SIZE_0="1"
SIZE_1="2"
SIZE_2="3"
SIZE_3="5"
SIZE_4="8"
```

### Dependency budgets
Ready-ticket ranking can temporarily promote blockers for high-priority work. These budgets control how much dependency size can be "pulled forward."

```bash
UNBLOCK_P0_BUDGET=""   # empty = infinite
UNBLOCK_P1_BUDGET="3"
```

---

## Development & Contributing

See [STYLE.md](STYLE.md) for coding standards and contribution guidelines.

**Quick start:**
- Follow existing code patterns
- Run the smallest relevant `tests/unit/<file>.bats` first; on Windows use `bats.cmd --print-output-on-failure tests/unit/<file>.bats`
- Run the full suite only as a final confidence pass
- Submit PRs to the dev branch


## Data storage
Each project gets a `.atoshell/` directory:

```
.atoshell/
  config.env    # project configuration (gitignored)
  queue.json    # active tickets: Ready → In Progress (committed)
  backlog.json  # parked / untriaged tickets (committed)
  done.json     # completed tickets (committed)
  meta.json     # local metadata such as next_id (gitignored)
```

`queue.json`, `backlog.json`, and `done.json` are shared project state. `config.env` and `meta.json` are local-only.

Ticket schema:

```json
{
  "id": 1,
  "uuid": "2136d109-2e74-42d6-9519-91128337188b",
  "title": "Fix login bug",
  "description": "Full details here",
  "status": "Ready",
  "priority": "P1",
  "size": "S",
  "type": "Bug",
  "disciplines": ["Backend"],
  "accountable": ["lyra"],
  "dependencies": [2],
  "comments": [
    { 
      "author": "lyra", 
      "text": "Reproduced on staging", 
      "created_at": "2026-01-01T01:00:00Z" 
    }
  ],
  "created_by": "lyra",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_by": "lyra",
  "updated_at": "2026-01-01T01:00:00Z"
}
```

`created_at` and `updated_at` are written in the timezone configured by
`ATOSHELL_TIMEZONE` in `.atoshell/config.env`. The default is `UTC`, which keeps
the historical `...Z` format. Use IANA timezone names such as
`ATOSHELL_TIMEZONE="America/Mexico_City"` to write local timestamps with an
ISO-8601 offset such as `2026-04-23T23:00:00-06:00`.

`show <id> --json` also computes:

- `blocked`: `true` when any dependency is still open
- `blocked_by`: unresolved dependency objects `{id,title,status}`
- `blocking`: open dependent ticket objects `{id,title,status}`

These fields are computed at read time and are not stored on disk.

## License

atoshell is licensed under the GNU General Public License, version 3. See [LICENSE](LICENSE).
