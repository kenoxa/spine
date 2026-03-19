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

## 3. Envoy Injection Point A

After phases+EARS drafted, before DAG. Load `use-envoy`. Dispatch `@envoy`:
- Prompt: problem + users/context + constraints + phases + EARS (self-contained)
- Tier: standard → `.scratch/<session>/discuss-spec-phases-envoy.md`

Main thread reads output, incorporates adjustments. Skip on failure: `[COVERAGE_GAP: envoy — provider unavailable]`.

## 4. DAG Elicitation

Infer dependencies conservatively (more = safer). Populate `Depends on:` per phase — phase numbers or `none` for roots. Present graph to user for confirmation. Cycles = phase boundaries need adjustment.

User must confirm before output. Rejection → revise, re-present. Do NOT re-dispatch Envoy-A after rejection.

## 5. Envoy Injection Point B

After DAG confirmed. Load `use-envoy`. Dispatch `@envoy`:
- Prompt: full spec draft (self-contained)
- Tier: standard → `.scratch/<session>/discuss-spec-final-envoy.md`

Present findings; user confirms before file creation. Skip on failure: `[COVERAGE_GAP: envoy — provider unavailable]`.

## 6. Output

Create `docs/specs/{YY}{WW}-<slug>/spec.md` per [template-spec.md](template-spec.md) + `progress.md` with scaffold. All phases: `[ ] pending`.

**Slug**: lowercase, hyphens. Execute `date +%g%V` for prefix — use `%g` not `%y` (year-boundary bugs). **Capability**: what system does after all phases. Present tense, 2-4 sentences. **Success Criteria**: top-level EARS across entire spec, 3-5 statements. **Open Questions**: unresolved items — question, affected phase(s), blocks-start flag.

## 7. Revision Mode

`@`-referenced spec.md + explicit "rewrite"/"recreate": edit in-place, re-run relevant steps, preserve unchanged phase status. Slug collision (dir exists, no spec.md) → warn user.

## 8. Handoff

Suggest `/do-discuss @docs/specs/{YY}{WW}-<slug>/spec.md`. Do NOT suggest `/do-plan` directly.

## 9. Session Log

Append to existing if mid-clarify; generate new if intake activation. Log at: problem defined, constraints elicited, phases drafted, Envoy-A, DAG confirmed, Envoy-B, files created.

## 10. Anti-Patterns

- Auto-triggering do-plan after spec creation
- Prose acceptance criteria instead of EARS format
- Phase count outside 3-6 without pushback
- Abstract scope without file/function names
- Skipping user confirmation of dependency graph
- Fabricating `{YY}{WW}` instead of executing `date +%g%V`
- Recreating spec when `@`-reference exists (edit in-place)
