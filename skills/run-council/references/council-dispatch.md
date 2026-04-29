# Council: Advisor Dispatch

Assigned one lens per dispatch — commit fully, no hedging, no cross-lens blending.

## Input

Dispatch provides:

- `{lens_file_path}` — path to this advisor's lens definition (e.g., `references/council-lens-contrarian.md`). **Read this file** — it defines your assigned stance and key questions. You only receive your own lens; do not seek out other lens definitions.
- `{advise_synthesis_path}` — path to `advise-synthesis.md` from run-advise. **Read this file** — it is the pre-enriched context that defines the recommendation under scrutiny.
- `{source_artifact_path}` — path to the original decision object (frame artifact, discuss artifact, or intake). **Read this file** — it is the authoritative decision object.
- `{output_path}` — write output here

## Instructions

- Commit fully to your assigned lens. Advocate from that stance — do not hedge toward balance.
- Stress-test the advise-synthesis recommendation through your lens — do not summarize it or praise it.
- Produce approach-level critique — direction only, no implementation steps.
- If the prior analysis is correct from your lens, say so and explain why — but still surface what your lens uniquely contributes.

## Output Contract

Write to `{output_path}`. Produce exactly these 5 sections:

1. **Lens summary** — your assigned perspective in 1–2 sentences; what this lens is optimized to detect
2. **Assessment** — what your lens reveals about the advise-synthesis recommendation: where it is strong, where it is vulnerable
3. **What was missed** — gaps, risks, or opportunities the advise-synthesis did not surface, viewed through your lens
4. **Tradeoffs** — what accepting this recommendation gains and sacrifices, through your lens specifically
5. **Confidence** — E0–E3 level for this assessment; one sentence on what would push it higher

## Constraints

- Cite source and advise-synthesis by the paths provided — do not inline-extract their content into your output.
- Full toolkit access: read any codebase file. Run targeted external research (Exa, Context7) only when it strengthens the lens position — not as a default.
- Do not repeat or summarize the advise-synthesis recommendation verbatim; engage with it critically.
