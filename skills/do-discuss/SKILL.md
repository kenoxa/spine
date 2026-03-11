---
name: do-discuss
description: >
  Structured problem framing through Socratic dialogue before planning.
  Use when: vague/ambiguous problems, symptom/feeling/situation descriptions,
  "I'm not sure what the actual problem is", "help me think through this",
  "what should I consider", "this keeps happening but I don't know why".
  Also trigger on: "grill me", "challenge my assumptions", "poke holes",
  plan/design for stress-testing, upstream handoffs (brainstorming selected
  direction, run-debug root cause with architectural scope).
  Do NOT use when: requirements are plan-ready (do-plan), reproducible defect (run-debug),
  creative ideation without a problem (brainstorming).
argument-hint: "[problem description, symptom, or situation]"
---

Frame the actual problem through tiered Socratic dialogue: intake → clarify → investigate → explore → frame → handoff. Investigate and explore are conditional (tier escalation only).

## Tiered Interaction Model

| Tier | Mode | Trigger | Agents |
|------|------|---------|--------|
| 1 | Socratic dialogue (main thread) | Always starts here | None |
| 2 | Codebase-assisted | Codebase-dependent unknown blocks framing AND user cannot answer | `@scout` or `@researcher` |
| 3 | Multi-perspective exploration | Ambiguous scope + 2+ one-way-door decisions after clarify + investigate | `@framer` team |

## Phases

| Phase | Agent type |
|-------|-----------|
| Investigate | `@scout` / `@researcher` |
| Explore | `@framer` |

**Session ID**: Per SPINE.md convention. Carry into do-plan. Append to session log at phase boundaries and tier escalations. `<session>` placeholder below.

### 1. Intake

Accept raw input, classify, redirect if wrong tool.

| Input shape | Action |
|-------------|--------|
| Has tasks, criteria, scope → plan-ready | Redirect to `do-plan` |
| Reproducible defect with steps | Redirect to `run-debug` |
| Pure ideation without a problem | Redirect to `brainstorming` |
| < 1 sentence of problem context | Ask grounding question: "What situation are you trying to change?" |
| Vague, ambiguous, or symptom-based | Proceed to clarify |
| Plan/design for stress-testing, "grill me", "challenge my assumptions", "poke holes" | Proceed to clarify with deep-interview mode |

Detect upstream handoff: `brainstorming` (selected direction) or `run-debug` (root cause, scope exceeds fix). Seed known inventory from upstream.

### 2. Clarify

Socratic dialogue. Main thread only (tier 1). No subagents.

Derive the **frame question** — single question whose answer unblocks planning. Specific (names affected system/behavior), answerable (finite answers), scoped (enables planning). Example: "Is the auth retry failure a client-side timeout or a server-side rate limit?"

- Ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**
- Batch 2-4 independent questions per round; sequential dependents one at a time
- Track `known` / `unknown` inventory; 3-round budget
- After each round: update inventory, check frame question answerability

**Deep interview**: activate when user says "grill me", "challenge my assumptions", "poke holes", or provides a plan/design for stress-testing. Increase round budget from 3 to 5. Challenge stated requirements — push back on "obvious" answers. Actively probe for unstated assumptions and implicit constraints. Same output (frame artifact) — deeper interrogation path.

Escalation to tier 2: codebase-dependent unknown blocks framing AND user cannot answer from domain knowledge ("check the code", "I don't know how it works").

### 3. Investigate (conditional, tier 2)

Subagent dispatch for codebase evidence.

| Agent | Use when | Output |
|-------|----------|--------|
| `@scout` | Orientation: "does X exist? where? what shape?" | `.scratch/<session>/discuss-investigate-scout.md` |
| `@researcher` | Depth: "how does X work? what are the side effects?" | `.scratch/<session>/discuss-investigate-researcher.md` |

Dispatch context: specific unknowns from inventory, current `known`/`unknown` state, why user could not answer (domain vs. codebase gap).

Before dispatch: select 1 lens from `do-plan/references/variance-lenses.md` — match `unknown` inventory against lens trigger column, log selection reasoning (2-3 sentences). Dispatch one augmented `@researcher` with the lens focus directive. Max 3 concurrent (1-2 base + 1 augmented). Max 2 rounds. Synthesize into `codebase_signals`, return to clarify.

Escalation to tier 3: ambiguous scope AND `key_decisions` has 2+ one-way-door options after investigation.

### 4. Explore (conditional, tier 3)

Team `discuss-explore` — three `@framer` personas for one-way-door decisions resisting convergence:

| Role | Output |
|------|--------|
| `stakeholder-advocate` | `.scratch/<session>/discuss-explore-stakeholder-advocate.md` |
| `systems-thinker` | `.scratch/<session>/discuss-explore-systems-thinker.md` |
| `skeptic` | `.scratch/<session>/discuss-explore-skeptic.md` |

Dispatch context: current `problem_frame` (in-progress), full `known`/`unknown` inventory, assigned perspective, all three output paths.

Dispatch all three in parallel → wait → re-invoke each to read peers and append `## Peer Reactions` → synthesize. Irreconcilable positions become `key_decisions`.

Dispatch one additional `@framer` with the variance lens from investigate (or select lens per variance-lenses.md if investigate was skipped). Output: `.scratch/<session>/discuss-explore-augmented-{lens}.md`. Included in peer reaction round. Max 4 total framers.

### 5. Frame

Main thread only. Write `problem_frame` artifact to `.scratch/<session>/discuss-frame.md` using [references/frame-template.md](references/frame-template.md).

Frame must be self-sufficient: understandable without chat history, all terms defined, no conversation references.

### 6. Handoff

Main thread only. Sole handoff authority. Confidence-gated recommendation:

| Confidence | Declaration |
|------------|-------------|
| `high` | "Discussion complete. Proceed with `/do-plan`." |
| `medium` | "Complete with open assumptions. Proceed with `/do-plan` or resolve assumptions first." |
| `low` | "Needs further exploration. Consider `/brainstorming` to clarify direction." |

Emit `discussion_learnings` proposals (never auto-applied). STOP. User decides next step.

## Skill Relationships

```
do-discuss → do-plan → do-execute  (frame → plan → build)
brainstorming → do-plan             (ideate → plan)
do-discuss → brainstorming          (low confidence → ideation)
run-debug → do-discuss               (root cause → architectural scope)
```

## Ask Policy

- During clarify: when user's answer reveals problem is substantially different from initial description
- Before handoff: when blocking unknowns remain that only the user can resolve
- Never carry unresolved blocking unknowns silently into the frame artifact

## Termination Conditions

| Condition | Outcome |
|-----------|---------|
| Frame question answered + blocking unknowns resolved | `complete` |
| User says "just plan it" + unknowns acknowledged | `complete` with accepted risk |
| 5 iteration cap (clarify-through-frame pass) | Freeze best state, surface gaps |
| Input classified as wrong tool | Redirect, no artifact |

## Anti-Patterns

- Asking leading questions that embed solutions
- Framing as solution choice ("should we use Redis?") instead of diagnostic ("is the bottleneck in storage or retrieval?")
- Dispatching tier-2 agents for questions answerable by the user
- Dispatching tier-3 team for simple problems with clear scope
