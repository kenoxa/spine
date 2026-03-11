---
name: run-debug
description: >
  Diagnose and fix bugs through structured 4-phase debugging.
  Use when facing failing tests, crashes, regressions, unexpected behavior,
  or non-deterministic / flaky failures.
  Do NOT use when the problem is unclear scope or missing requirements — use /do-plan instead.
argument-hint: "[error, failing test, or symptom]"
---

Diagnose root cause and fix: observe → pattern → hypothesis → harden.

## 1. Observe and Capture

Reproduce deterministically. Capture exact error, steps, environment, variance. Record known vs unknown before editing code.

## 2. Pattern Analysis

Generate 5–7 falsifiable hypotheses from distinct failure classes: timing, data shape, config, ordering, boundary, dependency, environment. Narrow to 1–2 most likely on static evidence only — no code changes yet. Deprioritize rest as `LOW-PRIOR: <reason>`; revisit if all Phase 3 survivors fail. Narrow to smallest collision zone distinguishing surviving hypotheses.

## 3. Hypothesis Testing

If non-deterministic, stabilize first. Static analysis before instrumentation.

Wrap each instrumentation block: `DEBUG:start-<tag>` / `DEBUG:end-<tag>` in language comment syntax; `<tag>` = 4-char session hash (`openssl rand -hex 2`). Add broad instrumentation covering all surviving hypotheses simultaneously. Statements append to `.scratch/<session>/debug.log`; clear before each reproduction run.

Reproduce. Analyze `debug.log` to eliminate hypotheses in one pass. Record eliminated as `DEAD END: <reason>`. Narrow to survivors. Repeat until one confirmed (E3).

Removal command (user runs):
```
rg -l 'DEBUG:start-<tag>' . | xargs sd -f ms '[^\n]*DEBUG:start-<tag>[^\n]*\n[\s\S]*?[^\n]*DEBUG:end-<tag>[^\n]*\n' ''
```

All candidates DEAD END → escalate. Failed hypothesis → return to Phase 1, not forward. This is a loop.

## 4. Implement and Harden

Apply smallest fix resolving confirmed root cause. Harden to make bug class impossible:
- Entry validation
- Domain invariants
- Environment guardrails
- Regression test coverage

Verification requires current-run evidence (E3). Confirm instrumentation removed: `rg 'DEBUG:start-<tag>' .` returns zero hits before marking complete. Semantic regression → re-enter Phase 1. Non-semantic failure (lint, format) → fix inline.

## Escalation into Root-Cause Chain

Root cause unclear after Phase 2, or failure spans multiple modules: chain "why" grounded in observed evidence. Stop when cause is actionable. Branching unknowns → return to Phase 1.

## Unsticking Patterns

- **Simplification cascade**: strip non-essential parts until failure obvious.
- **Collision-zone narrowing**: reduce to smallest interacting set that still fails.
- **Inversion check**: validate assumptions by forcing opposite conditions.
- **Boundary stress**: test near limits to expose hidden conditions.
- **Determinism isolation**: fix seed, mock time, remove network/filesystem calls until failure reproduces on demand.

## Escalation

3 failed hypotheses → escalate with concrete evidence and attempted alternatives. Architectural uncertainty or repeated cross-module failures → re-enter planning (`/do-plan`).

## Anti-Patterns

- Skipping reproduction because fix "seems obvious"
- Bundling speculative edits across multiple subsystems
- Suppressing errors to force green checks
- Stopping at symptom relief when source trigger unknown
- Claiming completion without current-run verification evidence
- Adding instrumentation before generating and ranking hypotheses
- Leaving debug instrumentation in code after confirming and applying fix
