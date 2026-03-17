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

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Orient | `@scout` + `@navigator` | — (in orchestrator) |
| Investigate | `@scout` / `@researcher` / `@navigator` | — (in orchestrator) |
| Explore | `@framer` + `@navigator` | — (in orchestrator) |
| Frame | `@framer` + `@envoy` + `@synthesizer` | [frame-*.md](references/) |
| Spec Create | `@envoy` | [orchestrate-spec-creation.md](references/orchestrate-spec-creation.md) |

## Intake

Redirects: plan-ready → `do-plan`, reproducible defect → `run-debug`, pure ideation → `brainstorming`, < 1 sentence → grounding question. Detect upstream handoff (brainstorming selected direction, run-debug root cause). Seed known inventory.

## Mode Routing

| Detection | Mode | Load |
|-----------|------|------|
| "grill me", "challenge", "poke holes", stress-test | deep-interview | [orchestrate-discuss.md](references/orchestrate-discuss.md) `mode=deep-interview` |
| Scope exceeds single session + no @-ref | spec-creation | [orchestrate-spec-creation.md](references/orchestrate-spec-creation.md) |
| @-referenced spec file | spec-mode | [spec-mode.md](references/spec-mode.md) |
| Default | normal | [orchestrate-discuss.md](references/orchestrate-discuss.md) `mode=normal` |

Load matched reference after detection.

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
