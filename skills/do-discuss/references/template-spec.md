# Spec Template

## Detection Markers

How skills detect a spec document:

- **Spec markers**: `## Status` table + `## Phases` heading + `### Phase N:` headings
- **Plan reference line** (written by do-plan, detected by do-execute):
  ```
  > Spec: docs/specs/{YY}{WW}-<slug>/spec.md | Phase N of <total>
  ```

## Status Legend

| Status | Display | Meaning |
|--------|---------|---------|
| pending | [ ] pending | Not started |
| in-progress | [~] in-progress | Active work |
| done | [x] done | Completed |

Status table format:

```markdown
| Phase | Title | Status |
|-------|-------|--------|
| 1 | <title> | [ ] pending |
| 2 | <title> | [~] in-progress |
| 3 | <title> | [x] done |
```

## Spec Skeleton

```markdown
# Spec: <Feature Name>

## Status

| Phase | Title | Status |
|-------|-------|--------|

## Problem

## Users & Context

## Capability

## Success Criteria (EARS)

## Constraints & Non-Goals

## Open Questions

## Phases

### Phase N: <Title>

**Scope**: concrete file/component names
**Depends on**: comma-separated phase numbers (e.g., "1, 3") or `none` for roots
**Acceptance Criteria**:
- 2-5 EARS statements
**Out of scope**:
```

## EARS Pattern Reference

| Pattern | Template |
|---------|----------|
| Ubiquitous | `THE SYSTEM SHALL <action>` |
| Event-driven | `WHEN <event> THE SYSTEM SHALL <response>` |
| State-driven | `WHILE <state> THE SYSTEM SHALL <behavior>` |
| Conditional | `IF <precondition> THEN THE SYSTEM SHALL <action>` |
| Context | `WHERE <context> THE SYSTEM SHALL <behavior>` |

### Good Examples

```
WHEN spec-creation mode is triggered THE SYSTEM SHALL create docs/specs/{YY}{WW}-<slug>/spec.md
IF Phase N depends on Phase M AND M is [ ] pending THEN THE SYSTEM SHALL warn before proceeding
WHILE a phase is [~] in-progress THE SYSTEM SHALL prevent concurrent phase starts
THE SYSTEM SHALL initialize all phases as [ ] pending on spec creation
WHERE the project has an existing spec directory THE SYSTEM SHALL edit in-place rather than overwrite
```

### Bad Examples

```
WHEN the feature works THE SYSTEM SHALL be usable        (not testable)
THE SYSTEM SHALL handle errors nicely                     (vague)
THE SYSTEM SHALL be performant                            (no metric)
WHEN something goes wrong THE SYSTEM SHALL recover        (undefined trigger + action)
```

## Quality Bar

Each acceptance criterion must be verifiable in <30s by hand: read the output, check the condition, pass/fail. No subjective judgment, no benchmarks, no external tooling required.
