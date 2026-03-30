---
name: do-frame
description: >
  WHAT-focused problem framing.
  Use when: "frame", "frame this", "what's the problem",
  "scope this", "understand this", "what are we solving",
  "investigate this", "what's happening", "what's going on",
  "analyze", "analyze this".
  Do NOT use when: solution design needed (do-design), build-ready (do-build),
  reproducible defect (run-debug).
argument-hint: "[problem, symptom, or area to frame]"
---

Phases: orient → clarify → investigate → handoff. Triangulates codebase evidence (run-explore) with human intent (run-discuss). Produces `frame_artifact` (see `references/frame-dispatch.md`). Never prescribes HOW.

Artifact schema and field mapping: `references/frame-dispatch.md`.

Log each phase to Phase Trace (session-log) at boundary. Zero-dispatch phases require row with justification.

## Phases

| # | Phase | Type | Skills |
|---|-------|------|--------|
| 1 | Orient | R — invoke skill(s) | `/run-explore` + adaptive |
| 2 | Clarify | C — invoke `/run-discuss` | `/run-discuss` (scope=frame) |
| 3 | Investigate | G — adaptive for blocking unknowns | skill matched to unknown type |
| 4 | Handoff | mainthread | — |

### 1. Orient

Invoke `/run-explore` for codebase reconnaissance. Scan input for adaptive signals:
- Defect symptoms (errors, crashes, data loss, missing records, inconsistent state, unexpected behavior, "drops", "gaps", "intermittent") → also invoke `/run-debug`
- Coupling/module/boundary language → also invoke `/run-architecture-audit`

Skip when input is purely conceptual. Carry orient key_findings + risks into clarify as `codebase_signals`.

### 2. Clarify

Invoke `/run-discuss` with `scope: frame`, `goal` from user input, and `codebase_signals` from orient. Returns `discuss_artifact` — projection into frame state defined in lens reference.

### 3. Investigate

Target blocking unknowns from clarify. Match skill to unknown type:
- Code structure unknowns → `/run-explore` with depth queries
- Defect unknowns → `/run-debug` with targeted hypothesis
- Architecture unknowns → `/run-architecture-audit` with focused scope
- External unknowns → `/run-research` for ecosystem context

Max 2 rounds. Zero-dispatch when no blocking unknowns remain — log with rationale.

### 4. Handoff

Verify Phase Trace has rows for orient, clarify, investigate, handoff.

Assemble `frame_artifact` per `references/frame-dispatch.md`. When a blocking unknown is feasibility-related, redirect to `/do-design` (WHAT/HOW escape hatch).

**Spec persistence**: When confidence is high or medium, offer to persist `frame_artifact` to `docs/specs/{YYWW}-<slug>/spec.md`. User confirms.

Carry session ID into `/do-design`.

Confidence-gated:

| Confidence | Declaration |
|------------|-------------|
| high | "Framing complete. Proceed with `/do-design` for solution design." |
| medium | "Framing complete with open unknowns. Proceed with `/do-design` or resolve first." |
| low | "Needs further investigation." |

STOP after declaration. User decides next step.

## Anti-Patterns

- Prescribing HOW: solutions, implementation approaches, architecture decisions
- Using only run-explore when signals indicate run-debug or run-architecture-audit
- Inlining Socratic interview logic instead of invoking run-discuss
- Ranking or recommending options — framing maps the problem, not the solution space
- Skipping orient when input is codebase-adjacent
- Carrying blocking unknowns past handoff without flagging confidence
