# Audit Workflow

4-phase sequential pipeline. Read-only — no file writes outside `.scratch/<session>/`.

## Phase 1 — Scope

Main thread. Determine audit scope from user input.

- **Focused** (single module or directory) — skip Phase 2; proceed to Phase 3 with user's module as sole candidate.
- **Broad** (multiple modules or full codebase) — proceed to Phase 2.

Generate session ID if none inherited. Output: scope classification + candidate list (focused) or area list (broad).

## Phase 2 — Explore (broad scope only)

Dispatch @scout + `audit-scout.md` per module area (max 2-3 areas). Each scout prompt:

> Map module boundaries, export surfaces, cross-module coupling, pass-through functions,
> and internal-mocking test patterns for `<area>`.
> Output: `.scratch/<session>/audit-explore-<area-slug>.md`

Synthesize scout outputs into numbered deepening candidates. Present to user. User selects 1-3 candidates for Phase 3.

## Phase 3 — Analyze

Dispatch @researcher + `references/analyze-researcher.md` per selected candidate (max 3 concurrent).

Verify researcher output covers:
1. Depth assessment — ratio estimate with shallow/medium/deep classification
2. Dependency classification — every dependency categorized (4-category model)
3. Test strategy — boundary tests vs internal mocking, which dominates
4. Caller map — fan-in count, coupling hotspots

Output: `.scratch/<session>/audit-analyze-<candidate-slug>.md`

## Phase 4 — Synthesize

Dispatch `@synthesizer` → `references/audit-synthesis.md`.

Input: all `audit-analyze-*.md` paths from Phase 3. Output: `.scratch/<session>/architecture-findings.md`.

Read synthesis output. Present findings to user per SKILL.md Output Format.

## Anti-Patterns

- Running Phase 2 for focused scope (wastes scout dispatch on known target)
- Dispatching more than 3 researchers in Phase 3 (diminishing returns; cap at 3)
- Proposing solutions in Phase 4 (audit diagnoses; do-consult with architecture-depth lens prescribes)
- Skipping user selection between Phase 2 and Phase 3 (user chooses deepening targets)
