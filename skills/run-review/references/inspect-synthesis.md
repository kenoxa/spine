# Inspect: Synthesis

## Input

- `{inspector_output_paths}` — non-empty inspector output files
- `{verifier_output_path}` — verifier output file
- `{envoy_output_paths}` — 0-N envoy output files (via `{base}.*.md` glob)
- `{review_brief_path}` — review brief
- `{output_path}` — write synthesis here

## Instructions

**Existence check**: confirm every input file exists and is non-empty. Report absent/empty in output header.

Merge procedure:
1. **Deduplicate by meaning** — same finding from multiple inspectors collapses, citing all sources.
2. **Rank by evidence** — E3 > E2 > E1 > E0.
3. **Conflicting findings** at same evidence level → `[CONFLICT]` label. Do NOT resolve.
4. **Preserve provenance** — per finding, list originating inspector(s).
5. **Envoy skip notice** → omit from merge; note `[COVERAGE_GAP: envoy skipped]` in output header.
6. **Assign final severity** — E2+ required for blocking. For blocking findings, verify cited file+symbol references exist; unverifiable → demote to `should_fix`.
7. **Correctness assessment** — categorical confidence (high/med/low) + 1-2 sentence justification. Note envoy agreement/disagreement.

**Verifier VERDICT**: PASS = no flag. FAIL = blocking header. PARTIAL = header with reason.
Run-review has no re-entry — blocking findings surface to caller.

**Probe integration**: failed probe without Part 1 finding = `[B]`. E3 probe supporting E2 Part 1 finding → upgrade to E3.

## Output

Write to `{output_path}`.

## Constraints

- Flag conflicts, never resolve them.
- Missing/empty inputs = reportable gap in output header, not a failure.
- Preserve per-agent provenance on every finding (inspector(s), verifier, envoy).
- No file writes beyond the output artifact.
