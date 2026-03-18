# Clarify Phase

Socratic dialogue. Main thread only — user interaction loop. Subagent dispatches between rounds only.

Challenge stated requirements, probe assumptions, actively push back on "obvious" answers. This is the default style for all discussions.

Seed `known` from `codebase_signals` when non-empty. Seed `external_signals` from navigator. Do not re-ask already-answered questions.

**Between-round @scout assists**: user introduces named codebase reference not covered → dispatch `@scout` + [orient-scout.md](orient-scout.md). Output: `.scratch/<session>/discuss-clarify-assist-<round>.md`. Track dispatched references.

**Between-round @navigator assists**: user introduces library/dependency not covered → dispatch `@navigator` + [navigator-synthesis.md](navigator-synthesis.md). Output: `.scratch/<session>/discuss-clarify-nav-<round>.md`. Append to `external_signals`.

**Between-round scope escalation**: 2-of-3 threshold met → escalate to spec-creation. Carry all state. See [orchestrate-spec-creation.md](orchestrate-spec-creation.md).

**Round budget**: base 5. orient Answer non-empty → -1. `external_signals` non-empty → -1. Minimum 3.

**Frame question**: single question unblocking planning. Specific (names system/behavior), answerable (finite options), scoped (enables planning).

Ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**. Batch 2-4 independent questions per round; sequential dependents one at a time. Track `known`/`unknown`; check frame question answerability after each round.

Escalation to tier 2: blocking unknown requires depth — behavior, side effects, data flow — beyond scout orient or clarify-assists.

> Anti-patterns: (1) Leading questions embedding solutions. (2) Solution-choice framing instead of diagnostic. (3) Tier-2 dispatch for user-answerable questions. (4) Agent dispatch during clarify (between-round assists are the only exception).
