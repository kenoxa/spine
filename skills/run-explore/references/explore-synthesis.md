# Explore: Synthesis

## Input

- `{file_pattern}` — glob for input files. **Required.** If missing: report error, do not guess.
- `{output_path}` — write synthesis here

Expected files match `{file_pattern}` within session directory.

**Existence verification**: Before merging, confirm every matched input file exists and is non-empty. Report absent files in output header.

## Instructions

Pure merge strategy:
1. Deduplicate findings by meaning — same insight from multiple scouts collapses to one entry citing all sources.
2. Rank by evidence level: E3 > E2 > E1 > E0.
3. Conflicting claims at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
4. Group by concern: code surface, docs/specs, external/upstream.
5. Preserve source provenance (file-scout, docs-explorer, navigator, augmented lens name).

## Output

Write to `{output_path}`. Include evidence summary table at end.

## Constraints

- Flag all conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
