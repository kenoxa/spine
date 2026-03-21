# Spec-Creation Mode

Terminal branch — emits spec.md + progress.md only, never brief.md. Do NOT auto-trigger do-plan.

## 1. Activation

Two triggers:
- **Intake**: scope exceeds single session (2-of-3: multiple phases, cross-cutting concerns [3+ unrelated modules], multi-day signals) AND no `@`-reference.
- **Handoff**: Frame phase brief recommends `spec-creation`. Full brief + accumulated state carried forward.

Guard: present scope-signal evidence, get user confirmation. NOT when `@`-reference present — that's [spec-mode.md](spec-mode.md).

**State transfer**: full brief, `known`/`unknown`, `codebase_signals`, `external_signals`, session log. Resume from first unanswered step. Pre-populate answered steps.

## 2. Interview

Sequential. Do not skip or reorder.

| Step | Elicit | Pushback trigger |
|------|--------|-----------------|
| **Problem** | What situation needs to change? One paragraph — no solutions. | Input contains implementation details |
| **Users & Context** | Primary users, current workaround, relevant infrastructure. | Missing stakeholder identification |
| **Constraints** | Out-of-scope, hard limits (perf/compat/security), non-goals. | "No constraints" — ask: "What would you reject if someone added it?" |
| **Phases** | 3-6 phases. Title, scope (concrete file/component names), 2-5 EARS criteria per [template-spec.md](template-spec.md), out-of-scope. | < 3 → suggest do-plan. > 6 → decompose into separate specs or collapse. |

## 3. Phase Review

After phases+EARS drafted, before DAG. Dispatch in parallel:
- `@framer` + `spec-phases-reviewer.md`: problem + phases + EARS → `.scratch/<session>/discuss-spec-phases-review.md`
- `@envoy` (via `use-envoy`): prompt = problem + users/context + constraints + phases + EARS (self-contained). Tier: standard. Mode: multi → `.scratch/<session>/discuss-spec-phases-envoy.md`

Then sequential:
- `@synthesizer` + `spec-phases-synthesis.md`: all review outputs → `.scratch/<session>/discuss-spec-phases-synthesis.md`

Main thread reads synthesis, incorporates adjustments. Envoy skip/partial: `[COVERAGE_GAP: envoy — {provider} unavailable]`.

Cap: framer(1) + envoy(1) + synthesizer(1) ≤ 3.

## 4. DAG Elicitation

Infer dependencies conservatively (more = safer). Populate `Depends on:` per phase — phase numbers or `none` for roots. Present graph to user for confirmation. Cycles = phase boundaries need adjustment.

User must confirm before output. Rejection → revise, re-present. Do NOT re-dispatch Phase Review after rejection.

## 5. Spec Review

After DAG confirmed. Dispatch in parallel:
- `@inspector` + `spec-final-reviewer.md`: full spec draft (self-contained) → `.scratch/<session>/discuss-spec-final-review.md`
- `@envoy` (via `use-envoy`): prompt = full spec draft (self-contained). Tier: standard. Mode: multi → `.scratch/<session>/discuss-spec-final-envoy.md`

Then sequential:
- `@synthesizer` + `spec-final-synthesis.md`: all review outputs → `.scratch/<session>/discuss-spec-final-synthesis.md`

Main thread reads synthesis. Blocking findings (E2+) require user resolution before file creation. Envoy skip/partial: `[COVERAGE_GAP: envoy — {provider} unavailable]`.

Cap: inspector(1) + envoy(1) + synthesizer(1) ≤ 3.

## 6. Output

Create `docs/specs/{YY}{WW}-<slug>/spec.md` per [template-spec.md](template-spec.md) + `progress.md` with scaffold. All phases: `[ ] pending`.

**Slug**: lowercase, hyphens. Execute `date +%g%V` for prefix — use `%g` not `%y` (year-boundary bugs). **Capability**: what system does after all phases. Present tense, 2-4 sentences. **Success Criteria**: top-level EARS across entire spec, 3-5 statements. **Open Questions**: unresolved items — question, affected phase(s), blocks-start flag.

## 7. Revision Mode

`@`-referenced spec.md + explicit "rewrite"/"recreate": edit in-place, re-run relevant steps, preserve unchanged phase status. Slug collision (dir exists, no spec.md) → warn user.

Review pipeline scaling: revision touching ≤1 phase → skip Phase Review (section 3), re-run Spec Review (section 5) only. Changes to ≥2 phases or DAG structure → full pipeline (both sections 3 and 5).

## 8. Handoff

Suggest `/do-discuss @docs/specs/{YY}{WW}-<slug>/spec.md`. Do NOT suggest `/do-plan` directly.

## 9. Session Log

Append to existing if mid-clarify; generate new if intake activation. Log at: problem defined, constraints elicited, phases drafted, Phase Review, DAG confirmed, Spec Review, files created.

## 10. Anti-Patterns

- Auto-triggering do-plan after spec creation
- Prose acceptance criteria instead of EARS format
- Phase count outside 3-6 without pushback
- Abstract scope without file/function names
- Skipping user confirmation of dependency graph
- Fabricating `{YY}{WW}` instead of executing `date +%g%V`
- Recreating spec when `@`-reference exists (edit in-place)
