# atoshell Development Style Guide

This guide is for contributors working on atoshell itself. `README.md` is the user contract; `AGENTS.md` is the agent-facing contract.

## Architecture

- `atoshell.sh` is the top-level dispatcher and interactive menu.
- `bin/atoshell` and `bin/ato` are shipped wrappers for that dispatcher and should stay behaviorally aligned with it.
- Each user-facing command lives in its own `*.sh` script.
- Shared runtime/config/file helpers live in `funcs/helpers.sh`.
- Ranking and dependency logic live in `funcs/algorithms.sh`.
- Bulk ticket import planning and validation helpers live in `funcs/add_import.sh`.
- Human-readable rendering lives in `funcs/prints.sh`.
- Project state is split into shared ticket files (`queue.json`, `backlog.json`, `done.json`) and local-only files (`config.env`, `meta.json`).

## Source Of Truth

- The shipped CLI surface includes `atoshell.sh`, `bin/atoshell`, `bin/ato`, and `VERSION`.
- Package distribution metadata lives in `package.json`; keep its `bin` entries and version aligned with the shipped wrappers and `VERSION`.
- Keep command names, aliases, help text, and version output aligned across:
  - `atoshell.sh`
  - `bin/atoshell`
  - `bin/ato`
  - command file headers
  - `package.json`
  - `README.md`
  - `AGENTS.md`
  - `tests/README.md`
- Do not document removed features as if they still exist.

## Shell Conventions

### Script shape

Every command script should:

1. Start with `set -euo pipefail`.
2. Source `funcs/helpers.sh`.
3. Source other shared modules only when needed.
4. Call `_setup` before writing project state, or `_setup_readonly` for read-only commands. Read-only setup must stay lock-free on the normal path, but must recover any visible lock or transaction journal before reading.
5. Pass large ticket or queue payloads to `jq` through files such as `--slurpfile`; never place complete ticket objects or unbounded comment history in process arguments.
6. Use banner comments for major sections.
7. Keep the file header in this order: title line, `Usage:`, optional `Aliases:`, then examples/options blocks when needed.
8. Keep command files in narrative order: setup, initial parsed-state variables, flag parsing, validation/pre-flight checks, helper functions local to the command, the main read/write operation, then JSON/human output.
9. Keep dispatchers in narrative order: setup, helper functions, global-flag stripping, command normalization, help/version/menu branches, then final `exec` dispatch.

### Layout and alignment

- Treat aligned text as part of the house style, not incidental formatting.
- Treat any visually aligned block as adjacent vertical lists, not one padded left blob.
- Use the `# ── Section ─────` banner form for shell section dividers in tracked scripts and tests. Do not mix it with older `# -- Section ---` dividers inside the same project.
- In shell `case` arms, help listings, `printf` command menus, comment headers, flag groups, and other columnar blocks, start the next column exactly 2 spaces after the longest item in the previous column.
- In `|`-separated command or alias blocks, each alias position is its own vertical column. The `— description` column is just the final column in that sequence.
- In one contiguous block, shorter rows must preserve the width of later empty columns so the final description column still aligns with rows that have more aliases.
- After the last real item on a row, do not render placeholder `|` separators for those empty trailing columns; pad with spaces only until the description column.
- Preserve that same 2-space rule when adding aliases, flags, descriptions, or assignment columns later.
- In `case` arms that assign `CMD=...`, align the assignment column 2 spaces after the longest matcher pattern in that contiguous block.
- In flag-parsing `case "$1"` blocks, a tiny `--help|-h` arm may stay one line, but other flag arms should prefer multi-line bodies for readability when they set state or shift arguments.
- Apply the same scan-friendly alignment to Markdown tables in `README.md`, `AGENTS.md`, and `tests/README.md`.
- Human-facing command lists use aligned columns plus an em dash before the description.
- Runtime framing should prefer ASCII boxes that match actual CLI output.
- In generated or example `config.env` files, align inline comments 2 spaces after the longest assignment in that contiguous block. Keep section banners and explanatory comments in the same order as the generated template.
- Agent-facing docs should prefer canonical commands and task flows. Keep full alias inventories in user-facing docs unless an alias is directly required for an automation contract.

### Applying the alignment rules

Alignment drifts when it is edited row-by-row and checked by eye. Apply the rules above as a measured, whole-block, whole-surface operation:

1. **Inventory every columnar surface before editing any of them.** For the command family that means the interactive menu `printf` block, the help `printf` block, the dispatcher header comment block, the `case` dispatch arms, and the matching tables and examples in `README.md`, `AGENTS.md`, and `tests/README.md`. They are one shared surface; a row changed in one place must be re-checked in all of them.
2. **Unify wording before aligning.** A command's description must be word-for-word identical across the menu, help output, header comment, and README. Pick the most accurate wording once, propagate it everywhere, then align. Aligning strings that are about to change is wasted work.
3. **Parse each contiguous block as a grid, not as padded strings.** Split every row into its cells — in the menu, `N) name` is one cell; in help and header listings, the canonical name and each alias position are separate cells; the `— description` is always the final cell. Blocks are scoped: a new block (menu vs help vs header) gets its own measured widths.
4. **Compute column widths — never eyeball them.** A column starts exactly 2 spaces after the widest cell in the previous column across *all* rows of the block. Include the awkward rows when measuring: double-digit menu numbers, alias cells that are flags (`--version`), and rows with no aliases at all. When any cell changes width, recompute and rewrite the entire block — one longer item reflows every row.
5. **Verify by counting characters, not by looking.** Confirm with byte-exact checks: `grep -F` for the exact expected row, or a diff of the full block against the intended layout. Terminal rendering can look aligned while being off by one, especially around `—` and `|`.
6. **Compare the shipped CLI to the docs byte-for-byte.** Run `bash atoshell.sh help` and the menu, and diff the output against the `README.md` examples. Doc examples are exact transcripts of runtime output, not approximations.
7. **Pin the drift-prone rows in tests.** Keep Bats assertions on the rows that historically fall off the grid: the widest row, the no-alias row (`install`), the flag-alias row (`version | --version | -v`), the first double-digit menu row, and the menu title banner. Extend these pins when adding commands or aliases.

In Markdown tables, additionally escape any literal `|` inside a cell as `\|` so the cell does not split when rendered, and pad every cell so the pipes form straight vertical lines in the source.

### Module headers

- Shared `funcs/*.sh` files should start with a one-line purpose comment after the shebang.
- Data-only sourced modules under `funcs/`, such as default-value files, follow the same shebang and purpose-comment rule.
- Filename-prefixed synopsis headers are acceptable for larger aggregator, rendering, or algorithm modules when the extra prose explains how the module is meant to be sourced.
- If a file is guarded against re-sourcing, keep the purpose comment above the guard so the file still reads clearly at the top.
- Aggregator modules should use a banner comment before sourced module blocks.
- Separate adjacent helper functions with a blank line, and use banner comments to group related helpers in shared modules.
- A banner may directly introduce code with no blank line; use one blank after the banner only when section-level explanatory comments follow.
- Keep reusable helper modules organized from bootstrap/configuration toward increasingly specific behavior, and put command-local helper functions below parsing/pre-flight unless they are needed to parse arguments safely.

Example — simple two-column list:

```text
printf '  0) init       — Initialise .atoshell/ in current directory\n'
printf '  1) add        — Create a new ticket\n'
printf ' 11) uninstall  — Remove atoshell\n'
```

Example — multi-column alias list:

```text
#   install                                        — Install atoshell on this machine
#   uninstall  | nuku   | purge                    — Remove atoshell
#   take       | toru    | snatch  | grab          — Assign yourself to a ticket and move it to In Progress
#   add        | tasu    | fab     | new   | open  — Create a new ticket
```

Example — aligned `case` block:

```bash
case "$choice" in
  0|init|kido|boot)         CMD="init"       ;;
  1|add|tasu|fab|new|open)  CMD="add"        ;;
  11|uninstall|nuku|purge)  CMD="uninstall"  ;;
esac
```

Example — readable flag parser:

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) _show_help "${BASH_SOURCE[0]}"; exit 0 ;;
    --force|-F)
      force=true
      shift ;;
    --json|-j)
      json=true
      shift ;;
  esac
done
```

### Naming

- Internal helpers use a leading underscore: `_resolve_status`.
- User-facing helpers may omit the underscore when they are intentionally top-level, such as `show_menu`.
- Constants stay `UPPER_CASE`.
- Regular variables use `snake_case`.
- Function-local variables should be `local` unless they are intentionally shared with caller scope.
- Runtime control flags parsed from CLI options should stay in local `snake_case` variables where possible.
- If script-level plumbing must be exported between modules, set it explicitly from parsed CLI state in the same command path, and name it so it cannot be mistaken for a supported config key or ambient global knob.
- Do not let pre-existing environment variables change command behavior unless they are documented public config or standard OS runtime inputs.

### Output and errors

- Prefer `_out`, `_outln`, and `_outf` for non-error human output so quiet mode works everywhere.
- Use `_out` / `_outln` for user-controlled or already-rendered text. Use `_outf` only with a static printf format string.
- Keep machine-readable output behind `--json`.
- Use `_json_error` for structured error contracts.
- Exit from main scripts on failure; do not rely on fallthrough after a fatal error.
- Keep help text, banner output, and README examples visually consistent with the shipped CLI.

### Quoting and safety

- Quote shell expansions unless word-splitting is intentional.
- With `set -u` and Bash 4.3 support, iterate arrays that may be empty as `"${array[@]+"${array[@]}"}"` instead of plain `"${array[@]}"`; the longer form avoids unbound empty-array errors on the minimum supported Bash.
- Validate ticket IDs, dependency IDs, and user-provided enums before writing.
- Sanitize user-entered text that will be rendered back to terminals.
- Keep file operations scoped to `.atoshell/`.
- When `jq -r` output is fed back into shell variables, loops, prompts, or equality checks, prefer `_jq_text` so text handling stays stable across Bash environments. Keep raw `jq -r` in modules that are intentionally sourceable without `funcs/helpers.sh` or `funcs/terminal.sh`.

## Portability And Environment

- atoshell requires Bash 4.3 or newer and must stay portable across normal modern Bash environments, including Linux, macOS with Homebrew Bash, and Git Bash. Do not assume Linux CI alone proves portability.
- Do not hardcode absolute machine paths, usernames, WSL bridge paths, or repo-external temp locations into runtime code or permanent tests.
- Keep path resolution anchored on repo helpers such as `ATOSHELL_DIR`, `_resolve_project`, and sibling-path helpers instead of `$PWD` assumptions.
- `curl` is part of the bootstrap/update story and may stay there. Do not add it as a hidden requirement for ordinary ticket commands.
- Avoid introducing extra helper dependencies such as `uuidgen`, `setsid`, or `script` when a Bash-native approach is available.

## Config And Data Rules

- Configurable labels (`STATUS_*`, `PRIORITY_*`, `SIZE_*`, `TYPE_*`) must be treated as runtime data, not hardcoded strings.
- Discipline labels are fixed Atoshell options, not project config.
- `meta.json` is the only source of truth for `next_id`.
- `done.json` is shared workflow state, not local-only metadata.
- The ticket and comment JSON shape defined by atoshell is the canonical schema that other tools must adapt to, not rewrite.

## Isolation Rules

- atoshell is a standalone ticket manager. Do not add runtime, planning, or orchestration dependencies on sibling orchestration tools.
- Cross-tool integration guidance belongs in those tools' adapter skill docs, not in atoshell core code or product docs.
- Keep file operations scoped to `.atoshell/` and same-machine project state.

## Tests

- Use `tests/helpers/setup.bash` unless a file needs custom bootstrap behavior.
- Tests should assert both exit status and user-visible behavior.
- Add regression tests for any new public flag, config contract, or migration path.
- Prefer fixtures for stable baseline state, then override inline only for scenario-specific data.
- Keep prompt and adapter fixtures where their scope lives. Runtime prompt assets used by Atoshell belong in `prompts/` if such a runtime prompt library exists; prompts created only for tests belong under `tests/`.
- If a test prompt is shared by every adapter-style test in a suite, keep one shared fixture at that suite level. If it is specific to one adapter or command surface, keep it in that adapter or command test folder.
- Adapter-specific executable test doubles belong in the specific adapter test folder they support. Extensionless files are acceptable when the fixture intentionally mimics an installed command name.
- When testing missing-dependency branches, isolate only the dependency under test. Do not accidentally remove `bash` or other required baseline tools while constructing the test environment.
- Prefer helper/env overrides and stub commands over platform-specific test helpers.
- On Windows, prefer `bats.cmd` from the repo root so Git Bash / MSYS is the shell actually running the suite.
- If Git Bash / MSYS fails before a test starts, treat that as a harness issue first and verify the changed CLI path directly with explicit Git Bash commands before debugging product code.

## Docs And Comments

- Update `README.md` when changing user-visible behavior.
- Update `AGENTS.md` when changing JSON contracts, orchestration workflows, or agent-specific flags.
- Update `CHANGELOG.md` when behavior, install/update expectations, or portability guarantees change.
- Keep `tests/README.md` aligned with the actual suite structure.
- Keep runtime examples in docs visually consistent with the real CLI output.
- Comments should explain intent, invariants, or tricky data flow. Avoid diary-style or personal comments.

## Performance

- Optimize for clarity first, then measure.
- Ranking and filtering code should stay linear or close to linear in ticket count.
- When adding jq-heavy logic, prefer a single pass with explicit sort/rank helpers over repeated shell subprocess chains.
