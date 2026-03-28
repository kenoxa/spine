---
name: do-consult
description: >
  Structured HOW consultation composing multi-model advisory with user feedback loop.
  Use when: "consult", "get direction", "advise", "what approach",
  "how should we", "do-consult", "second opinion".
  Do NOT use when: problem unclear (do-analyze), build-ready (do-build),
  reproducible defect (run-debug).
argument-hint: "[analysis_artifact, problem statement, or area needing direction]"
---

HOW-focused consultation composing `/run-advise` with iterative user feedback.

## Phases

| Phase | Mechanism | Reference |
|-------|-----------|-----------|
| Intake | mainthread | — |
| Advise | invoke `/run-advise` | — |
| Decide | mainthread | — |

**Phase Trace**: verify rows for intake, advise, decide before STOP.

### Intake

- Accept: `analysis_artifact` from `/do-analyze`, freeform problem statement, or user pushback from prior round.
- Thin input → grounding question before dispatch.
- Re-dispatch: incorporate pushback; carry prior outputs as signal.
- Variance: once at intake; match [variance-lenses.md](references/variance-lenses.md); 1-2 lenses; carry unchanged.

**Session**: reuse from `/do-analyze` when carrying `analysis_artifact`; generate otherwise.

### Advise

Invoke `/run-advise` with problem context or `analysis_artifact`. Returns `advise_artifact`.

### User Decision Gate

Present `advise_artifact` synthesis. Main thread = sole decision authority.

| User action | Response |
|------------|----------|
| Approves | Suggest `/do-build`. STOP. |
| Pushes back | Re-invoke `/run-advise` with refined context (return to Intake) |
| Rejects | Redirect to `/do-analyze`. STOP. |

STOP after presenting. Never auto-forward. **Cap**: 3 re-dispatch rounds; surface stall after cap.

## Anti-Patterns

- Auto-forwarding to `/do-build` without user approval
- Resolving model disagreements silently — divergence is signal, surface it
- Producing per-file implementation plans — that is `/do-build`'s scope phase job
- Bypassing run-advise to dispatch agents directly
- Carrying prior-round outputs without incorporating user pushback
