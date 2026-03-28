# Advise: Synthesis

Merge consultant + envoy outputs into a directional recommendation. Surface disagreement as signal -- never auto-resolve.

## Input

Dispatch provides:
- `{file_pattern}` -- glob pattern for consultant output files
- `{output_path}` -- write synthesis here

Expected files matching `{file_pattern}`:
- `advise-batch-rigorous.md`
- `advise-batch-creative.md`
- `advise-batch-navigator.md` (external research: library docs, code patterns, ecosystem alternatives)
- `advise-batch-envoy.md` or `advise-batch-envoy.<provider>.md` per mode (when present; may be skip advisory)

Verify all expected inputs exist and are non-empty; flag gaps in output header.

## Instructions

Merge strategy -- disagreement-as-signal:

1. **Convergence zones**: where multiple angles agree = high confidence. Cite all sources.
2. **Divergence zones**: where angles disagree = surface to user with both positions and evidence. Do NOT auto-resolve. Tag with `[DIVERGENCE]`.
3. Rank by evidence level: E3 > E2 > E1 > E0. Same level = `[CONFLICT]` with provenance.
4. Preserve per-consultant provenance (rigorous, creative, envoy).
5. Envoy skip notice: `[COVERAGE_GAP: envoy skipped]` in header; proceed with base outputs.

## Falsification

Embed 3 falsification bullets: "What would invalidate this approach?" Drawn from consultant invalidation conditions + synthesis judgment. These are part of the recommendation, not a separate phase.

## Output

Write to `{output_path}` as `advise_artifact`. Structure:

1. **Recommendation** -- synthesized direction with convergence/divergence map
2. **Constraints** -- MUST/SHOULD/MAY directives (<=10 total). Preserve `researcher-upstream` and `navigator-external` provenance tags
3. **Tradeoffs** -- consolidated gains and sacrifices across angles
4. **Rejected alternatives** -- what was considered and why not
5. **Confidence** -- overall with per-zone breakdown (convergence = high, divergence = flagged)
6. **Falsification risks** -- 3 bullets: what would make this approach wrong
7. **Scope hints** -- candidate files/modules, estimated size (small/medium/large)
8. **Evidence summary** -- table of sources and evidence levels

## Constraints

- **Evidence-weighted parity**: E2+ required for blocking regardless of source.
- Flag all divergences; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
- Do not produce implementation plans -- directional recommendation only.
