# Lint: No run-* Cycles

Detects cross-`run-*` references that violate the SPINE.md invariant: "No `run-*` skill calls another `run-*` skill."

## Invariant

A `run-*` skill may reference its own files (self-refs are fine). A violation occurs when a `run-A` skill's content invokes or references `run-B` (a sibling primitive), creating a dependency graph that breaks standalone invocation contracts.

## What Counts as a Violation

- Slash-command form: `/run-<name>` where `<name>` is a different run-* primitive (e.g., `/run-review` inside `run-implement/SKILL.md`).
- Path form: `skills/run-<name>/` reference inside a different run-* directory.

Self-references are excluded: a skill referencing its own directory path or slash command is not a violation.

## Lint Script

The executable lint lives at sibling path [`lint-no-run-cycles.sh`](lint-no-run-cycles.sh). Invoke via:

```bash
bash "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-curate/references/lint-no-run-cycles.sh"
```

## Pass Criterion

Exit code 0, output line: `PASS: 0 cross-run-* violations`.

## False-Positive Guidance

- Glob patterns like `run-*` in prose are excluded by the `grep -v "run-\*"` filter.
- Installed script paths using `$HOME/.agents/skills/run-*`, `.agents/skills/run-*`, or `SPINE_SKILLS_DIR` are excluded; they are filesystem resolution, not skill composition.
- `See Also` sections that mention sibling skills by name (not path) are advisory references, not invocations. If they generate false positives, exclude the specific line pattern with an additional `grep -v`.
- Documentation files that discuss the invariant itself (e.g., this file) live under `run-curate/` — they are scanned but the self-exclusion covers `run-curate` refs inside `run-curate/`.

## Integration

Run this lint during `run-curate` Gather phase (standalone mode) as a structural health check. Surface violations as `blocking` curation findings — they indicate an invariant breach that must be fixed before any knowledge is promoted.

```bash
# Quick inline invocation from run-curate Gather phase:
bash "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-curate/references/lint-no-run-cycles.sh"
```
