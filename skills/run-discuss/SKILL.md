---
name: run-discuss
description: >
  Clarify ambiguous problems and decisions through targeted questioning.
  Use when: "discuss", "clarify", "help me frame", "what exactly",
  "narrow this down", "let's talk through", "what are we solving".
  Do NOT use when: codebase exploration needed (run-explore),
  multi-model advisory needed (run-advise), build-ready (do-build).
argument-hint: "[topic, problem, or decision to clarify]"
---

Propose-and-refine interview producing `discuss_artifact`. Standalone or composed by `do-frame` / `do-design`.

Accepts optional `scope` (frame|design), `goal`, and `codebase_signals` from parent skill. Standalone: infer scope from context, default frame.

Read lens reference matching scope at session start: `frame` → [discuss-lens-frame.md](references/discuss-lens-frame.md), `design` → [discuss-lens-design.md](references/discuss-lens-design.md).

## Protocol

Read [discuss-protocol.md](references/discuss-protocol.md) at session start.

| # | Phase | Type |
|---|-------|------|
| 1 | Seed | mainthread |
| 2 | Propose | mainthread (interactive) |
| 3 | Probe | G — invoke `/run-explore` on demand |
| 4 | Declare | mainthread |

### 1. Seed

Initialize `known`/`unknown` from `codebase_signals` and `goal`. Classify unknowns by type: scope, parameter, constraint.

**Challenge initial framing**: if user presents a diagnosis or solution as the problem ("the cache is broken", "we need to refactor X"), treat it as a hypothesis — add to `unknown` with `type: scope`, not `known`. Probe the underlying symptom before building on the assumption.

### 2. Propose

For each blocking unknown: propose interpretation, ask user to confirm/redirect/reject. Batch 2-3 per exchange. Never ask blank questions — every question includes a proposed answer.

Calibrated depth: simple (2-3 questions), complex (5-8).

### 3. Probe

User response surfaces codebase question → invoke `/run-explore` for targeted probe. Feed result into known table. Skip user turn. Zero-dispatch when no codebase question surfaces — log with justification.

### 4. Declare

Convergence: no blocking unknowns remain. Before emitting artifact: verify Phase Trace has 4 rows (Seed, Propose, Probe, Declare).

Emit `discuss_artifact` with known table, open items (informational only), confidence.

Stall: 3 exchanges with no state change → surface gaps, suggest next step.

## Output

Write `discuss_artifact` to `.scratch/<session>/discuss-artifact.md`. Schema in `references/discuss-protocol.md`.

## Anti-Patterns

- Asking questions answerable from codebase_signals (use run-explore probes instead)
- Open-ended questions when enough signal exists to propose an interpretation
- Turn-count termination instead of state-delta convergence
- Accepting user's initial diagnosis as fact without probing the underlying symptom
- Scope drift: WHAT questions in design lens, HOW questions in frame lens
