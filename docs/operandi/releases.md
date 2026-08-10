# Atoshell Release Guide

## Current Release Shape

- Repository: $(System.Collections.Hashtable.Repo)
- npm package: $(System.Collections.Hashtable.Package)
- Current release line: 2.3.0
- Commands: $(System.Collections.Hashtable.Commands)

Trusted publishing is already known-good for atoshell. Keep package.json name as atoshell.

## Version Commits

Release commits are named exactly as the version, for example 1.0.0 or 2.3.0. Do not add words such as aseline, elease, or feature summaries to the commit subject unless the user explicitly asks.

For a release, squash the non-version work since the previous release into one version commit. Preserve previous version commits as history unless the user explicitly asks to rewrite them too. dev, main, and the matching X.Y.Z tag should point at the same final release commit after the user authorizes pushing.

## GitHub Releases

Use the Atoshell-style release body:

1. A short opening sentence naming what the version delivers.
2. ## Highlights with concise bullets for the major user-facing changes.
3. ## Install with npm/Bun commands and archive links when applicable.
4. ## Verification with the exact local tests, packaging checks, and publish evidence inspected.

Attach or reference the packaged repository archives GitHub creates for the tag. When adding project-built bundles or zips later, name them with the version and keep the contents aligned with the npm package surface.

## npm Publishing

The npm package is published from .github/workflows/npm-publish.yml on release publication. Prefer npm trusted publishing over long-lived npm tokens. The trusted publisher must match the package name, GitHub owner/repo, workflow filename, and environment setting exactly.

Before releasing, run a package dry run when feasible and confirm package.json exposes the intended files:

$(System.Collections.Hashtable.Files)

Do not change the npm package name during release automation. If the package name differs from the repository or product name, document the exception here and keep the difference intentional.
