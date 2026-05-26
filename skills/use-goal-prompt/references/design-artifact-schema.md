# Design Artifact Schema

Alignment surface assembled at Decide from `advise_artifact` + `council_artifact` + `frame_artifact`. Target: ≤200 lines. Direction and delivery slicing approved together.

## Schema

Write to `.scratch/<session>/design-artifact.md`.

### Required Sections

1. **Session References** — table linking to session artifacts (synthesis, batch outputs, source material)
2. **Current State** — how relevant code/system works now. Source: `frame_artifact.blast_radius` + orient findings. E2+ grounded.
3. **Desired End State** — what it should look like after. Source: `advise_artifact.recommendation`. Note council delta when it refines or overrides advise.
4. **Patterns to Follow** — codebase patterns to match. Each pattern cites file/symbol.
5. **Resolved Decisions** — design questions answered during advisory. Table: decision | resolution | source.
6. **Open Questions** — unresolved items. When council recommendation diverges from advise, surface as explicit user decision item. Plain English — no synthesis labels.
7. **Delivery Slices** — vertical testable slices ordered by dependency. Each slice: scope, what, entry criteria, exit validation, rollback.
8. **Constraints** — carried from `frame_artifact` + advisory.

### Assembly Rules

- Slice at module/seam level, never per-file.
- Each delivery slice MUST include entry and exit validation criteria.
- **No synthesis labels.** `[DIVERGENCE]`, `[CONFLICT]`, `${LETTER}-${kebab}` → plain-English questions.
- **Advise/council divergence is an Open Question, not a Resolved Decision.**
