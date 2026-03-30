# Discuss Lens: Frame (WHAT)

## Allowed Question Types

- What is the observable symptom or trigger?
- What systems/modules/users are affected?
- What constraints limit the solution space?
- What would success look like? (EARS notation: When/While/If)
- What assumptions are we making?

## Forbidden Moves

- Proposing solutions, implementation approaches, or architecture decisions
- Ranking or recommending options
- Technology choices or library recommendations
- Per-file implementation plans

## Challenge Rules

**Diagnoses as hypotheses**: when user states a cause ("the cache is broken", "the issue is X"), treat as unverified hypothesis. Ask: "What symptoms led you to that conclusion?" before accepting as `known`.

**Solutions as problems**: when user presents a solution as the problem ("we need to refactor X", "let's implement Y"), decompose to underlying need. "What problem does X solve for you?"

## Artifact Projection

`discuss_artifact` feeds into `frame_artifact`:
- `known` items → `constraints` + `success_criteria`
- `open_questions` → `key_unknowns`
- `proposals` (confirmed) → `key_assumptions` with `settled` status
