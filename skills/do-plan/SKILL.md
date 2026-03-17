---
name: do-plan
description: >
  Use when: planning, architecture decisions, multi-file changes, migration strategies,
  "think through", "map out", "figure out approach", open-ended tasks, 3+ files,
  multiple approaches. Do NOT use for single-file edits, simple bug fixes, approved plans.
argument-hint: "[task description]"
---

Produce a self-sufficient, executable plan: discovery → framing → planning → challenge → synthesis. Unclear requirements → run `do-discuss` first.

## Phases

Every subagent prompt MUST be self-contained.

**Session**: per SPINE.md; reuse across phases; carry into do-execute; log at boundaries.

**Evidence**: E0 intuition · E1 doc ref · E2 code ref (file+symbol) · E3 executed command+output. Blocking = E2+.

| Phase | Agent type |
|-------|-----------|
| Discovery | `@researcher`, `@navigator` |
| Planning | `@planner` |
| Challenge | `@debater` |

**Variance**: once at entry; match [variance-lenses.md](references/variance-lenses.md); 1-2 lenses; carry unchanged. Augmented output: `plan-{phase}-augmented-{lens}.md`.

**Spec Mode**: `@`-ref spec → [spec-mode.md](references/spec-mode.md).

### 1. Discovery

Dispatch in parallel:
- `file-scout` (`@researcher`) → [discovery-file-scout.md](references/discovery-file-scout.md)
- `docs-explorer` (`@researcher`) → [discovery-docs-explorer.md](references/discovery-docs-explorer.md)
- `navigator` (`@navigator`) → no ref
- +augmented per `variance_lenses`

**Cap**: ≤ 5

**Synthesis**: `@synthesizer` + [discovery-synthesis.md](references/discovery-synthesis.md). Retry once on empty; halt on failure.

### 2. Framing

Distill discovery into `planning_brief`:

| Field | Content |
|-------|---------|
| `goal` | Disambiguated restatement |
| `scope` | In/out + change surface |
| `constraints` | Perf, security, compat, API |
| `key_decisions` | Numbered, A/B/C, tradeoffs |
| `planner_focus_cues` | E2 pointers — no narrative |
| `evidence_manifest` | Paths, provenance, conflicts |
| `technical_context` | Runtime, deploy, infra |
| `docs_impact` | `customer-facing`/`internal`/`both`/`none` + skip rationale |

Two-Way Door per `key_decision`: reversible → fast; one-way → exhaustive. Limit 2–3 options.
`docs_impact` `customer-facing`/`both` → changelog; load `use-writing`.
Ask before dispatch when scope/risk changes, evidence missing, or conflicts unresolved. Never carry unresolved decisions into synthesis.

### 3. Planning

Dispatch in parallel (`@planner`):
- `rigorous` → [planning-rigorous.md](references/planning-rigorous.md)
- `creative` → [planning-creative.md](references/planning-creative.md)

**Envoy**: `use-envoy` + [planning-envoy.md](references/planning-envoy.md) (variant: `standard`).

**Cap**: (2) + envoy + augmented ≤ 6.

**Synthesis**: `@synthesizer` + [planning-synthesis.md](references/planning-synthesis.md). Retry once on empty; halt on failure.

### 4. Challenge

Adversarial review of `canonical_plan`. Blocking = E2+. Lenses: `assumptions`, `nfr`.
Dispatch in parallel (`@debater`):
- `thesis-champion` → [challenge-thesis-champion.md](references/challenge-thesis-champion.md)
- `counterpoint-dissenter` → [challenge-counterpoint-dissenter.md](references/challenge-counterpoint-dissenter.md)
- `tradeoff-analyst` → [challenge-tradeoff-analyst.md](references/challenge-tradeoff-analyst.md)

**Envoy**: `use-envoy` + [challenge-envoy.md](references/challenge-envoy.md) (variant: `debater`).

**Cap**: (3) + envoy + augmented ≤ 6.

**Synthesis**: `@synthesizer` + [challenge-synthesis.md](references/challenge-synthesis.md). Retry once on empty; halt on failure.
Post-synthesis: `@visualizer` architecture diagram (reads `plan-synthesis-planning.md` + `plan-synthesis-challenge.md`) → `plan-challenge-diagram.html`.

### 5. Synthesis

Main thread. Sole readiness authority.
1. Assemble per [template-plan.md](references/template-plan.md) → `.scratch/<session>/plan.md`
2. Visual: `@visualizer` if warranted → `plan-review.html`
3. Validate [Plan Requirements](#plan-requirements)
4. Confirm blocking findings incorporated/rejected
5. Emit readiness. `semantic` gaps → framing. `non_semantic` → fix inline.

## Plan Requirements

Self-sufficiency (executable sans history, repo-relative paths, defined terms). Test tasks (given/when/then). Edge/failure coverage. Docs (when `docs_impact` ≠ `none`). Completion criteria. Template: [template-plan.md](references/template-plan.md).

## Readiness Declaration

`Plan is ready for execution.` + link to `plan.md` — STOP. Await approval. Declaration ≠ approval.
`Plan is NOT ready` — followed by gaps.

**Cap**: 5 iterations; freeze on cap.

**Anti-Patterns**: unresolved `key_decisions` past ask; re-selecting lenses; same visualizer filename; spec detection on non-`@`-ref files.
