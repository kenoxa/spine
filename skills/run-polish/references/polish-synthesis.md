# Polish: Synthesis

## Input

Advisory output files as provided in dispatch context. May include augmented lens outputs beyond base 2-3.

Before merging, confirm every provided input file exists and is non-empty. Report absent or empty files in output header. Proceed with available inputs and flag gaps.

## Instructions

- Deduplicate findings by meaning — same insight from multiple advisors collapses to one entry citing all sources.
- Rank by evidence level: E3 > E2 > E1 > E0.
- Conflicting findings at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
- Provenance labels: conventions-advisor, complexity-advisor, efficiency-advisor [conditional], augmented lens name. Efficiency lens conditional — absent when scope not performance-sensitive; missing output is NOT gap unless scope is performance-sensitive.
- Every E2+ finding MUST appear as explicit action or explicit rejection with rationale. Silent drops prohibited.
- Apply noise filtering: introduced/worsened by change? Fixable in same scope? Material impact? Fail any → downgrade or drop with rationale.
- No new findings — merge and deduplicate only.

## Output

Write to `{output_path}`. Structure:

1. **Actions** — finding summary, source advisor(s), evidence level, file + location, action description
2. **Rejected Findings** — E2+ not actioned, with rationale
3. **Advisory Only** — E0/E1 noted
4. **Conflicts** — `[CONFLICT]`-labeled with both positions
5. **Evidence Summary** — advisor | finding count | E-levels | conflicts

## Constraints

- Flag all conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip.
- Actions list consumed by polish-apply — keep unambiguous and actionable.
