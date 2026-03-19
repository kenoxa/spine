# Clarify Phase

Convergence-driven interview. Main thread only — user interaction loop. Proactive subagent dispatches for factual questions.

Relentless interview until shared understanding. Resolve decision dependencies one-by-one. Challenge stated requirements, probe assumptions, push back on "obvious" answers.

Seed `known` from `codebase_signals` when non-empty. Seed `external_signals` from navigator. Do not re-ask already-answered questions.

## Question Taxonomy

Before asking the user, classify each question:

| Question type | Action |
|---|---|
| Factual/codebase ("does X exist?", "how does Y work?") | Dispatch `@scout` + `run-explore/references/explore-scout.md` proactively. Do not ask user. |
| Factual/external ("how does library Z handle this?") | Dispatch `@navigator` + `run-explore/references/explore-navigator.md` proactively. Do not ask user. |
| Preferential/business ("which approach do you prefer?", "what are the business constraints?") | Ask user with recommended answer. |
| Mixed (technical + business constraints) | Explore technical constraints via dispatch; ask user for business constraints. |

**Proactive @scout assists**: output `.scratch/<session>/discuss-clarify-assist-<N>.md` (sequential counter). Track dispatched references.

**Proactive @navigator assists**: output `.scratch/<session>/discuss-clarify-nav-<N>.md` (sequential counter). Append to `external_signals`.

## Recommended Answers

Every question includes a labeled recommendation with rationale. For one-way-door decisions, surface alternatives alongside.

## Convergence

Interview continues until: all `key_decisions` resolved or deferred AND `frame_question` answerable. User override: "just plan it" or equivalent signals early exit.

**Stall detection**: 3 exchanges (one user turn + one assistant turn; proactive dispatches don't count) with no `key_decisions` status changes across any item. Resets globally on any status change. On stall: surface remaining gaps, recommend next step.

**Frame question**: single question unblocking planning. Specific (names system/behavior), answerable (finite options), scoped (enables planning).

Ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**. Batch 2-4 independent questions per exchange; sequential dependents one at a time. Track `known`/`unknown`; check convergence after each exchange.

Blocking unknowns requiring codebase depth — behavior, side effects, data flow — beyond scout orient or proactive assists signal readiness for investigate phase.

> Anti-patterns: (1) Leading questions embedding solutions. (2) Solution-choice framing instead of diagnostic. (3) Asking user factual questions answerable by codebase/internet exploration.
