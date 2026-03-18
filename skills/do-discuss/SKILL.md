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

Tiered Socratic dialogue: intake → orient → clarify → investigate → explore → frame → handoff. Tiers: (1) dialogue + between-round assists, (2) codebase investigation, (3) multi-perspective exploration, (4) spec creation (terminal).

## Phases

**Subagent references** (backticked): dispatch to subagent — do NOT Read into mainthread.
**Phase dispatch references** (backticked `dispatch-*.md`): lazy-load into mainthread when entering each phase. Read the matched dispatch ref via the Read tool.

| Phase | Dispatch ref | Agent type | Subagent refs |
|-------|-------------|-----------|---------------|
| Orient | `references/dispatch-orient.md` | `@scout` + `@navigator` | `references/orient-scout.md`, `references/navigator-synthesis.md` |
| Clarify | `references/dispatch-clarify.md` | mainthread | `references/orient-scout.md`, `references/navigator-synthesis.md` (between-round assists) |
| Investigate | `references/dispatch-investigate.md` | `@scout` / `@researcher` / `@navigator` | `references/orient-scout.md`, `references/investigate-researcher.md`, `references/navigator-synthesis.md` |
| Explore | `references/dispatch-explore.md` | `@framer` + `@navigator` | `references/explore-*.md` |
| Frame | `references/dispatch-frame.md` | `@framer` + `@envoy` + `@synthesizer` | `references/frame-*.md` |
| Spec Create | — | `@envoy` | `references/orchestrate-spec-creation.md` |

Note: `dispatch-{phase}.md` is a local naming convention for mainthread-loaded phase refs in do-discuss. Not a repo-wide standard.

## State Protocol

| Variable | Lifecycle | Mutation Rule |
|----------|-----------|---------------|
| `codebase_signals` | create: orient; append: investigate | append-only |
| `external_signals` | create: orient/research-override; append: clarify-nav, investigate | append-only |
| `known` / `unknown` | create: orient/clarify-start; mutate: clarify, investigate | mutable — items move between them |
| `key_decisions` | create: clarify; accumulate: investigate, explore | accumulate-only |
| `frame_question` | derive: clarify | immutable after derivation |
| `round_budget` | set: clarify entry (base 5); reduce: orient/external findings | conditional reduction, hard minimum 3 |

## Escalation

| From | To | Trigger |
|------|----|---------|
| Clarify | spec-creation | 2-of-3 scope threshold — carry all state to `references/orchestrate-spec-creation.md` |
| Clarify | Investigate | blocking unknown requires codebase depth beyond scout orient or clarify-assists |
| Investigate | Explore | ambiguous scope + 2+ one-way-door `key_decisions` after investigation |

## Intake

Redirects: plan-ready → `do-plan`, reproducible defect → `run-debug`, pure ideation → `brainstorming`, < 1 sentence → grounding question. Detect upstream handoff (brainstorming selected direction, run-debug root cause). Seed known inventory.

Spec routing: @-referenced spec file → Read `references/spec-mode.md`. Explicit "write a spec" → Read `references/orchestrate-spec-creation.md`.

**Session ID**: per SPINE.md. Carry into do-plan. Log at phase boundaries and tier escalations.

## Handoff

Confidence-gated. Main thread = sole handoff authority.

| Confidence | Declaration |
|------------|-------------|
| high | "Discussion complete. Proceed with `/do-plan`." |
| medium | "Complete with open assumptions. Proceed with `/do-plan` or resolve assumptions first." |
| low | "Needs further exploration. Consider `/brainstorming`." |

Termination: frame question answered → `complete`. "just plan it" + acknowledged unknowns → `complete` with risk. 5 iteration cap → freeze + surface gaps. Wrong tool → redirect.

Emit `discussion_learnings` proposals (never auto-applied). STOP after declaration. User decides next step.

Ask: during clarify (problem changes), before handoff (blocking unknowns). Never carry blocking unknowns silently.

## Skill Relationships

`do-discuss → do-plan → do-execute` · `brainstorming → do-plan` · `do-discuss → brainstorming` (low confidence) · `run-debug → do-discuss` (root cause) · `do-discuss (spec-creation) → do-discuss (spec-mode)`

## Anti-Patterns

- Entering spec-creation mode for clearly single-session work
- Restarting interview from scratch when mid-clarify escalation triggers spec-creation
- Auto-triggering do-plan after spec creation
