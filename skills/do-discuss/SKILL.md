---
name: do-discuss
description: >
  Structured problem framing before planning through Socratic dialogue.
  Use when the problem is vague, ambiguous, or too broad for direct planning.
  Also trigger when the user describes symptoms, feelings, or situations
  rather than concrete requirements — phrases like "I'm not sure what the
  actual problem is", "help me think through this", "what should I consider",
  or "this keeps happening but I don't know why". Also trigger on upstream
  handoffs: when brainstorming produces a selected direction that needs
  framing, or when do-debug reveals root causes with architectural scope.
  Do NOT use when requirements are already plan-ready (go directly to do-plan),
  when the user reports a reproducible defect (use do-debug), or for creative
  ideation without a specific problem (use brainstorming).
argument-hint: "[problem description, symptom, or situation]"
---

Frame the actual problem through tiered Socratic dialogue before planning:
intake → clarify → investigate → explore → frame → handoff.

Investigate and explore are conditional — triggered by tier escalation, not always run.

## Tiered Interaction Model

| Tier | Mode | Trigger | Agents |
|------|------|---------|--------|
| 1 | Socratic dialogue (main thread) | Always starts here | None |
| 2 | Codebase-assisted | Codebase-dependent unknown blocks framing AND user cannot answer | `@scout` or `@researcher` |
| 3 | Multi-perspective exploration | Ambiguous scope + 2+ one-way-door decisions after clarify + investigate | `@framer` team |

## Phases

**Subagent dispatch policy**: Each role uses its specialized agent type. Every dispatch prompt MUST include:
- The exact output file path (`.scratch/<session>/<prescribed-filename>.md`)
- The constraint: "Write your complete output to that path. You may read any repository file. Do NOT edit, create, or delete files outside `.scratch/<session>/`. Do NOT run build commands, tests, or destructive shell commands."

| Phase | Agent type | Rationale |
|-------|-----------|-----------|
| Investigate | `@scout` / `@researcher` | Breadth-first orientation or deep evidence gathering |
| Explore | `@framer` | Perspective-committed, advisory, peer-reactive |

**Session ID**: generate once at phase entry using `{YYWW}-{slug}-{hash}` (e.g., `2610-auth-scope-b7c1`). `YYWW` is two-digit year + zero-padded ISO week. `slug` is 3-5 words derived from the initial user prompt (lowercase, hyphen-separated, alphanumeric only). `hash` is a 4-character random hex. Reuse across all phases — and carry forward into do-plan if user proceeds. All output paths below use `<session>` as placeholder.

### 1. Intake

Accept raw input, classify, redirect if wrong tool.

| Input shape | Action |
|-------------|--------|
| Has tasks, criteria, scope → plan-ready | Redirect to `do-plan` |
| Reproducible defect with steps | Redirect to `do-debug` |
| Pure ideation without a problem | Redirect to `brainstorming` |
| < 1 sentence of problem context | Ask grounding question: "What situation are you trying to change?" |
| Vague, ambiguous, or symptom-based | Proceed to clarify |

Detect upstream handoff context: `brainstorming` (selected direction) or `do-debug` (root cause confirmed, scope exceeds bug fix). When present, seed the known inventory from the upstream artifact.

### 2. Clarify

Socratic dialogue. Main thread only (tier 1). No subagent dispatch.

Derive the **frame question** — the single question whose answer unblocks planning. A good frame question is specific (names the affected system or behavior), answerable (finite set of possible answers), and scoped (answering it directly enables planning). Example: "Is the auth retry failure a client-side timeout or a server-side rate limit?"

- Identify ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**
- Batch 2-4 contextually independent questions per round
- Ask sequentially dependent questions one at a time
- Track `known` / `unknown` inventory across rounds
- 3-round budget
- After each round: update inventory, check if frame question is answerable

Escalation trigger to tier 2: a codebase-dependent unknown blocks framing AND the user says "check the code" / "I don't know how it works" / cannot answer from domain knowledge.

### 3. Investigate (conditional, tier 2)

Subagent dispatch for codebase evidence when user cannot resolve unknowns.

| Agent | Use when | Output |
|-------|----------|--------|
| `@scout` | Orientation: "does X exist? where? what shape?" | `.scratch/<session>/discuss-investigate-scout.md` |
| `@researcher` | Depth: "how does X work? what are the side effects?" | `.scratch/<session>/discuss-investigate-researcher.md` |

**Dispatch context** (include in every investigate prompt):
- The specific unknown(s) to resolve (from the `unknown` inventory)
- Current `known` / `unknown` inventory state
- Why the user could not answer (domain gap vs. codebase gap)

- Max 2 dispatch rounds, max 2 concurrent agents per round
- Main thread synthesizes dispatch outputs into `codebase_signals`
- After synthesis: return to clarify to re-check if the frame question is now answerable

Escalation trigger to tier 3: ambiguous scope AND `key_decisions` has 2+ one-way-door options after investigation.

### 4. Explore (conditional, tier 3)

Multi-perspective agent team when one-way-door decisions resist convergence.

- Team name: `discuss-explore`
- Three `@framer` personas:

| Role | Output |
|------|--------|
| `stakeholder-advocate` | `.scratch/<session>/discuss-explore-stakeholder-advocate.md` |
| `systems-thinker` | `.scratch/<session>/discuss-explore-systems-thinker.md` |
| `skeptic` | `.scratch/<session>/discuss-explore-skeptic.md` |

**Dispatch context** (include in every framer prompt):
- Current `problem_frame` state (in-progress)
- Full `known` / `unknown` inventory
- Assigned perspective name
- All three output paths (so the framer can read peer outputs)

**Sequencing**: dispatch all three in parallel → wait for completion → re-invoke each framer to read peer outputs and append a `## Peer Reactions` section → main thread synthesizes. Irreconcilable positions become `key_decisions` in the frame.

### 5. Frame

Main thread only. Produce `problem_frame` artifact.

Write structured artifact to `.scratch/<session>/discuss-frame.md` using the template from [references/frame-template.md](references/frame-template.md).

The frame must be self-sufficient: understandable without chat history, all terms defined, no conversation references.

### 6. Handoff

Main thread only. Sole handoff authority.

Emit confidence-gated recommendation.

| Confidence | Declaration |
|------------|-------------|
| `high` | "Discussion complete. Proceed with `/do-plan`." |
| `medium` | "Discussion complete with open assumptions. Proceed with `/do-plan` or resolve assumptions first." |
| `low` | "Problem needs further exploration. Consider `/brainstorming` to clarify direction." |

Emit `discussion_learnings` proposals (never auto-applied). STOP. Do not invoke do-plan automatically. User decides next step.

## Relationship to Adjacent Skills

```
do-discuss -> do-plan -> do-execute    (frame -> plan -> build)
brainstorming -> do-plan               (ideate -> plan)
do-discuss -> brainstorming            (when confidence is low, discuss recommends ideation)
do-debug -> do-discuss                 (when root cause reveals architectural scope)
```

- **do-discuss**: "What is the actual problem?" (convergent, diagnostic)
- **brainstorming**: "What should we build?" (divergent, creative)

## Ask Policy

Ask whenever ambiguity materially affects the frame question. Two pressure points:

- During clarify: when the user's answer reveals the problem is substantially different from what was initially described
- Before handoff: when blocking unknowns remain that only the user can resolve

Never carry unresolved blocking unknowns silently into the frame artifact.

## Termination Conditions

| Condition | Outcome |
|-----------|---------|
| Frame question answered + blocking unknowns resolved | `complete` |
| User says "just plan it" + blocking unknowns acknowledged | `complete` with accepted risk |
| 5 iteration cap reached (one iteration = one pass from clarify through frame) | Freeze best state, surface gaps |
| Input classified as wrong tool | Redirect, no artifact |

## Anti-Patterns

- Asking leading questions that embed solutions
- Proposing implementations during discuss (this is framing, not planning)
- Framing the frame question as a solution choice ("should we use Redis?") instead of a diagnostic question ("is the bottleneck in storage or retrieval?")
- Dispatching tier-2 agents for questions answerable by the user
- Dispatching tier-3 team for simple problems with clear scope
- Silently dropping blocking unknowns when user wants to proceed
- Running discuss when input is already plan-ready
- Producing a frame artifact that references conversation turns (violates self-sufficiency)
