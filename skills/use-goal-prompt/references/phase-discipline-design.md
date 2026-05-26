# Phase Discipline: Design

**Autonomous mode.** In `/goal` flows there is no user STOP. User-STOP gates become emit-artifact-and-halt signals.

## MANDATORY Steps (no zero-dispatch exception)

1. **Advise** — invoke `@advisor` (or `/run-advise`) with the frame artifact + constraints as context. Write output to `.scratch/<session>/advise-synthesis.md`.
2. **Council** — immediately after advise returns, invoke `@advisor-council` (or `/run-council`) with `advise_synthesis_path=.scratch/<session>/advise-synthesis.md`. Write output to `.scratch/<session>/council-synthesis.md`.

Both steps required. Neither may be skipped. Zero-dispatch is never valid at this phase.

## Divergence Rule

When council-synthesis recommendation diverges from advise-synthesis recommendation:
1. Write `.scratch/<session>/divergence-artifact.md` with the conflict in plain English.
2. Halt via Stop hook. Never auto-resolve. Never proceed past divergence without explicit resolution.

## Re-dispatch Cap

Maximum 3 rounds. At cap: write `build-status.json` with `status=blocked`, `reason="design-redispatch-cap"`, halt.

## Phase Trace

Append a row to `session-log.md` at each boundary: **intake → advise → validate → decide**.

Zero-dispatch decisions (validate only) require a justification row.

## Design Artifact Emission

Write `design-artifact.md` per `skills/use-goal-prompt/references/design-artifact-schema.md` schema. Inputs: frame artifact, advise-synthesis, council-synthesis. Write to `.scratch/<session>/design-artifact.md`.

## Autonomous Halt Signals

| Signal | Action |
|--------|--------|
| council diverges from advise | emit divergence-artifact → halt |
| re-dispatch cap reached | write build-status.json blocked → halt |
| user-STOP gate (interactive) | emit design-artifact → halt |
