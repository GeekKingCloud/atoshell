# Contributing To Atoshell

Thanks for helping improve Atoshell. This project is a small, shell-based CLI, so changes should stay focused, portable, and easy to verify.

## Development Setup

Requirements:

- Bash 4.3 or newer
- jq
- git
- Bats for the test suite

From the repo root:

```bash
bash atoshell.sh help
bash bin/atoshell help
```

On Windows, use Git Bash for shell commands and `bats.cmd` for tests. On macOS,
install modern Bash with Homebrew and ensure it appears before `/bin` in `PATH`.

## Before You Change Code

Read:

- `README.md` for the user-facing contract
- `STYLE.md` for coding and formatting conventions
- `AGENTS.md` for automation, JSON, and orchestration behavior
- `tests/README.md` for test structure

Treat these files as part of the same public surface when changing CLI behavior:

- `atoshell.sh`
- `bin/atoshell`
- `bin/ato`
- `VERSION`
- `README.md`
- `AGENTS.md`
- `STYLE.md`
- `tests/README.md`

## Coding Standards

Follow the existing shell style:

- Use `set -euo pipefail`
- Quote shell expansions unless word splitting is intentional
- Keep human output ASCII-framed and column-aligned
- Keep machine-readable output behind `--json` / `-j`
- Write structured JSON errors to stderr and keep stdout clean on failure
- Do not add runtime dependencies on external planning or orchestration tools
- Keep file operations scoped to `.atoshell/`

## Tests

Run the smallest relevant test first:

```bash
bats tests/unit/<file>.bats
```

On Windows:

```powershell
bats.cmd --print-output-on-failure tests/unit/<file>.bats
```

Use the full suite as a final confidence pass:

```powershell
bats.cmd --print-output-on-failure tests/unit
```

If Windows Git Bash or MSYS fails before a test starts, verify the smallest raw Git Bash command before treating it as an Atoshell failure.

## Documentation

Update docs in the same change when behavior changes.

- User-facing CLI behavior belongs in `README.md`
- Agent/automation behavior belongs in `AGENTS.md`
- Contributor conventions belong in `STYLE.md`
- Test layout and verification notes belong in `tests/README.md`
- Release-visible behavior belongs in `CHANGELOG.md`

## Pull Requests

Submit pull requests against the `dev` branch.

A good PR should include:

- A clear description of the behavior changed
- Focused tests for the change
- Updated docs when the public surface changed
- Notes for any Windows-specific behavior or verification limits
