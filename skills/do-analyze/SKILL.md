---
name: do-analyze
description: >
  Socratic WHAT-focused analysis: problem decomposition, constraint mapping,
  blast-radius assessment. Use when: "analyze", "analyze this", "what's the problem",
  "scope this", "understand this", "frame this", "what are we solving",
  "investigate this", "what's happening", "what's going on".
  Do NOT use when: solution design needed (do-consult), build-ready (do-build),
  reproducible defect (run-debug).
argument-hint: "[problem, symptom, or area to analyze]"
---

WHAT-focused Socratic dialogue composing run-explore: orient → clarify → investigate → handoff. All phases execute (zero-dispatch with justification when not applicable). Produces `analysis_artifact` (see `references/analyze-dispatch.md`). Never prescribes HOW.

## Phases

**Phase dispatch reference**: `references/analyze-dispatch.md` — lazy-load into mainthread at session start. Read via the Read tool.

| Phase | Mechanism | Reference |
|-------|-----------|-----------|
| Orient | invoke `/run-explore` | — |
| Clarify | mainthread + invoke `/run-explore` on demand | — |
| Investigate | invoke `/run-explore` | — |
| Handoff | mainthread | — |

### Orient

Invoke `/run-explore` for codebase reconnaissance. Skip when input is purely conceptual. Carry `key_findings` + `risks_or_unknowns` into clarify as `codebase_signals` + `external_signals`.

### Clarify

Convergence-driven interview. Mainthread. Seed `known` from orient signals. Track `known`/`unknown` + `key_assumptions` (settled/disputed); batch 2-4 independent questions per exchange.

Decompose input at start: if stated problem is actually a proposed solution, redirect to the underlying need.

Questions must be WHAT-scoped. Redirect HOW questions back to WHAT.

**Proactive exploration**: when user answers surface new codebase questions ("does X exist?", "how many callers?"), invoke `/run-explore` mid-dialogue for targeted probes. Skip visualize phase on these interleaved invocations.

Stall detection: 3 exchanges with no state changes → surface gaps, recommend next step.

### Investigate

Invoke `/run-explore` with targeted queries for blocking unknowns. Use depth question types ("how does X work? call chains?"). Max 2 rounds.

### Handoff

Verify Phase Trace has rows for orient, clarify, investigate, handoff. Zero-dispatch phases require row with justification.

Assemble `analysis_artifact` per `references/analyze-dispatch.md`.

**Spec persistence**: When confidence is high or medium, offer to persist `analysis_artifact` to `docs/specs/{YYWW}-<slug>/spec.md`. User confirms. Write-once — finalize does not modify the spec.

Confidence-gated:

| Confidence | Declaration |
|------------|-------------|
| high | "Analysis complete. Proceed with `/do-consult` for solution design." |
| medium | "Analysis complete with open unknowns. Proceed with `/do-consult` or resolve first." |
| low | "Needs further investigation. Consider additional `/run-explore`." |

STOP after declaration. User decides next step.

## WHAT/HOW Escape Hatch

When analysis reveals a blocking feasibility unknown, emit `requires_how_clarification: true` and redirect to `/do-consult`.

## Session

Per SPINE.md. Generate at entry; carry into `/do-consult`. Log at phase boundaries.

## Anti-Patterns

- Prescribing HOW: solutions, implementation approaches, architecture decisions
- Bypassing run-explore to dispatch agents directly
- Ranking or recommending options — analysis maps the problem, not the solution space
- Skipping orient when input is codebase-adjacent
- Carrying blocking unknowns past handoff without flagging confidence
