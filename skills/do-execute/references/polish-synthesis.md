# Polish: Synthesis

## Role

Merge all polish advisory outputs into a prioritized action list. Deduplicate cross-advisor findings, rank by evidence, surface unresolved conflicts for the orchestrator. No envoy in polish — all sources are internal base agents.

## Input

Expected files (pattern: `.scratch/<session>/execute-polish-*.md`):
- `execute-polish-conventions-advisor.md`
- `execute-polish-complexity-advisor.md`
- `execute-polish-efficiency-advisor.md`
- Any `execute-polish-augmented-{lens}.md` from variance lenses

**Existence verification**: Before merging, confirm every expected input file exists and is non-empty. Report absent or empty files in the output header. Do not skip synthesis — proceed with available inputs and flag gaps.

## Instructions

Merge strategy:
1. Deduplicate findings by meaning — same insight from multiple advisors collapses to one entry citing all sources.
2. Rank by evidence level: E3 > E2 > E1 > E0.
3. Conflicting findings at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
4. Preserve per-advisor provenance (conventions-advisor, complexity-advisor, efficiency-advisor, augmented lens name).
5. Every E2+ finding MUST appear in output as an explicit action or an explicit rejection with rationale. Silent drops are prohibited.

## Output

Write to `.scratch/<session>/execute-synthesis-polish.md`. Structure:

1. **Actions** — ordered list of apply actions; each entry: finding summary, source advisor(s), evidence level, file + line range, action description
2. **Rejected Findings** — E2+ findings not actioned; each entry: finding summary, rejection rationale
3. **Advisory Only** — E0/E1 findings noted but not actioned; no rejection rationale required
4. **Conflicts** — `[CONFLICT]`-labeled entries with both positions; orchestrator resolves
5. **Evidence Summary** — table: advisor | finding count | E-levels present | conflicts

## Constraints

- No corroboration rule — all sources are internal base agents; no external provider in this phase
- Flag all conflicts; never resolve them
- Missing inputs are a reportable gap, not a reason to skip synthesis
- Actions list is consumed directly by the polish-apply step — keep entries unambiguous and actionable
