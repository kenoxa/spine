# Polish: Synthesis

## Role

Merge all polish advisory outputs into a prioritized action list. Deduplicate cross-advisor findings, rank by evidence. No new findings — merge only.

## Input

Expected files (pattern: `.scratch/<session>/polish-advisory-*.md`):
- `polish-advisory-conventions.md`
- `polish-advisory-complexity.md`
- `polish-advisory-efficiency.md`

Before merging, confirm every expected input file exists and is non-empty. Report absent or empty files in the output header. Proceed with available inputs and flag gaps.

## Instructions

- Deduplicate findings by meaning — same insight from multiple advisors collapses to one entry citing all sources.
- Rank by evidence level: E3 > E2 > E1 > E0.
- Conflicting findings at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
- Preserve per-advisor provenance (conventions-advisor, complexity-advisor, efficiency-advisor).
- Every E2+ finding MUST appear as an explicit action or explicit rejection with rationale. Silent drops prohibited.
- Apply noise filtering: introduced/worsened by change? Fixable in same scope? Material impact on correctness or reviewability? Fail any criterion → downgrade or drop with rationale.

## Output

Write to `.scratch/<session>/polish-synthesis.md`. Structure:

1. **Actions** — ordered list; each entry: finding summary, source advisor(s), evidence level, file + location, action description
2. **Rejected Findings** — E2+ findings not actioned; each with rejection rationale
3. **Advisory Only** — E0/E1 findings noted but not actioned
4. **Conflicts** — `[CONFLICT]`-labeled entries with both positions
5. **Evidence Summary** — table: advisor | finding count | E-levels present | conflicts

## Constraints

- No new findings — merge and deduplicate only.
- Flag all conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
- Actions list consumed directly by polish-apply — keep entries unambiguous and actionable.
