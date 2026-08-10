# Atoshell Agent Entry Point

This file is the compact startup index for agents working in $(System.Collections.Hashtable.Tool). Load the shared machine/global instructions first, then use this local map.

## Read Order

1. docs/operandi/README.md - documentation map.
2. docs/operandi/context.md - project contract, CLI boundaries, commands, and workflow rules.
3. docs/operandi/style.md - engineering and documentation style.
4. docs/operandi/releases.md - version commits, tags, GitHub releases, npm publishing, and package artifacts when doing release work.
5. docs/operandi/sister-tools.md - AutoDev pipeline context when sibling tools matter.

CONTRIBUTING.md remains the normal human contribution guide. It is not the agent operating contract.

## Local Boundary

Atoshell must remain usable as a standalone tool. Sister-tool context may guide integration and documentation, but do not add runtime coupling to lumber-hack, atoshell, or g8ldfish unless the task explicitly asks for it.
