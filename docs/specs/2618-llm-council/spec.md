---
spec: 2618-llm-council
title: LLM Council — Sequential Advisory with Peer Review
status: framed
session: llm-council-frame-7c4e
updated: 2026-04-29
---

# LLM Council

## Problem Statement

The do-flow's only multi-perspective advisory mechanism is run-advise: 4 functional agents,
generic synthesizer, no cross-critique. For high-stakes design decisions, there is no way
to trigger structured adversarial stress-testing — the peer-review dynamic (advisors
critiquing each other anonymously) and thinking-lens diversity (Contrarian, First Principles,
Expansionist, Outsider, Executor) that the LLM Council pattern provides. The result is that
run-advise can surface divergence but cannot expose what all perspectives collectively missed,
and produces no directional recommendation under genuine conflict.

## Constraints

| Type | Description | Source | Evidence |
|------|-------------|--------|----------|
| hard | run-advise is mandatory at do-design Phase 2 and must continue to run — Council sequences after it, not instead of it | codebase | E2 |
| hard | Council does not belong in do-frame — framing is WHAT-only; adversarial critique of options is design-domain | user | E1 |
| hard | do-build stuckness advisory stays separate — Council is a design-phase skill, not a recovery mechanism | codebase | E2 |
| soft | Council's thinking-lens roster (5 advisors) must remain independent of run-advise's functional roster — no merging | user | E1 |
| assumed | run-advise synthesis output is structurally usable as enriched context for Council advisors without reformatting | inferred | E0 |

## Blast Radius

**Direct:**
- `skills/do-design/SKILL.md` — Phase 2 extended to invoke Council after run-advise
- `skills/run-council/` — new skill directory (SKILL.md + references/)

**Transitive:**
- `skills/run-advise/` — synthesis artifact becomes Council input; output schema may need a handoff contract
- `agents/` — 5 new thinking-lens agent files (or lens prompting in skill)
- `docs/skills-reference.md` — new skill entry

## Key Assumptions

| Assumption | Status | Evidence |
|-----------|--------|----------|
| run-advise output can serve as enriched context for Council advisors in sequential-B execution | settled | E1 |
| Council is a separate skill (run-council), not a wrapper or replacement for run-advise | settled | E1 |
| Thinking-lens roles and run-advise functional roles are complementary — no overlap that warrants collapsing | settled | E1 |
| do-design Phase 2 is the exclusive integration point — run-advise has one call site today | settled | E2 |

## Success Criteria

- **When** do-design Phase 2 runs, run-advise completes first and its synthesis artifact is passed as context to Council advisors.
- **When** Council advisors run, each responds independently from its assigned thinking lens using run-advise output as pre-enriched context.
- **When** the Council peer-review phase completes, each advisor has reviewed all 5 responses anonymously and identified blind spots.
- **When** Chairman synthesis completes, the output includes: convergence zones, genuine disagreements, collective blind spots, and a single directional recommendation.
- **When** do-design Phase 2 completes, both run-advise artifact and Council artifact are available to the design-recommendation phase.

## Key Unknowns (Deferred to Design)

| Unknown | Impact | Feasibility Note |
|---------|--------|-----------------|
| Model tier for Council advisors and Chairman (Standard vs Frontier, uniform vs mixed) | informational | Envoy supports frontier/standard/fast tiers per provider; tier selection affects cost and latency but not the sequential-B integration pattern. |
| Whether thinking-lens advisors are implemented as envoy dispatches (cross-provider diversity) or same-provider agents with lens system prompts | informational | Both patterns exist in the codebase; envoy provides provider diversity, same-provider agents are simpler to author. Trade-off is design-domain. |
