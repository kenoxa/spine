# Phase Discipline: Build

**Autonomous mode.** In `/goal` flows there is no user STOP. User-STOP gates become emit-artifact-and-halt signals.

## Phase Trace — MANDATORY (log before each dispatch)

Append a row to `session-log.md` at EVERY boundary: **each slice boundary AND each dispatch boundary**. Omitting rows is a protocol violation.

## Slice Invariant

Execute slices in declared order. NEVER advance past a slice without E3 exit gate.

## Per-Slice Loop

1. **Implement** — invoke `@implementer` with slice scope.
2. **Review** — invoke `@inspector`. Binary gate: PASS → advance; BLOCKED → invoke `/run-polish` (max 3 polish iterations per slice), then re-review.
3. **Cap** — 5 review iterations per slice. At cap: write `build-status.json` `status=blocked`, halt.
4. **Exit gate (E3)** — verify deliverables exist at declared paths.

## Terminal Outcome — ALWAYS write build-status.json

Write atomically to `.scratch/<session>/build-status.json` on EVERY outcome (pass/blocked/failed):
`{ session, slice, status, reason, evidence: [...], learnings: [...], next }`

**Learnings field is MANDATORY regardless of outcome.**

- **Emitter**: mainthread/orchestrator writes `build-status.json` only after all verification phases complete. Subagents (implementer/inspector/envoy) NEVER write the terminal artifact — they emit their own role-specific outputs, and mainthread synthesizes the final status.

## Refuse

Adjacent refactors, backcompat shims, scope creep — refuse immediately and surface to user.

## Autonomous Halt Signals

| Signal | Action |
|--------|--------|
| review cap reached (5) | build-status blocked → halt |
| slice exit gate fails | build-status blocked → halt |
| scope expansion detected | refuse → surface to user → halt |
