---
name: run-debug
description: >
  Diagnose and fix bugs through structured 4-phase debugging.
  Use when facing failing tests, crashes, regressions, unexpected behavior,
  or non-deterministic / flaky failures.
  Do NOT use when the problem is unclear scope or missing requirements — use /do-plan instead.
argument-hint: "[error, failing test, or symptom]"
---

Diagnose root cause and fix: observe → pattern → hypothesis → harden. Subagent-dispatched with orchestrator-managed loop.

## Phase Table

**Reference paths** (backticked): dispatch to subagent — do NOT Read into mainthread.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Observe | `@scout` | `references/observe-scout.md` |
| Pattern | `@researcher` | `references/pattern-researcher.md` |
| Hypothesis | `@implementer` | `references/hypothesis-implementer.md` |
| Harden | `@implementer` | `references/harden-implementer.md` |

## Loop State

```
hypothesis_attempts: 0        # increment on each hypothesis dispatch, cap 5
dead_ends: .scratch/<session>/debug-dead-ends.md   # append-only
current_phase: observe         # observe | pattern | hypothesis | harden
instrumentation_tag: <4-char hex from openssl rand -hex 2>  # generated once per session
```

## Flow

```
observe(@scout) → pattern(@researcher) → hypothesis(@implementer) → harden(@implementer)
```

**Backtrack**: hypothesis fails → orchestrator appends failed hypotheses to `dead_ends` → increment `hypothesis_attempts` → re-dispatch observe with `dead_ends` path.

**Proceed**: hypothesis confirmed → dispatch harden with confirmed hypothesis.

## Dispatch Protocol

Each dispatch is self-contained. Pass by path:
- Observe: error description, `dead_ends` path (if backtracking)
- Pattern: `debug-observe.md` path, `dead_ends` path (if exists)
- Hypothesis: `debug-pattern.md` path, `dead_ends` path, `instrumentation_tag`
- Harden: `debug-hypothesis.md` path, `instrumentation_tag`

After each hypothesis dispatch, orchestrator reads `debug-hypothesis.md` header (`status: confirmed|failed`) to decide backtrack or proceed.

## Escalation

- 3 failed hypotheses (`hypothesis_attempts >= 5`) → halt loop, report all dead-end evidence to user, suggest `/do-plan` for architectural investigation.
- Architectural uncertainty or repeated cross-module failures → re-enter planning (`/do-plan`).

## Anti-Patterns

- Skipping reproduction because fix "seems obvious"
- Bundling speculative edits across multiple subsystems
- Suppressing errors to force green checks
- Stopping at symptom relief when source trigger unknown
- Claiming completion without current-run verification evidence
- Adding instrumentation before generating and ranking hypotheses
- Leaving debug instrumentation in code after confirming and applying fix

## Completion

Verification requires current-run evidence (E3). Confirm instrumentation fully removed before marking complete.
