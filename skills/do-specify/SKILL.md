---
name: do-specify
description: >
  Create a spec for multi-session feature delivery. Use when: "write a spec",
  "create a spec", "specify this feature", "scope this feature",
  "break this into phases", "multi-session", "more than one session",
  "too big for one session", "decompose this", feature spanning multiple sessions,
  need persistent scope documentation.
  Do NOT use when: single-session tasks, simple bug fixes, planning (do-plan).
argument-hint: "[feature description]"
---

Produces requirements, not implementation tasks. Not a planning tool — do-plan consumes spec phases, not the other way around.

See [references/spec-template.md](references/spec-template.md) for EARS patterns and spec skeleton.

## Interview Flow

Sequential. Do not skip or reorder steps.

### 1. Problem

What situation needs to change? Extract from user input or ask directly. One paragraph — no solutions, no implementation details. If user leads with a solution ("add a cache"), ask what problem the cache solves.

### 2. Users & Context

Who is affected? What is the current state? Identify:
- Primary users (human or system)
- Current workaround or absence thereof
- Relevant existing infrastructure

### 3. Constraints

Mandatory section — agents hallucinate scope without explicit boundaries. Elicit:
- What is explicitly out of scope
- Hard limits (performance, compatibility, security)
- Non-goals (things that look related but are not part of this work)

If user says "no constraints": push back. Every feature has boundaries. Ask: "What would you reject if someone added it to this work?"

### 4. Phases

Break the capability into 3-6 phases. Push back outside this range:
- < 3 phases: likely a single-session task — suggest do-plan directly
- \> 6 phases: decompose into separate specs or collapse related work

Each phase gets:
- **Title**: short, action-oriented
- **Scope**: concrete file/component names — not abstract nouns. "Add `parseConfig()` to `src/config.ts`" not "implement configuration parsing"
- **Acceptance Criteria**: 2-5 EARS statements per [references/spec-template.md](references/spec-template.md)
- **Out of scope**: what this phase explicitly does not touch

## DAG Elicitation

After phases are drafted:

1. **Infer dependencies conservatively** — more deps = safer. A phase that reads output from another phase depends on it. When uncertain, add the dependency.
2. **Populate `Depends on:`** per phase — list phase numbers (comma-separated), or `none` for root phases. `Depends on: none` must be explicit for roots.
3. **Present the dependency graph** to user for confirmation. Format:
   ```
   Phase 1 (root) → Phase 2 → Phase 4
                  → Phase 3 → Phase 4
   ```
4. **Cycle warning**: if the graph contains cycles, flag them as advisory. Cycles indicate phase boundaries need adjustment.

User must confirm the dependency graph before output. If rejected → revise phases/dependencies, re-present.

## Output

1. Create `docs/specs/{YY}{WW}-<slug>/spec.md` per the skeleton in [references/spec-template.md](references/spec-template.md)
2. Create `docs/specs/{YY}{WW}-<slug>/progress.md` with scaffold:
   ```markdown
   # Progress: <Feature Name>

   | Date | Phase | Action | Detail |
   |------|-------|--------|--------|
   | YYYY-MM-DD | -- | created | Initial spec created |
   ```
   Date format: `YYYY-MM-DD` (ISO 8601).
3. All phases initialize as `[ ] pending` in the Status table
4. Do NOT auto-trigger do-plan

**Slug**: derive from feature name. Lowercase, hyphens, no special chars. Prefix with `{YY}{WW}` — execute `date +%g%V` to get 2-digit ISO year + ISO week (do not fabricate). Use `%g` not `%y` — `%y` causes year-boundary bugs at week 52/53 crossover. Example: "Auth Retry System" → `2612-auth-retry-system`.

**Capability section**: what the system will do after all phases complete. Present tense, outcome-focused. 2-4 sentences — not a phase, the aggregate capability.

**Success Criteria section**: top-level EARS statements across the entire spec, not per-phase. Validate the complete feature. 3-5 statements.

**Open Questions section**: unresolved items from interview. Each entry: question, affected phase(s), whether it blocks phase start. Open questions don't block spec creation — they block phase execution.

## Revision Mode

When an `@`-referenced spec.md already exists:

1. Edit spec.md in-place — do not recreate
2. Re-run relevant interview steps for changed sections
3. Preserve status of unchanged phases

**Slug collision**: if `docs/specs/{YY}{WW}-<slug>/` exists but contains no `spec.md` — warn user about orphaned directory before proceeding.

## Anti-Patterns

- Auto-triggering do-plan after spec creation
- Prose acceptance criteria instead of EARS format
- Phase count outside 3-6 without explicit pushback
- Omitting Constraints & Non-Goals section
- Abstract scope descriptions without file/function names
- Skipping user confirmation of dependency graph
- Fabricating `{YY}{WW}` prefix instead of executing `date +%g%V`
