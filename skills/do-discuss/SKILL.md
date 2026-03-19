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

Socratic dialogue: intake → orient → clarify → investigate → explore → frame → handoff. All phases always execute; agent scales dispatch within each. Orient runs zero-dispatch when not codebase-adjacent.

## Phases

**Subagent references** (backticked): dispatch to subagent — do NOT Read into mainthread.
**Phase dispatch references** (backticked `dispatch-*.md`): lazy-load into mainthread when entering each phase. Read the matched dispatch ref via the Read tool.

| Phase | Dispatch ref | Agent type | Subagent refs |
|-------|-------------|-----------|---------------|
| Orient | `references/dispatch-orient.md` | `@scout` + `@navigator` | `run-explore/references/explore-scout.md`, `run-explore/references/explore-navigator.md` |
| Clarify | `references/dispatch-clarify.md` | mainthread | `run-explore/references/explore-scout.md`, `run-explore/references/explore-navigator.md` (proactive assists) |
| Investigate | `references/dispatch-investigate.md` | `@scout` / `@researcher` / `@navigator` | `run-explore/references/explore-scout.md`, `references/investigate-researcher.md`, `run-explore/references/explore-navigator.md` |
| Explore | `references/dispatch-explore.md` | `@framer` + `@navigator` + `@envoy` | `references/explore-*.md` |
| Frame | `references/dispatch-frame.md` | `@framer` + `@envoy` + `@synthesizer` | `references/frame-*.md` |
| Spec Create | — | `@envoy` | `references/orchestrate-spec-creation.md` |

## State Protocol

| Variable | Lifecycle | Mutation Rule |
|----------|-----------|---------------|
| `codebase_signals` | create: orient; append: investigate | append-only |
| `external_signals` | create: orient/research-override; append: clarify-nav, investigate | append-only |
| `known` / `unknown` | create: orient/clarify-start; mutate: clarify, investigate | mutable — items move between them |
| `key_decisions` | create: clarify; accumulate: investigate, explore | accumulate-only; per-item status: `open → exploring → resolved / deferred` |
| `frame_question` | derive: clarify | immutable after derivation |

## Intake

Redirects: plan-ready → `do-plan`, reproducible defect → `run-debug`, pure ideation → `brainstorming`, < 1 sentence → grounding question. Detect upstream handoff (brainstorming selected direction, run-debug root cause). Seed known inventory.

Spec routing: @-referenced spec file → Read `references/spec-mode.md`. Explicit "write a spec" → Read `references/orchestrate-spec-creation.md`.

**Session ID**: per SPINE.md. Carry into do-plan. Log at phase boundaries.

## Handoff

Phase coverage: verify Phase Trace has entries for orient through frame. Zero-dispatch phases require a row with justification. Missing = incomplete.

Confidence-gated. Main thread = sole handoff authority.

| Confidence | Declaration |
|------------|-------------|
| high | "Discussion complete. Proceed with `/do-plan`." |
| medium | "Complete with open assumptions. Proceed with `/do-plan` or resolve assumptions first." |
| low | "Needs further exploration. Consider `/brainstorming`." |
| `spec-creation` | "Scope exceeds single session. Proceed with spec creation." Carry all state to `references/orchestrate-spec-creation.md`. |

Termination: all `key_decisions` resolved/deferred + frame question answerable → `complete`. "just plan it" + acknowledged unknowns → `complete` with risk. Stall (3 exchanges with no status changes) → surface gaps + recommend next step. Wrong tool → redirect.

Emit `discussion_learnings` proposals (never auto-applied). STOP after declaration. User decides next step.

Ask: during clarify (problem changes), before handoff (blocking unknowns). Never carry blocking unknowns silently.

## Skill Relationships

`do-discuss → do-plan → do-execute` · `brainstorming → do-plan` · `do-discuss → brainstorming` (low confidence) · `run-debug → do-discuss` (root cause) · `do-discuss (spec-creation) → do-discuss (spec-mode)`

## Anti-Patterns

- Entering spec-creation mode for clearly single-session work
- Restarting interview from scratch when Handoff routes to spec-creation
- Auto-triggering do-plan after spec creation
