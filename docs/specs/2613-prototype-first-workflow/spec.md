# Prototype-First Workflow

> **Archived**: do-discuss, do-plan, do-execute removed. Canonical flow is now do-analyze → do-consult → do-build.

Replaces the discuss → plan → execute chain with a lighter, faster flow: analyze → consult → build. Code is cheap — build to learn, then refine.

## Problem

The discuss → plan → execute workflow burns 30+ minutes on planning that execution regularly invalidates. Planning reasons over static code references (E2) without running anything. Execution is where learning actually happens, but by then significant context window and session time are consumed.

Evidence: across 10 do-plan sessions, challenge/debate phases caught 12 blocking issues and revised 100% of plans — but 70% of those findings were implementation-level issues that post-build review would catch equally well. The remaining 30% (specification/scoping issues) must be caught pre-build.

## Core Principle: WHAT/HOW Split

Discussion should discover the problem (WHAT). Multiple models should advise on direction (HOW). Implementation should discover the real solution through code. Review validates post-build.

The old workflow's failure: planning tried to figure out both WHAT and HOW through reasoning. The new workflow separates them: reasoning discovers the problem, code discovers the solution.

## Architecture

Four independent skills, chained by session ID handoff:

```
/do              Orchestrator — routes through phases, tracks state
  /do-analyze    WHAT — Socratic dialogue, problem framing, constraints
  /do-consult    HOW — multi-model direction, cross-provider perspectives
  /do-build      DO IT — automated build-review loop, cap 3
```

Each skill is independently invocable. The orchestrator (`/do`) is a convenience entry point that chains them with skip validation.

### do-analyze (replaces do-discuss)

Structurally truncated do-discuss: orient → clarify → investigate → handoff. No explore phase, no frame phase — these are where HOW prescription crept in. Produces `analysis_artifact` with EARS-structured success criteria. Forbidden from outputting solutions, implementation plans, or architecture decisions.

Key additions over raw do-discuss truncation: `key_assumptions` tracking (settled/disputed), solution-as-problem detection at intake, proactive @scout routing in clarify.

### do-consult (replaces do-plan)

Compressed planning: single batch dispatch (@consultant rigorous + @consultant creative + @navigator + @envoy) → synthesis → user decision gate. Produces `consult_artifact` with MUST/SHOULD/MAY constraints (≤10), rejected alternatives, falsification risks, and scope hints.

Preserves the load-bearing value from do-plan's challenge phase through: (1) multi-model disagreement-as-signal in synthesis, (2) 3 falsification bullets embedded in recommendation, (3) cross-provider envoy dispatch for diverse perspectives.

User feedback loop: approve direction → `/do-build`, push back → re-dispatch with refined context, reject → back to `/do-analyze`.

### do-build (replaces do-execute)

Automated build-review loop: scope → implement → lean review (@verifier + @inspector + @envoy, no advisory analysts) → re-entry on ITERATE verdict, cap 3. Accepts either do-plan output or do-consult recommendation.

Key differences from do-execute: no test/doc content gates (prototype context), depth classification (focused/standard), ITERATE/ACCEPT verdict (not PASS/BLOCK with failure_class branching), prototype completion assessment (question answered: yes/partially/no).

### do (orchestrator)

Redirect model — suggests next phase skill, tracks state in session-log.md. Not subagent dispatch (do-analyze is interactive). Skip validation: problem clear → skip analyze, direction clear → skip consult. Human gate after every phase.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 4 separate skills | Yes | Mirrors proven do-discuss/do-plan/do-execute chain; independent invocation |
| New @consultant agent | Yes | @planner preloads do-plan via `skills: [do-plan]`; pollution is structural (E2) |
| Lean review (no analysts) | Yes | Analysts produce advisory-only findings; prototype review needs correctness |
| Cap 3 (not 5) | Yes | Cost-bounded for prototype context; two-way door |
| EARS in analysis_artifact | Yes | Boundary-stable across agent hand-offs; prevents paraphrasing degradation (E2: spec-mode precedent) |
| Cross-skill refs (not copies) | Yes | Single source of truth; E3-verified path resolution; consumer headers for coupling trace |
| Staged build loop | Yes | Simple re-entry first; episodic memory + stagnation detection deferred to Stage 2 |
| No Two-Way Door assessment | Yes | Everything is reversible in git |

## What's Preserved from the Old Flow

- **Socratic dialogue** — do-analyze keeps orient/clarify/investigate from do-discuss
- **Multi-model perspectives** — do-consult dispatches consultants + envoy like do-plan's planning phase
- **Challenge/debate value** — redistributed: 30% (spec validation) → consult falsification bullets + disagreement-as-signal; 70% (implementation validation) → do-build review
- **Evidence gating** — E2+ for blocking, E3 for verification
- **Variance lenses** — selected at do-consult intake, inherited by do-build
- **Session conventions** — same session ID, session-log, .scratch directory patterns
- **Cross-provider envoy** — in every phase that benefits from diverse perspectives

## What's Removed

- **5-phase planning cycle** (discovery → framing → planning → challenge → synthesis) → compressed to single batch + synthesis
- **Advisory analysts** in review → prototype doesn't need polish
- **Test/doc content gates** → prototype context; surfaced as learnings, not blockers
- **Readiness declaration + iterations** → replaced by user decision gate
- **Explore + frame phases** → HOW territory; removed by design
- **Semantic/non-semantic re-entry branching** → single ITERATE path with cap 3
- **30-minute planning sessions** → 5-minute consult + build

## Coexistence

The new skills coexist with do-discuss, do-plan, do-execute. Users choose which flow to use. Deprecation happens after the new flow is proven:

1. do-analyze proven → deprecate do-discuss (or rename do-analyze to do-discuss)
2. do-consult proven → deprecate do-plan
3. do-build proven → deprecate do-execute

## Follow-ups

- Stage 2: episodic memory + stagnation detection for do-build loop
- @navigator depth knob for do-consult deep mode
- Naming: `do-{analyze,consult,build}` may become `do-{what,how,it}` or revert to `do-{discuss,plan,execute}`
- Skill evals for trigger accuracy and quality comparison
