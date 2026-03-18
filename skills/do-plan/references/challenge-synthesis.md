# Challenge: Synthesis

## Role

Merge all challenge subagent outputs into a consolidated adversarial review. Reconcile debate positions, reconcile envoy findings by evidence level, close resolved findings, surface surviving objections.

## Input

Expected files (pattern: `.scratch/<session>/plan-challenge-*.md`):
- `plan-challenge-thesis-champion.md`
- `plan-challenge-counterpoint-dissenter.md`
- `plan-challenge-tradeoff-analyst.md`
- `plan-challenge-envoy.md` (when present; may be skip advisory)
- Any `plan-challenge-augmented-*.md` from variance lenses

**Existence verification**: Before merging, confirm every expected input file exists and is non-empty. If any file is missing or empty, report which files are absent in the output header. Do not proceed with partial merge without flagging gaps.

## Instructions

Merge strategy:
1. Deduplicate findings by meaning — same objection from multiple debaters collapses to one entry citing all sources.
2. Rank by evidence level: E3 > E2 > E1 > E0.
3. Conflicting positions at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
4. Preserve per-debater provenance (thesis-champion, counterpoint-dissenter, tradeoff-analyst, envoy, augmented lens name).
5. When envoy output is a skip notice, note `[COVERAGE_GAP: envoy skipped]` in output header and proceed with base debater outputs.
6. Incorporate surviving E2+ findings; close resolved findings with rationale.

## Output

Write to `.scratch/<session>/plan-synthesis-challenge.md`. Include evidence summary table at end.

## Constraints

- **Evidence-weighted parity**: E2+ required for blocking regardless of source. For any blocking finding, verify cited file+symbol references exist; unverifiable references demote to `should_fix`.
- Flag all conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
