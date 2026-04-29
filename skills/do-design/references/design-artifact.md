# Design Artifact

Alignment surface assembled at Decide from `advise_artifact` + `council_artifact` + `frame_artifact`. Target: ≤200 lines. Direction and delivery slicing approved together.

## Schema

Write to `.scratch/<session>/design-artifact.md`.

### Required Sections

1. **Session References** — table linking to session artifacts (synthesis, batch outputs, source material)
2. **Current State** — how relevant code/system works now. Source: `frame_artifact.blast_radius` + orient findings. `council_artifact` may supplement with systemic risks identified by thinking-lens advisors. E2+ grounded.
3. **Desired End State** — what it should look like after. Source: `advise_artifact.recommendation`. When `council_artifact` Chairman recommendation refines or overrides the advise recommendation, note the delta here.
4. **Patterns to Follow** — codebase patterns to match. Source: `advise_artifact.constraints` + codebase evidence. Each pattern cites file/symbol.
5. **Resolved Decisions** — design questions answered during advisory. Source: `advise_artifact` convergence zones. Convergence confirmed in BOTH `advise_artifact` and `council_artifact` counts as high-confidence. Table: decision | resolution | source.
6. **Open Questions** — unresolved items. Source: `advise_artifact` divergence zones + `frame_artifact.key_unknowns`. When `council_artifact` recommendation diverges from `advise_artifact` recommendation, surface that divergence here as an explicit user decision item. Write each question in plain English; do NOT copy synthesis labels (see Assembly Rules).
7. **Delivery Slices** — vertical testable slices ordered by dependency. Each slice: scope (module/seam level — no per-file lists), what, entry criteria, exit validation, rollback. Prefer vertical slices (stub → wire → integrate) over horizontal layers (DB → service → API → frontend). When do-build depth = focused or task is small: "Slicing: N/A — single delivery."
8. **Constraints** — carried from `frame_artifact` + advisory.

### Assembly Rules

- Slice at module/seam level, never per-file — per-file plans are do-build Scope's job.
- Each delivery slice MUST include entry and exit validation criteria.
- Slices inform do-build Scope partitioning — they are not literal execution orders.
- Missing frame_artifact: derive Current State and Constraints from advisory context + codebase reads.
- **No synthesis labels in any section.** `[DIVERGENCE]`, `[CONFLICT]`, `${LETTER}-${kebab}`, `V__`/`R__` → plain-English questions or trade-off statements. Labels stay in raw synthesis batch files only.
- **Advise/council divergence is an Open Question, not a Resolved Decision.** When advise-synthesis and council-synthesis recommend different directions, do not auto-resolve — surface as a flagged Open Question for user decision at the Phase 4 gate.
