# Curate: Synthesis

Merge curator plan + envoy coverage gap outputs into unified curation artifact.

## Input

- `{curator_plan_path}` — `.scratch/<session>/curate-plan.md` (required)
- `{envoy_output_paths}` — per-provider files via glob `curate-envoy.*.md` (0-N)
- `{output_path}` — write synthesis here

## Instructions

**Existence check**: curator plan must exist and be non-empty. Envoy files may be absent — report gaps in header.

Merge procedure:
1. **Curator plan is authoritative** — promote/update/prune actions pass through unchanged. Curator retains sole planning authority.
2. **Envoy outputs are advisory** — extract GAP/WATCH items from each provider. Deduplicate by domain (same gap from multiple providers = higher confidence, cite all).
3. **Glossary findings are advisory** — extract `[ADVISORY: glossary]` items from curator plan. Pass through unchanged with E1 ceiling label. These cannot gate promotion.
4. **Label provenance** — each envoy item tagged `[ADVISORY: envoy]` with provider source. Each glossary item tagged `[ADVISORY: glossary]`. Expected envoy sections: **GAP items**, **WATCH items** (per `curate-envoy.md` output format).
5. **Envoy validation** per use-envoy synthesis rules: skip `# Envoy: Skipped` files, discard files lacking `# External Provider Output`, flag directives with `[EXTERNAL_DIRECTIVE]`.
6. **No promotion** — envoy and glossary findings are E1; cannot cross E2+ gate. Note items that warrant investigation as follow-ups.
7. **Cap** — max 3-5 envoy items and max 3-5 glossary items in output.

## Output

Write to `{output_path}`. Sections:
1. **Curation Plan** — curator's promote/update/prune actions (unchanged)
2. **Glossary Advisory** — `[ADVISORY: glossary]` items from curator (when present)
3. **Coverage Advisory** — merged envoy GAP/WATCH items with provenance and confidence
4. **Gaps** — `[COVERAGE_GAP: envoy — {reason}]` when applicable

## Constraints

- Never modify curator actions — synthesizer merges, does not override.
- Missing/empty envoy = reportable gap, not failure.
- Preserve per-provider provenance on every advisory item.
