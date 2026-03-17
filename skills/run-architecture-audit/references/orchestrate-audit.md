# Audit Workflow

4-phase sequential pipeline. Read-only — no file writes outside `.scratch/<session>/`.

## Phase 1 — Scope

Main thread. Determine audit scope from user input.

- **Focused** (single module or directory) — skip Phase 2; proceed to Phase 3 with user's module as sole candidate.
- **Broad** (multiple modules or full codebase) — proceed to Phase 2.

Generate session ID if none inherited. Output: scope classification + candidate list (focused) or area list (broad).

## Phase 2 — Explore (broad scope only)

Dispatch @scout + [audit-scout.md](audit-scout.md) per module area (max 2-3 areas). Each scout prompt:

> Map module boundaries, export surfaces, cross-module coupling, pass-through functions,
> and internal-mocking test patterns for `<area>`.
> Output: `.scratch/<session>/audit-explore-<area-slug>.md`

Synthesize scout outputs into numbered deepening candidates. Present to user. User selects 1-3 candidates for Phase 3.

## Phase 3 — Analyze

Dispatch @researcher per selected candidate (max 3 concurrent). Per candidate:

1. Count exports vs implementation scope (depth heuristic from `do-plan/references/deep-modules.md`)
2. Classify dependencies using 4-category model (in-process, local-substitutable, remote-but-owned, true-external)
3. Identify current test strategy — boundary tests vs internal mocking
4. Map callers — who depends on this module's exports

Output: `.scratch/<session>/audit-analyze-<candidate-slug>.md`

## Phase 4 — Synthesize

Main thread. Per candidate: compile depth assessment, dependency classification, test impact, caller map.

Produce `architecture-findings.md` per SKILL.md Output Format.

Next-step footer:
- Large scope (3+ candidates, cross-cutting friction) → suggest `/do-discuss` for spec creation
- Focused scope (1-2 candidates, clear boundary) → suggest `/do-plan` with `architecture-depth` lens

## Anti-Patterns

- Running Phase 2 for focused scope (wastes scout dispatch on known target)
- Dispatching more than 3 researchers in Phase 3 (diminishing returns; cap at 3)
- Proposing solutions in Phase 4 (audit diagnoses; do-plan with architecture-depth lens prescribes)
- Skipping user selection between Phase 2 and Phase 3 (user chooses deepening targets)
