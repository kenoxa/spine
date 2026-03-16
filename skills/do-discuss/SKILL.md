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
  Also trigger on spec creation: "write a spec", "create a spec",
  "specify this feature", "scope this feature", "break this into phases",
  "multi-session", "more than one session", "too big for one session",
  "decompose this", feature spanning multiple sessions,
  need persistent scope documentation.
  Do NOT use when: requirements are plan-ready (do-plan), reproducible defect (run-debug),
  creative ideation without a problem (brainstorming).
argument-hint: "[problem description, symptom, or situation]"
---

Frame the actual problem through tiered Socratic dialogue: intake → orient → clarify → investigate → explore → frame → handoff. Orient is conditional (codebase-adjacent input only). Investigate and explore are conditional (tier escalation only).

## Tiered Interaction Model

| Tier | Mode | Trigger | Agents |
|------|------|---------|--------|
| 1 | Orient (pre-tier, conditional) + Socratic dialogue with between-round @scout assists | Always starts here | `@scout` (orient + clarify-assist) + `@navigator` |
| 2 | Codebase-assisted | Codebase-dependent unknown blocks framing AND user cannot answer | `@scout`, `@researcher`, or `@navigator` |
| 3 | Multi-perspective exploration | Ambiguous scope + 2+ one-way-door decisions after clarify + investigate | `@framer` team |
| 4 | Spec creation (terminal — emits spec.md + progress.md, not brief.md) | Scope exceeds single session at intake OR mid-clarify scope growth (2-of-3 signals) | Main thread interview + `@second-opinion` (2x advisory-only) |

## Phases

| Phase | Agent type |
|-------|-----------|
| Orient | `@scout` (haiku, orient mode) + `@navigator` |
| Investigate | `@scout` / `@researcher` / `@navigator` |
| Explore | `@framer` + `@navigator` |
| Frame | `@synthesizer` |
| Spec Create | `@second-opinion` (advisory-only, 2x sequential) |

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
| Scope exceeds single session (2-of-3 signals) AND no @-reference present | Activate spec-creation mode — see [references/spec-creation.md](references/spec-creation.md) |
| Spec provided via `@`-reference | See [references/spec-mode.md](references/spec-mode.md) |
| Plan/design for stress-testing, "grill me", "challenge my assumptions", "poke holes" | Proceed to clarify with deep-interview mode |

Detect upstream handoff: `brainstorming` (selected direction) or `run-debug` (root cause, scope exceeds fix). Seed known inventory from upstream.

### 2. Orient (conditional — codebase-adjacent input only)

Dispatches `@scout` (haiku, orient mode) + `@navigator` to gather breadth-first codebase context before Socratic dialogue begins. Tier-1 "no subagents" constraint (§3 Clarify) does not apply here.

**Codebase-adjacency classification** (run at end of intake, after redirect check):

| Signal | Classification |
|--------|---------------|
| Upstream handoff present (brainstorming or run-debug) | Codebase-adjacent — always orient |
| Input names a file, module, function, or system component explicitly | Codebase-adjacent |
| Input contains inline code block | Codebase-adjacent |
| Input contains diagnostic language over system behavior (slow, broken, timeout, error, bug) AND names a component | Codebase-adjacent (soft signal) |
| Input contains diagnostic language only, no named component | Grounding question first; re-classify after response |
| Design/architectural framing language without operational context (e.g., "should we adopt X", "how should we structure Y", "feels like it owns too much") — even when a component is named | Not codebase-adjacent — skip orient |
| Input < 1 sentence, grounding question not yet asked | Defer classification until after grounding response |
| Pure process/organizational/domain question, no system references, no upstream handoff | Not codebase-adjacent — skip orient |

**When codebase-adjacent**:
1. Dispatch `@scout` with orient-mode query: intake signals (named components, upstream handoff context, inline code) as the seed. Output: `.scratch/<session>/discuss-orient.md`.
1b. Dispatch `@navigator` in parallel with `@scout`. Extract `seed_terms` from intake signals (named components, library references, inline code). `research_question`: "What upstream or external knowledge about [seed_terms] is relevant to [problem_description]?" `mode`: `synthesis`. Output: `.scratch/<session>/discuss-orient-external.md`.
2. Orient artifacts must contain:
   - **Answer** — what the codebase contains relevant to the problem
   - **File map** — paths with key line ranges
   - **Gaps** — what could not be determined; note potential lens signals if observed (e.g., "async queue found — potential concurrency lens signal")
   - **External signals** — `external_signals` table from `.scratch/<session>/discuss-orient-external.md` (empty if navigator found nothing). Parallel to codebase signals.
3. Append to session log: phase boundary, `@scout` dispatched, 1-sentence orient summary.
4. Carry `codebase_signals` (from scout) and `external_signals` (from navigator) into clarify as pre-populated context.

**When NOT codebase-adjacent** (orient skipped):
- Proceed directly to clarify.
- No session log entry required (phase not entered).
- `codebase_signals` is empty.
- `external_signals` is empty unless the external research override below triggers.

**External research override** (when orient skipped but library names present):

| Signal | Action |
|--------|--------|
| Input names a library, framework, package, or SDK | Dispatch `@navigator` standalone |
| Input references version constraint, API, or "upstream" | Dispatch `@navigator` (soft signal) |
| No library/framework names in input | Skip — `external_signals = []` |
| Ambiguous | Dispatch `@navigator` — handles no-library gracefully |

When triggered: dispatch `@navigator` with `seed_terms` from input, `codebase_signals = []`, `mode`: `synthesis`, output: `.scratch/<session>/discuss-orient-external.md`. Carry `external_signals` into clarify. Append to session log.

**Failure handling**:
- `@scout` or `@navigator` returns empty/irrelevant: set corresponding signals to `[]`, note in Gaps if applicable, proceed to clarify without blocking or surfacing empty output.
- Grounding question was asked at intake (< 1 sentence or diagnostic-only): re-run adjacency classification after user responds before dispatching orient.

Orient does NOT: select variance lenses (tier-2 §4), ask user questions, block clarify, or run in deep-interview mode ("grill me" / stress-testing — starts from clarify without orient).

### 3. Clarify

Socratic dialogue. Main thread only — this is the user interaction loop. Subagent dispatches happen between rounds, not during them.

When `codebase_signals` is non-empty (orient ran): seed `known` inventory before first round. Do not re-ask questions orient already answered. Also seed `external_signals` from navigator if non-empty. Do not re-ask questions navigator already answered.

**Between rounds** (after each user response, before formulating next questions): if the user's answer introduces a named codebase reference (file, module, function, service) not already covered by orient or a prior clarify-assist dispatch → dispatch `@scout` (haiku, orient mode) with the named reference as query. Output: `.scratch/<session>/discuss-clarify-assist-<round>.md`. Incorporate findings into the next question batch. Track dispatched references to avoid re-dispatch.

**Between-round navigator assists** (after each user response): if the user's answer introduces a library, framework, or external dependency not already covered by orient's navigator dispatch or a prior clarify-nav dispatch → dispatch `@navigator` with the new reference as `seed_terms`, `mode`: `synthesis`, output: `.scratch/<session>/discuss-clarify-nav-<round>.md`. Incorporate findings into the next question batch as additional `external_signals`. Track dispatched references to avoid re-dispatch.

**Between-round scope escalation**: if user's answer reveals scope-growth signals meeting the 2-of-3 threshold, escalate to spec-creation mode. Carry all accumulated state. Do not restart from intake. See [references/spec-creation.md](references/spec-creation.md).

Round budget adjustment: if orient's **Answer** section is non-empty, reduce budget by 1. If `external_signals` is non-empty, reduce budget by 1. Minimum 2 rounds normal / 4 rounds deep-interview. Hard minimum 2 rounds.

Derive the **frame question** — single question whose answer unblocks planning. Specific (names affected system/behavior), answerable (finite answers), scoped (enables planning). Example: "Is the auth retry failure a client-side timeout or a server-side rate limit?"

- Ambiguity buckets: **goal**, **scope**, **constraints**, **stakeholder**
- Batch 2-4 independent questions per round; sequential dependents one at a time
- Track `known` / `unknown` inventory; 3-round budget
- After each round: update inventory, check frame question answerability

**Deep interview**: activate when user says "grill me", "challenge my assumptions", "poke holes", or provides a plan/design for stress-testing. Increase round budget from 3 to 5. Challenge stated requirements — push back on "obvious" answers. Actively probe for unstated assumptions and implicit constraints. Same output (frame artifact) — deeper interrogation path.

Escalation to tier 2: blocking unknown requires depth investigation — behavior, side effects, data flow — beyond what @scout orient mode or clarify-assist dispatches have answered.

### 4. Investigate (conditional, tier 2)

Subagent dispatch for codebase evidence.

| Agent | Use when | Output |
|-------|----------|--------|
| `@scout` | Orientation: "does X exist? where? what shape?" | `.scratch/<session>/discuss-investigate-scout.md` |
| `@researcher` | Depth: "how does X work? what are the side effects?" | `.scratch/<session>/discuss-investigate-researcher.md` |
| `@navigator` | External: "what does the ecosystem say about X?" | `.scratch/<session>/discuss-investigate-navigator.md` |

Dispatch context: specific unknowns from inventory, current `known`/`unknown` state, why user could not answer (domain vs. codebase gap).

Dispatch `@navigator` when the blocking unknown involves external library behavior, API compatibility, or ecosystem alternatives — not codebase depth. Navigator at investigate runs targeted queries, not the broad orient sweep.

Duplication prevention: before dispatching, check orient output (`.scratch/<session>/discuss-orient.md`) and any clarify-assist outputs (`.scratch/<session>/discuss-clarify-assist-*.md`). For each blocking unknown: if the relevant file appears in a prior File map, dispatch @scout with a depth-specific question (e.g., "how does the retry backoff work in queue.js, specifically the retry section") rather than general orientation. Only if a prior Answer section explicitly resolves the unknown may escalation be omitted — file presence alone is not sufficient. Prior findings narrow the dispatch query; they never suppress it.

Before dispatch: select 1 lens from `do-plan/references/variance-lenses.md` — match `unknown` inventory against lens trigger column, log selection reasoning (2-3 sentences). Dispatch one augmented `@researcher` with the lens focus directive. Max 3 concurrent (1-2 base + 1 augmented). Max 2 rounds. Synthesize into `codebase_signals`, return to clarify. Merge navigator findings into `external_signals` (append to orient's external_signals; do not overwrite).

Escalation to tier 3: ambiguous scope AND `key_decisions` has 2+ one-way-door options after investigation.

### 5. Explore (conditional, tier 3)

Team `discuss-explore` — three `@framer` personas for one-way-door decisions resisting convergence:

| Role | Output |
|------|--------|
| `stakeholder-advocate` | `.scratch/<session>/discuss-explore-stakeholder-advocate.md` |
| `systems-thinker` | `.scratch/<session>/discuss-explore-systems-thinker.md` |
| `skeptic` | `.scratch/<session>/discuss-explore-skeptic.md` |

Dispatch context: current `brief` (in-progress), full `known`/`unknown` inventory, assigned perspective, all three output paths.

Dispatch `@navigator` in parallel with the framer team. Use `mode`: `alternatives`. Output: `.scratch/<session>/discuss-explore-navigator.md`.

Dispatch all three in parallel → wait → re-invoke each to read peers and append `## Peer Reactions` → synthesize. Include navigator in the peer-reaction round when dispatched. Irreconcilable positions become `key_decisions`.

Dispatch one additional `@framer` with the variance lens from investigate (or select lens per variance-lenses.md if investigate was skipped). Output: `.scratch/<session>/discuss-explore-augmented-{lens}.md`. Included in peer reaction round. Max 4 total framers plus 1 navigator plus 1 second-opinion.

#### Second-Opinion

Load `use-second-opinion`. Dispatch `@second-opinion` concurrently with base framers. Excluded from peer-reaction round — SO output feeds Frame synthesis (§6) only:
- Prompt content: current `problem_frame` + `known`/`unknown` inventory + `key_decisions` with door-types + `codebase_signals` + `external_signals` (all self-contained — no local path references)
- Output format: 4-section framer structure with `external-analyst` perspective (perspective summary, key observations, challenges to current framing, synthesis weights)
- Output path: `.scratch/<session>/discuss-explore-second-opinion.md`
- Variant: `standard`

Cap: base framers (3) + navigator (1) + second-opinion (1) + augmented ≤ 6.

### 6. Frame

#### Second-Opinion (sequential pre-synthesis)

Load `use-second-opinion`. Dispatch `@second-opinion` BEFORE synthesizer (sequential — Frame has zero base agents, so concurrent dispatch would prevent synthesizer from seeing SO output):
- Prompt content: problem framing question + final `known`/`unknown` inventory + `key_decisions` with door-types + structured explore summary (if tier 3 ran) + `codebase_signals` + `external_signals` (all self-contained — no local path references)
- Output format: 4-section advisory structure (frame assessment, missing considerations, weight adjustments, confidence factors)
- Output path: `.scratch/<session>/discuss-frame-second-opinion.md`
- Variant: `advisory-only`

Cap: second-opinion (1) + synthesizer (1) ≤ 2.

#### Synthesis

Dispatch `@synthesizer` with accumulated session state. Output: `.scratch/<session>/brief.md` per [references/brief-template.md](references/brief-template.md).

Dispatch context must include:
- `known` / `unknown` inventory (final state after clarify)
- `codebase_signals` from orient and/or investigate
- `external_signals` from orient, clarify assists, investigate, and/or explore
- `key_decisions` with door-type classifications
- Evidence manifest (paths to orient, investigate, and explore artifacts)
- Session ID
- `.scratch/<session>/discuss-explore-second-opinion.md` if it exists and is not a skip advisory
- `.scratch/<session>/discuss-frame-second-opinion.md` if it exists and is not a skip advisory

Synthesizer: use-second-opinion `advisory-only` variant (both explore and frame SO files). Tail: "Evaluate for framing insights."

`@synthesizer` writes the frame artifact. Main thread reads the output and validates the self-sufficiency contract: understandable without chat history, all terms defined, no conversation references, evidence levels present. If self-sufficiency fails, re-dispatch with the gap list appended to context.

### 7. Handoff

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
do-discuss (spec-creation) → do-discuss (spec-mode)  (spec created → phase-scoped discussion)
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
- Dispatching agents during clarify (user dialogue loop must stay on main thread; between-round `@scout` and `@navigator` assists are the only exceptions)
- Dispatching a full `@researcher` or multi-agent team at orient — orient uses `@scout` plus `@navigator` for breadth only, not depth
- Escalating to tier-2 investigate for unknowns already answered by orient (orient's Answer section must explicitly resolve the unknown — file presence in File map alone is not sufficient)
- Asking the user about codebase facts orient could have answered proactively
- Running orient on pure-domain problems with no codebase component (unnecessary context noise; delays Socratic questions)
- Fire-and-forward navigator usage with no `external_signals` handoff into later phases
- Using navigator for codebase-depth questions that belong to `@researcher`
- Re-dispatching navigator for a library or dependency already covered in the session
- Entering spec-creation mode for clearly single-session work
- Restarting interview from scratch when mid-clarify escalation triggers spec-creation
- Auto-triggering do-plan after spec creation (hand off to new discuss session, not planning)
