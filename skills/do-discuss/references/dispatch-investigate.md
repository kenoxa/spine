# Investigate Phase

Codebase evidence gathering. Scales dispatch to blocking unknowns; fast-exits when no unknowns need codebase depth beyond orient or clarify assists.

| Agent | Reference | Use when | Output |
|-------|-----------|----------|--------|
| `@scout` | `run-explore/references/explore-scout.md` | Orientation: "does X exist? where?" | `.scratch/<session>/discuss-investigate-scout.md` |
| `@researcher` | `investigate-researcher.md` | Depth: "how does X work? side effects?" | `.scratch/<session>/discuss-investigate-researcher.md` |
| `@navigator` | `run-explore/references/explore-navigator.md` | External: "ecosystem says what about X?" | `.scratch/<session>/discuss-investigate-navigator.md` |

Dispatch context: specific unknowns, `known`/`unknown` state, why user couldn't answer. Navigator: external library behavior, API compatibility — not codebase depth. Targeted queries, not broad sweep. Duplication prevention: check orient + clarify-assist outputs first. File presence in File map narrows query; only explicit Answer resolution omits dispatch.

Before dispatch: select 1 lens from `do-plan/references/variance-lenses.md` — match unknowns against trigger column, log reasoning (2-3 sentences). One augmented `@researcher` with lens. Max 3 concurrent (1-2 base + 1 augmented). Max 2 rounds. Synthesize into `codebase_signals`; merge navigator into `external_signals` (append, not overwrite).

> Anti-patterns: (1) Dispatching for unknowns already answered by orient. (2) Navigator for codebase-depth questions (@researcher's job).
