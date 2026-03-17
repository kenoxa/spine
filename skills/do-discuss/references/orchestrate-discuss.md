# Discuss Orchestration

Core phase execution for do-discuss: orient → clarify → investigate → explore → frame.

## State Protocol

| Variable | Lifecycle | Mutation Rule |
|----------|-----------|---------------|
| `codebase_signals` | create: orient; append: investigate | append-only |
| `external_signals` | create: orient/research-override; append: clarify-nav, investigate | append-only |
| `known` / `unknown` | create: orient/clarify-start; mutate: clarify, investigate | mutable — items move between them |
| `key_decisions` | create: clarify; accumulate: investigate, explore | accumulate-only |
| `frame_question` | derive: clarify | immutable after derivation |
| `round_budget` | set: clarify entry; reduce: orient/external findings | conditional reduction, hard minimum 2 |
| `mode` | set: entry (normal \| deep-interview) | immutable |

## Deep-Interview Overrides

When `mode = deep-interview`, these override defaults. Phases reference this table.

| Parameter | Normal | Deep-Interview |
|-----------|--------|----------------|
| `round_budget` | 3 | 5 |
| Clarify style | diagnostic questioning | challenge stated requirements, probe assumptions |
| Push-back level | standard | actively push back on "obvious" answers |

## Orient (conditional — codebase-adjacent input only)

Dispatch `@scout` + [orient-scout.md](orient-scout.md) + `@navigator` for breadth-first codebase context before Socratic dialogue. Clarify's no-subagent constraint does not apply here.

**Codebase-adjacency classification** (run at end of intake, after redirect check):

| Signal | Classification |
|--------|---------------|
| Upstream handoff (brainstorming or run-debug) | Codebase-adjacent — always orient |
| Names file, module, function, or component | Codebase-adjacent |
| Contains inline code block | Codebase-adjacent |
| Diagnostic language + named component | Codebase-adjacent (soft) |
| Diagnostic language only, no named component | Grounding question first; re-classify after |
| Design/architectural framing without operational context | Not codebase-adjacent — skip orient |
| Input < 1 sentence, grounding question not yet asked | Defer until after grounding response |
| Pure process/organizational/domain question | Not codebase-adjacent — skip orient |

**When codebase-adjacent**:
1. `@scout` + [orient-scout.md](orient-scout.md): intake signals as seed. Output: `.scratch/<session>/discuss-orient.md`
1b. `@navigator` + [navigator-synthesis.md](navigator-synthesis.md) parallel with scout. `seed_terms` from intake. Output: `.scratch/<session>/discuss-orient-external.md`
2. Artifacts must contain: Answer, File map, Gaps (note potential lens signals), External signals table
3. Session log: phase boundary, scout dispatched, 1-sentence summary. Carry `codebase_signals` + `external_signals` into clarify.

**When NOT codebase-adjacent**: skip to clarify. `codebase_signals = []`, `external_signals = []` unless research override triggers.

**External research override** (orient skipped, library names present):

| Signal | Action |
|--------|--------|
| Names library, framework, package, SDK | Dispatch `@navigator` standalone |
| References version constraint, API, "upstream" | Dispatch `@navigator` (soft) |
| No library/framework names | Skip — `external_signals = []` |
| Ambiguous | Dispatch — handles no-library gracefully |

When triggered: `@navigator` + [navigator-synthesis.md](navigator-synthesis.md) with `seed_terms`, `codebase_signals = []`. Output: `.scratch/<session>/discuss-orient-external.md`. Carry `external_signals` into clarify.

**Failure**: scout/navigator returns empty → signals = `[]`, note in Gaps, proceed. Re-run adjacency classification after grounding response if deferred.

Orient does NOT: select variance lenses (Investigate phase), ask user questions, block clarify, run in deep-interview mode.

> Anti-patterns: (1) Full @researcher at orient — orient = breadth with scout + navigator. (2) Asking user about codebase facts orient could answer. (3) Running orient on pure-domain problems.

## Clarify

Socratic dialogue. Main thread only — user interaction loop. Subagent dispatches between rounds only.

Seed `known` from `codebase_signals` when non-empty. Seed `external_signals` from navigator. Do not re-ask already-answered questions.

**Between-round @scout assists**: user introduces named codebase reference not covered → dispatch `@scout` + [orient-scout.md](orient-scout.md). Output: `.scratch/<session>/discuss-clarify-assist-<round>.md`. Track dispatched references.

**Between-round @navigator assists**: user introduces library/dependency not covered → dispatch `@navigator` + [navigator-synthesis.md](navigator-synthesis.md). Output: `.scratch/<session>/discuss-clarify-nav-<round>.md`. Append to `external_signals`.

**Between-round scope escalation**: 2-of-3 threshold met → escalate to spec-creation. Carry all state. See [orchestrate-spec-creation.md](orchestrate-spec-creation.md).

**Round budget**: orient Answer non-empty → -1. `external_signals` non-empty → -1. Minimum 2. Deep-interview minimum 4. See overrides table.

**Frame question**: single question unblocking planning. Specific (names system/behavior), answerable (finite options), scoped (enables planning).

Ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**. Batch 2-4 independent questions per round; sequential dependents one at a time. Track `known`/`unknown`; check frame question answerability after each round.

**Deep interview**: see overrides table for budget + style changes.

Escalation to tier 2: blocking unknown requires depth — behavior, side effects, data flow — beyond scout orient or clarify-assists.

> Anti-patterns: (1) Leading questions embedding solutions. (2) Solution-choice framing instead of diagnostic. (3) Tier-2 dispatch for user-answerable questions. (4) Agent dispatch during clarify (between-round assists are the only exception).

## Investigate (conditional, tier 2)

Subagent dispatch for codebase evidence.

| Agent | Reference | Use when | Output |
|-------|-----------|----------|--------|
| `@scout` | [orient-scout.md](orient-scout.md) | Orientation: "does X exist? where?" | `.scratch/<session>/discuss-investigate-scout.md` |
| `@researcher` | — | Depth: "how does X work? side effects?" | `.scratch/<session>/discuss-investigate-researcher.md` |
| `@navigator` | [navigator-synthesis.md](navigator-synthesis.md) | External: "ecosystem says what about X?" | `.scratch/<session>/discuss-investigate-navigator.md` |

Dispatch context: specific unknowns, `known`/`unknown` state, why user couldn't answer. Navigator: external library behavior, API compatibility — not codebase depth. Targeted queries, not broad sweep. Duplication prevention: check orient + clarify-assist outputs first. File presence in File map narrows query; only explicit Answer resolution omits dispatch.

Before dispatch: select 1 lens from `do-plan/references/variance-lenses.md` — match unknowns against trigger column, log reasoning (2-3 sentences). One augmented `@researcher` with lens. Max 3 concurrent (1-2 base + 1 augmented). Max 2 rounds. Synthesize into `codebase_signals`; merge navigator into `external_signals` (append, not overwrite).

Escalation to tier 3: ambiguous scope AND `key_decisions` has 2+ one-way-door options after investigation.

> Anti-patterns: (1) Tier-2 for unknowns already answered by orient. (2) Navigator for codebase-depth questions (@researcher's job).

## Explore (conditional, tier 3)

Three `@framer` personas for one-way-door decisions resisting convergence:

| Role | Reference | Output |
|------|-----------|--------|
| `stakeholder-advocate` | [explore-stakeholder-advocate.md](explore-stakeholder-advocate.md) | `.scratch/<session>/discuss-explore-stakeholder-advocate.md` |
| `systems-thinker` | [explore-systems-thinker.md](explore-systems-thinker.md) | `.scratch/<session>/discuss-explore-systems-thinker.md` |
| `skeptic` | [explore-skeptic.md](explore-skeptic.md) | `.scratch/<session>/discuss-explore-skeptic.md` |

`@navigator` + [navigator-alternatives.md](navigator-alternatives.md) parallel with framers. Output: `.scratch/<session>/discuss-explore-navigator.md`.

All three parallel → wait → re-invoke each to read peers + append `## Peer Reactions` → synthesize. Include navigator in peer-reaction. Irreconcilable positions → `key_decisions`. Augmented `@framer` + [explore-augmented-framer.md](explore-augmented-framer.md) with variance lens from investigate (or select per `do-plan/references/variance-lenses.md`). Output: `.scratch/<session>/discuss-explore-augmented-{lens}.md`. Included in peer reaction.

**Envoy**: load `use-envoy`. Dispatch concurrent with base framers. Excluded from peer-reaction — feeds Frame phase only. Prompt: `problem_frame` + `known`/`unknown` + `key_decisions` + `codebase_signals` + `external_signals` (self-contained). Output: `.scratch/<session>/discuss-explore-envoy.md`. Variant: `standard`.

Cap: base framers (3) + navigator (1) + envoy (1) + augmented <= 6.

> Anti-patterns: (1) Tier-3 team for simple problems. (2) Re-dispatching navigator for already-covered dependency.

## Frame

Concurrent dispatch: 2 `@framer` agents + `@envoy`, then sequential `@synthesizer`.

**Concurrent** (3 agents):
- `@framer` + [frame-evidence-mapper.md](frame-evidence-mapper.md) → `.scratch/<session>/discuss-frame-evidence-mapper.md`
- `@framer` + [frame-dialogue-tracker.md](frame-dialogue-tracker.md) → `.scratch/<session>/discuss-frame-dialogue-tracker.md`
- Load `use-envoy`. `@envoy` (advisory-only): prompt = problem framing + final inventory + `key_decisions` + explore summary + signals (self-contained) → `.scratch/<session>/discuss-frame-envoy.md`

**Then sequential** (1 agent):
- `@synthesizer` + [frame-synthesis.md](frame-synthesis.md): all frame outputs + session state + explore envoy if exists → `.scratch/<session>/brief.md` per [template-brief.md](template-brief.md).

Main thread validates self-sufficiency contract: understandable without chat history, terms defined, no conversation references, evidence levels present. Re-dispatch on failure with gap list. Cap: framers (2) + envoy (1) + synthesizer (1) <= 4.

> Anti-pattern: Fire-and-forward navigator with no `external_signals` handoff.
