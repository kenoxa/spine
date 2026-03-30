# Design Artifact

Alignment surface assembled at Decide from `advise_artifact` + `frame_artifact`. Target: ≤200 lines. Direction and delivery slicing approved together.

## Schema

Write to `.scratch/<session>/design-artifact.md`.

### Required Sections

1. **Session References** — table linking to session artifacts (synthesis, batch outputs, source material)
2. **Current State** — how relevant code/system works now. Source: `frame_artifact.blast_radius` + orient findings. E2+ grounded.
3. **Desired End State** — what it should look like after. Source: `advise_artifact.recommendation`.
4. **Patterns to Follow** — codebase patterns to match. Source: `advise_artifact.constraints` + codebase evidence. Each pattern cites file/symbol.
5. **Resolved Decisions** — design questions answered during advisory. Source: `advise_artifact` convergence zones. Table: decision | resolution | source.
6. **Open Questions** — unresolved items. Source: `advise_artifact` divergence zones + `frame_artifact.key_unknowns`.
7. **Delivery Slices** — vertical testable slices ordered by dependency. Each slice: scope (module/seam level — no per-file lists), what, entry criteria, exit validation, rollback. Prefer vertical slices (stub → wire → integrate) over horizontal layers (DB → service → API → frontend). When do-build depth = focused or task is small: "Slicing: N/A — single delivery."
8. **Constraints** — carried from `frame_artifact` + advisory.

### Assembly Rules

- Slice at module/seam level, never per-file — per-file plans are do-build Scope's job.
- Each delivery slice MUST include entry and exit validation criteria.
- Slices inform do-build Scope partitioning — they are not literal execution orders.
- Missing frame_artifact: derive Current State and Constraints from advisory context + codebase reads.
