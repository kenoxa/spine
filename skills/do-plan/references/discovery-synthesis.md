# Discovery: Synthesis

## Role

Merge all discovery subagent outputs into a single findings artifact. Deduplicate by meaning, rank by evidence level, preserve provenance from each scout.

## Input

Expected files (pattern: `.scratch/<session>/plan-discovery-*.md`):
- `plan-discovery-file-scout.md`
- `plan-discovery-docs-explorer.md`
- `plan-discovery-navigator.md`
- Any `plan-discovery-augmented-*.md` from variance lenses

**Existence verification**: Before merging, confirm every expected input file exists and is non-empty. If any file is missing or empty, report which files are absent in the output header. Do not proceed with partial merge without flagging gaps.

## Instructions

Pure merge strategy:
1. Deduplicate findings by meaning — same insight from multiple scouts collapses to one entry citing all sources.
2. Rank by evidence level: E3 > E2 > E1 > E0.
3. Conflicting claims at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
4. Group by discovery concern: code surface, docs/specs, external/upstream.
5. Preserve source provenance (file-scout, docs-explorer, navigator, augmented lens name).

## Output

Write to `.scratch/<session>/plan-synthesis-discovery.md`. Include evidence summary table at end.

## Constraints

- No envoy output in discovery phase — no corroboration clause applies.
- Flag all conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
