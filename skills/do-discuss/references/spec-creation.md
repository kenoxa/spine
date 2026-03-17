# Spec-Creation Mode

Terminal branch — emits spec.md + progress.md only, never brief.md. Do NOT auto-trigger do-plan.

## 1. Activation

Two triggers:

- **Intake routing**: scope exceeds single session (2-of-3: multiple phases, cross-cutting concerns [3+ unrelated modules], multi-day signals) AND no `@`-reference present.
- **Mid-clarify escalation**: user's answer reveals scope-growth signals meeting the same 2-of-3 threshold. Between-round check.

Guard: present scope-signal evidence to user, get confirmation before activating.

Guard: NOT when `@`-reference present — that's [spec-mode.md](spec-mode.md), not spec-creation.

**Mid-clarify state transfer**: round budget does not carry forward. Resume from first unanswered interview step. Pre-populate answered steps from clarify state. Carry `known`/`unknown` inventory, `codebase_signals`, `external_signals`, session log.

## 2. Interview

Sequential. Do not skip or reorder steps.

### 2a. Problem

What situation needs to change? Extract from user input or ask directly. One paragraph — no solutions, no implementation details. May be pre-populated from clarify state.

### 2b. Users & Context

Who is affected? What is the current state? Identify:
- Primary users (human or system)
- Current workaround or absence thereof
- Relevant existing infrastructure

### 2c. Constraints

Elicit: out-of-scope items, hard limits (perf/compat/security), non-goals. Push back on "no constraints" — ask: "What would you reject if someone added it to this work?"

### 2d. Phases

Break the capability into 3-6 phases. Push back outside this range:
- < 3 phases: likely a single-session task — suggest do-plan directly
- \> 6 phases: decompose into separate specs or collapse related work

Each phase gets:
- **Title**: short, action-oriented
- **Scope**: concrete file/component names — not abstract nouns
- **Acceptance Criteria**: 2-5 EARS statements per [spec-template.md](spec-template.md)
- **Out of scope**: what this phase explicitly does not touch

## 3. Envoy Injection Point A

After phases+EARS drafted, before DAG. Advisory-only, sequential.

Load `use-envoy`. Dispatch `@envoy`:
- Prompt: problem + users/context + constraints + phases + EARS (self-contained — no local path references)
- Output: `.scratch/<session>/discuss-spec-phases-envoy.md`

Main thread reads Envoy output, incorporates adjustments, presents DAG with refinements noted.

Skip: proceed without if provider unavailable. Do NOT block on Envoy failure.

## 4. DAG Elicitation

1. **Infer dependencies conservatively** — more deps = safer. A phase that reads output from another phase depends on it. When uncertain, add the dependency.
2. **Populate `Depends on:`** per phase — list phase numbers (comma-separated), or `none` for root phases. `Depends on: none` must be explicit for roots.
3. **Present the dependency graph** to user for confirmation. Format:
   ```
   Phase 1 (root) → Phase 2 → Phase 4
                  → Phase 3 → Phase 4
   ```
4. **Cycle warning**: if the graph contains cycles, flag them as advisory. Cycles indicate phase boundaries need adjustment.

User must confirm the dependency graph before output. If rejected → revise phases/dependencies, re-present. If user rejects DAG after Envoy-A feedback, do NOT re-dispatch Envoy-A.

## 5. Envoy Injection Point B

After DAG confirmed, before file creation. Advisory-only, sequential.

Load `use-envoy`. Dispatch `@envoy`:
- Prompt: full spec draft (self-contained — no local path references)
- Output: `.scratch/<session>/discuss-spec-final-envoy.md`

Present findings to user; user confirms or requests changes before file creation.

Skip: proceed without if provider unavailable. Do NOT block on Envoy failure.

## 6. Output

1. Create `docs/specs/{YY}{WW}-<slug>/spec.md` per the skeleton in [spec-template.md](spec-template.md)
2. Create `docs/specs/{YY}{WW}-<slug>/progress.md` with scaffold:
   ```markdown
   # Progress: <Feature Name>

   | Date | Phase | Action | Detail |
   |------|-------|--------|--------|
   | YYYY-MM-DD | -- | created | Initial spec created |
   ```
   Date format: `YYYY-MM-DD` (ISO 8601).
3. All phases initialize as `[ ] pending` in the Status table

**Slug**: derive from feature name. Lowercase, hyphens, no special chars. Prefix with `{YY}{WW}` — execute `date +%g%V` to get 2-digit ISO year + ISO week (do not fabricate). Use `%g` not `%y` — `%y` causes year-boundary bugs at week 52/53 crossover. Example: "Auth Retry System" → `2612-auth-retry-system`.

**Capability section**: what the system will do after all phases complete. Present tense, outcome-focused. 2-4 sentences — not a phase, the aggregate capability.

**Success Criteria section**: top-level EARS statements across the entire spec, not per-phase. Validate the complete feature. 3-5 statements.

**Open Questions section**: unresolved items from interview. Each entry: question, affected phase(s), whether it blocks phase start. Open questions don't block spec creation — they block phase execution.

## 7. Revision Mode

When `@`-referenced spec.md exists AND user explicitly requests "rewrite"/"recreate":

1. Edit spec.md in-place — do not recreate
2. Re-run relevant interview steps for changed sections
3. Preserve status of unchanged phases

**Slug collision**: if `docs/specs/{YY}{WW}-<slug>/` exists but contains no `spec.md` — warn user about orphaned directory before proceeding.

## 8. Handoff

Suggest `/do-discuss @docs/specs/{YY}{WW}-<slug>/spec.md` with message:

> Spec created. To begin Phase 1 planning, run this command — it activates spec-mode for phase-scoped Socratic dialogue before planning.

Do NOT suggest `/do-plan` directly. Do NOT auto-trigger do-plan.

## 9. Session Log

If session ID exists (mid-clarify activation): append to existing session log.
If none (intake activation): generate per SPINE.md convention, then append.

Log at: problem defined, constraints elicited, phases drafted, Envoy-A dispatched, DAG confirmed, Envoy-B dispatched, files created.

## 10. Anti-Patterns

- Auto-triggering do-plan after spec creation
- Prose acceptance criteria instead of EARS format
- Phase count outside 3-6 without explicit pushback
- Omitting Constraints & Non-Goals section
- Abstract scope descriptions without file/function names
- Skipping user confirmation of dependency graph
- Fabricating `{YY}{WW}` prefix instead of executing `date +%g%V`
- "No constraints" accepted without pushback
- Recreating spec when `@`-reference exists (edit in-place)
- Dispatching `@scout` or clarify-assist during spec-creation interview steps
