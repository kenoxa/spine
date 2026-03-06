---
description: >
  Documentation and prose quality standards.
  Use when creating or editing docs, READMEs, changelogs, ADRs, or user-facing text.
  Do NOT use for code comments or commit messages — do-commit handles commits.
argument-hint: "[artifact type or document to write/edit]"
---

Route writing tasks to the correct artifact structure. Classify first, then write.

## Artifact Types

| Artifact | Key structure |
|----------|--------------|
| Docs (public/internal) | Diataxis: pick one mode per section — tutorial, how-to, reference, or explanation. Never mix. |
| ADR / decisions | See [references/decision-template.md](references/decision-template.md); numbered, immutable once accepted |
| Changelog / release notes | User-facing impact grouped by type (added, changed, fixed, removed) |
| README | Purpose → quick start → usage → contributing; scannable, no walls of text |
| Runbook | Trigger → steps → verification → rollback; executable by someone unfamiliar with the system |

## Docs Impact

Classify scope before writing:

- **Customer-facing**: user-visible behavior, API usage, config surfaces, deployment/runtime
- **Internal**: engineering workflow, architecture contracts, contributor guidance, runbooks
- **Both**: when both audiences are affected
- **None**: record explicit skip rationale

## Workflow

1. **Classify** — identify artifact type and docs impact lane before writing.
2. **Structure first** — lay out headings and sections matching the artifact type, then fill.
3. **Write concretely** — specific over vague, examples over descriptions, scannable over dense.
4. **Verify completeness** — check required sections exist for the artifact type.

## Changelog Rules

- Breaking changes: lead with `**BREAKING:**`, state what fails if users do nothing, provide migration steps.
- What's New: write user-facing outcomes ("Now supports..."), not internal refactors.
- Deprecations: announce before removing, provide replacements and timelines.
- Fixes: describe user impact ("X now works"), skip internal noise.

## Anti-Patterns

- Starting to write without classifying the artifact type
- Mixing Diataxis modes in a single section (tutorial steps inside a reference page)
- Walls of text without headings or scannable structure
- Documenting implementation details instead of user-facing behavior
- Changelog entries that describe code changes instead of user impact
