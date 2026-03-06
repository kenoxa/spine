---
name: do-plan
description: >
  Structured planning before complex implementation.
  Use when the task is open-ended, has architectural implications, or requires
  coordinating multiple workstreams. Do NOT use for single-file edits or
  straightforward bug fixes.
argument-hint: "[task description]"
---

Produce a self-sufficient, executable implementation plan through five phases:
discovery → framing → planning → challenge → synthesis.

If requirements are unclear or the solution space is wide open, run `brainstorming` first
to explore alternatives and get user sign-off on direction before entering discovery.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context explicitly.

### 1. Discovery

Map the codebase before planning. Subagent scope:

- **File scouting**: entry points, call graph, tests, config flags, change surface
- **Docs exploration**: intended behavior, spec bullets, ambiguities
- **External research**: upstream breaking changes, API gotchas, compatibility (when touching external dependencies)

Output: `discovery_findings` — all claims tagged with evidence level (see [Evidence Levels](#evidence-levels)).

### 2. Framing

Distill `discovery_findings` into a `planning_brief` all planners share. Fields:

| Field | Content |
|-------|---------|
| `goal` | One-sentence task restatement, disambiguated by discovery |
| `scope` | Confirmed in/out with change surface |
| `constraints` | Hard limits (performance, security, backwards compat, API surface) |
| `key_decisions` | Numbered IDs, A/B/C options, explicit tradeoffs |
| `planner_focus_cues` | E2 pointers to entry points, patterns, tests — no narrative |
| `evidence_manifest` | Artifact paths with why-relevant; planners lazy-load from here |

No raw dumps — distilled signals only.

Apply the Two-Way Door test to each `key_decision`: reversible decisions get a fast path;
one-way doors (rewrites, migrations, vendor lock-in) require exhaustive analysis. Evaluate
options on: correctness risk, operational complexity, team familiarity, migration cost, blast
radius. Limit to 2–3 options — never present 4+ without narrowing first.

Ask before dispatching planners if any `key_decisions` would materially change scope or risk.
Present context + options first, then prompt the user with short structured questions.

### 3. Planning

Dispatch planners with `planning_brief` + `evidence_manifest` in every prompt.
For multi-planner runs, assign distinct approach angles to avoid duplicate plans:

- `conservative`: minimize surface area, prefer existing patterns
- `thorough`: full coverage, explicit edge/failure enumeration
- `innovative`: structural improvements if scope allows

Merge parallel outputs via consensus: deduplicate by meaning; rank E3 > E2 > E1 > E0;
conflicting E2+ claims on blocking topics → targeted verification pass aiming for E3.

### 4. Challenge

Adversarial review of `canonical_plan`. Blocking findings MUST be E2+; E0-only blocking claims are advisory.

Challenge methodology: expose hidden assumptions, underestimated risks, and uncomfortable truths.
Ask: "Why must it be this way?" "What if that assumption is wrong?" "What are you avoiding?"
Flag over-engineering, under-engineering, and unnecessary abstraction. A blocking finding
requires a better alternative that is project-documented, industry-standard, or demonstrably
lower risk — never block without one.

Useful review lenses: approach correctness (`assumptions`) and non-functional risks (`nfr`: security, perf, scalability).
For visual architecture explanations, use the `visual-explainer` skill.
If blocking findings remain unresolved after asking, dispatch a structured debate
(thesis-champion, counterpoint-dissenter, tradeoff-analyst) before synthesis.

### 5. Synthesis

Main thread only. Sole readiness authority. No subagent dispatch.

1. Assemble final plan using [references/plan-template.md](references/plan-template.md) as scaffold.
2. Validate all content requirements (see [Plan Requirements](#plan-requirements)).
3. Confirm every blocking finding is incorporated or rejected with explicit rationale.
4. Confirm no open ask-checkpoint decisions without user-deferred evidence.
5. Emit readiness decision.

`semantic` gaps (missing test tasks, unresolved blocking findings, self-sufficiency failure) → re-run from framing.
`non_semantic` gaps (format, evidence shape) → fix inline.

## Evidence Levels

See AGENTS.md for E0–E3 definitions. Blocking claims MUST be E2+.

## Ask Policy

Ask whenever ambiguity materially affects scope, risk, or approach. Two pressure points:

- After discovery, before framing: blocking unknowns that would misdirect planning
- After challenge, before synthesis: contentious findings that remain unresolved

Never carry unresolved decisions silently into synthesis.

## Plan Requirements

Synthesis cannot declare readiness unless the plan includes:

- **Self-sufficiency**: executable without chat history; repo-relative paths; defined terms; decision rationale
- **Test tasks**: explicit for behavior-changing work
- **Edge/failure coverage**: enumeration for low risk; perspective table for medium/high risk
- **Docs tasks**: explicit for user-visible/API/config changes
- **Completion criteria**: testable acceptance conditions

See [references/plan-template.md](references/plan-template.md) for required sections and scaffold.

## Readiness Declaration

- `Plan is ready for execution.`
- `Plan is NOT ready for execution` — followed by specific gaps listed.

## Iteration Cap

5 iterations per request. A reroute from framing through synthesis = one iteration.
On cap: freeze best plan snapshot and request explicit user approval to continue.

## Anti-Patterns

- Skipping challenge for complex scope
- Carrying E0-only objections as blocking findings into synthesis
- Declaring readiness when self-sufficiency contract is unmet
- Silently carrying unresolved `key_decisions` past the ask checkpoint
