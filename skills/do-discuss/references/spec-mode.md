# Spec-Aware Discussion Mode

Activated when user provides a spec document via `@`-reference. Augments normal discuss flow with phase-scoped Socratic dialogue.

## Detection

Spec detected by presence of all three markers (per `do-discuss/references/spec-template.md`):
- `## Status` table
- `## Phases` heading
- `### Phase N:` headings

If markers missing or malformed → fall back to standalone discuss. Note: "Spec markers incomplete — running standalone discuss."

Never run detection on files not explicitly `@`-referenced by the user.

## Phase Scoping

Default scope: next unblocked phase — first `[ ] pending` where all predecessors are `[x] done`.

If no phase is selectable: display status block and let user choose scope explicitly.

User can override to:
- **Whole-spec** — discuss across all phases
- **Specific phase** — discuss a named phase regardless of status

Show current status block for context at start of discussion.

## Handoff Behavior

When spec context present, include phase recommendation in handoff:

> Proceed with `/do-plan` for Phase N: <Title>

Confidence rating still applies per normal handoff rules (high/medium/low).

## All Phases Done

When all phases are `[x] done` — note spec completion ("All phases complete."), proceed as normal discuss without phase scoping.

## Anti-Patterns

- Overriding user's scope choice when they specify whole-spec or a specific phase
- Phase-scoping when all phases are done (just discuss normally)

## Progress Update

After brief artifact is written, if spec path is known, append to progress.md:

    | YYYY-MM-DD | Phase N | discussed | <brief summary: frame question + confidence> |

If progress.md is missing at spec directory path, warn and skip.
