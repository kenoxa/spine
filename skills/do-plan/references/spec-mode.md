# Spec Mode

Conditional mode activated when an `@`-referenced file is a spec. Standalone mode proceeds unchanged when spec mode does not activate.

## Detection

Triggered when `@`-referenced file contains all three spec markers (per `do-discuss/references/template-spec.md`):
- `## Status` table
- `## Phases` heading
- `### Phase N:` headings

Malformed spec (missing any marker) → graceful fallback to standalone mode with advisory note: "Spec markers not found in referenced file. Proceeding in standalone mode."

Never run detection on files not explicitly `@`-referenced by the user.

## Phase Selection

1. Parse `## Status` block — extract phase list with statuses
2. Identify selectable phases: `[ ] pending` or `[~] in-progress` with all predecessors `[x] done`
3. Display unblocked phases to user
4. User picks, or agent infers from natural language when unambiguous (e.g., "plan the auth phase" matches a single phase)

If no phase is selectable (all pending phases have unmet deps): display all pending phases with their blocking predecessors. Let user choose (override) or resolve the dependency.

### "Plan next phase"

When spec present without specific phase request → find first `[ ] pending` or `[~] in-progress` phase with all predecessors `[x] done`. Confirm with user: "Next unblocked phase is Phase N: <Title>. Proceed?"

## Dependency Gate

When selected phase has predecessors not `[x] done` → warn with predecessor status table. User can override — advisory only, NOT a hard block. Never silently plan a phase with unmet dependencies.

## Status Update

Set selected phase to `[~] in-progress` in the spec's Status table. User confirms before write (same human-gate pattern as do-execute). If user declines status update → proceed with planning anyway.

If phase already `[~] in-progress` → skip status update (re-plan scenario).

## Spec Context Enrichment

Add `spec_context` field to `planning_brief` during Framing:

| Field | Content |
|-------|---------|
| `phase` | Phase number and title |
| `acceptance_criteria` | Verbatim EARS acceptance criteria from the phase |
| `constraints` | Constraints from spec's Constraints & Non-Goals section |
| `success_criteria` | Success Criteria from spec (full-feature level) |

## Synthesis Output

plan.md includes reference line (first line after Summary heading):

```
> Spec: docs/specs/{YY}{WW}-<slug>/spec.md | Phase N of <total>
```

Include spec-conditional sections per template-plan.md Optional Sections table: Spec Context, Validation, Deferred.

## Post-Plan Reminder

After readiness declaration: "Run do-execute. On completion, you'll be prompted to update spec status."

## Anti-Patterns

- Treating dependency gate as hard block (it's advisory — user can override)
- Running detection on non-`@`-referenced files
- Paraphrasing EARS criteria instead of copying verbatim
- Skipping status update confirmation
