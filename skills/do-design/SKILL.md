---
name: do-design
description: >
  HOW-focused solution design via multi-skill composition.
  Use when: "design", "plan the approach", "advise", "what approach",
  "how should we", "do-design", "second opinion", "consult".
  Do NOT use when: problem unclear (do-frame), build-ready (do-build),
  reproducible defect (run-debug).
argument-hint: "[frame_artifact, problem statement, or area needing direction]"
---

Compose run-discuss (design scope) + run-advise + optional run-explore. User feedback loop with re-dispatch cap.

Log each phase to Phase Trace (session-log) at boundary. Zero-dispatch phases require row with justification.

## Phases

| # | Phase | Type | Skills |
|---|-------|------|--------|
| 1 | Intake | R — mainthread + conditional `/run-discuss` | `/run-discuss` (scope=design) |
| 2 | Advise | C — invoke `/run-advise` | `/run-advise` |
| 3 | Validate | G — invoke on demand | `/run-explore` |
| 4 | Decide | mainthread | — |

**Phase Trace**: verify rows for intake, advise, validate, decide before STOP.

### 1. Intake

Accept: `frame_artifact` from `/do-frame`, freeform problem statement, or user pushback from prior round.

- **With frame_artifact**: extract constraints and blast-radius. Skip run-discuss when >= 3 concrete constraints.
- **Thin input** (fewer than 3 constraints): invoke `/run-discuss` with `scope: design`, `goal` from user input.
- **Re-dispatch**: invoke `/run-discuss` to drill into why the user resists before re-running advisory.

**Session**: reuse from `/do-frame` when carrying `frame_artifact`; generate otherwise.

### 2. Advise

Invoke `/run-advise` with problem context, constraints from `frame_artifact` or `discuss_artifact`. Returns `advise_artifact`.

### 3. Validate

When advisory surfaces assumptions about codebase state, invoke `/run-explore` for feasibility probes. Feed results back into advisory context.

Zero-dispatch when advisory is self-contained — log with justification.

### 4. User Decision Gate

Assemble `design_artifact` per [design-artifact.md](references/design-artifact.md) from `advise_artifact` + `frame_artifact`. Write to `.scratch/<session>/design-artifact.md`. Present to user — direction and delivery slicing reviewed together. Main thread = sole decision authority.

| User action | Response |
|------------|----------|
| Approves | Suggest `/do-build`. STOP. |
| Pushes back | Return to Intake with `/run-discuss` to refine, then re-dispatch `/run-advise` |
| Rejects | Redirect to `/do-frame`. STOP. |

STOP after presenting. Never auto-forward. **Cap**: 3 re-dispatch rounds; surface stall after cap.

## Anti-Patterns

- Auto-forwarding to `/do-build` without user approval
- Resolving model disagreements silently — divergence is signal, surface it
- Producing per-file implementation plans — that is `/do-build`'s scope phase job
- Bypassing run-advise to dispatch agents directly
- Re-dispatching full advisory batch when run-discuss could resolve pushback locally
- Ignoring frame_artifact constraints — carry all constraints into run-advise dispatch
