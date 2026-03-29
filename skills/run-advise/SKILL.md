---
name: run-advise
description: >
  Multi-model perspective gathering with synthesis.
  Use when: "run-advise", "get perspectives", "gather opinions",
  standalone advisory on approach decisions, or invoked as phase by do-consult.
  Do NOT use when: problem unclear (do-analyze), full consultation workflow
  with feedback loop needed (do-consult), implementation ready (run-implement).
argument-hint: "[problem, approach question, or analysis_artifact]"
---

Standalone (user question) or embedded (`analysis_artifact` from caller). Dispatches multi-model perspectives, synthesizes into directional recommendation.

**Session**: Generate per SPINE.md. When embedded, inherit calling skill's session ID.

**Phase Trace**: per phase-audit.md table format. Log at intake, batch, synthesis, output. Include dispatch count.

## Phases

**Subagent references** (backticked): dispatch to subagent -- do NOT Read into mainthread.

| # | Phase | Type | Agent | Reference |
|---|-------|------|-------|-----------|
| 1 | Intake | mainthread | — | — |
| 2 | Batch | C (4 agents) | `@consultant` (x2) + `@navigator` + `@envoy` | `references/advise-dispatch.md`, `references/advise-navigator.md`, `references/advise-envoy.md` |
| 3 | Synthesis | C (1 agent) | `@synthesizer` | `references/advise-synthesis.md` |
| 4 | Output | mainthread | — | — |

### 1. Intake

Accept: question from user (standalone) OR analysis_artifact/context from caller (embedded).

- **Standalone with thin input** (fewer than 3 concrete constraints/criteria): ask one grounding question before dispatch.
- **Embedded with analysis_artifact**: skip questions, dispatch directly.
- **Variance**: match task keywords against [variance-lenses.md](references/variance-lenses.md); select 0-2 lenses. A matched lens counts as one constraint toward the 3-constraint threshold. Freeze lenses on first dispatch — do not re-derive on re-dispatch rounds.

Exit: dispatch context assembled with >=3 constraints, OR analysis_artifact present. Include selected lenses (if any) in dispatch context for all batch agents.

### 2. Batch

Dispatch in parallel:
- `rigorous` (`@consultant`) → `references/advise-dispatch.md` (rigorous angle)
- `creative` (`@consultant`) → `references/advise-dispatch.md` (creative angle)
- `navigator` (`@navigator`) → `references/advise-navigator.md`
- `envoy` (`@envoy`) → `references/advise-envoy.md` (via `use-envoy`)

**Cap**: 4 dispatches. Output: `.scratch/<session>/advise-batch-{rigorous,creative,navigator,envoy}.md`.

### 3. Synthesis

Entry: all 4 batch outputs exist (or gap-flagged). Sequential `@synthesizer` via `references/advise-synthesis.md`. Retry once on empty; halt on failure. Output: `.scratch/<session>/advise-synthesis.md`.

### 4. Output

Present synthesis to caller/user as `advise_artifact`.

- **Standalone**: present for user decision.
- **Embedded**: return to caller.

## Anti-Patterns

- Producing implementation plans (directional advice only)
- Auto-resolving model disagreements (divergence is signal)
- Skipping batch dispatch and answering in mainthread
