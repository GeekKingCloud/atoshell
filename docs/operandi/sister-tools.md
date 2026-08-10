# AutoDev Sister Tools

These tools are standalone first. Do not add runtime dependencies on sibling checkouts, shared hidden state, or assumptions that the other tools are installed. When the repositories are present next to each other, use this context to understand the larger AutoDev pipeline.

| Tool | Role | Purpose |
| --- | --- | --- |
| `lumber-hack` | Ideate. Define. | Workshop an idea and get usable tickets out. |
| `atoshell` | Document. Organise. | A CLI ticket-manager. |
| `g8ldfish` | Delegate. Build. | An agent orchestrator that spins up workers to handle tasks. |

## Pipeline Shape

`lumber-hack` turns current-state and future-state thinking into grounded tickets. `atoshell` holds and manages those tickets in a durable CLI workflow. `g8ldfish` runs the execution loop over work that is ready to delegate.

## Boundary

Use sister-tool context for orientation, docs, tests, release notes, and adapter expectations. Keep each repository usable on its own, and avoid changing core behavior just because a sibling tool exists nearby.
