# Evidence Fidelity (Advisory + Review + Envoy Contract)

Consolidated spec for multi-agent evidence flow: **Slice 1** (advisory), **Slice 2** (review), **Slice 3** (shared envoy rules). Implementation is skill/reference contracts — no runtime code in this repo.

## Why slices existed

Work was staged so advisory wiring could ship first with a narrow blast radius, then review transport, then cross-cutting `use-envoy` language. All three are now specified together; implement in any order when touching each surface.

---

## Slice 1 — Advisory source artifact

**Problem**: `advise-synthesis` merged batch outputs without a first-class path to the authoritative decision object.

**Decision**: Orchestration passes `{source_artifact_path}` to every advisory role and to synthesis; `advise-envoy` lists the same path first. See `skills/run-advise/references/advise-synthesis.md`, `advise-envoy.md`, `skills/run-advise/SKILL.md`, `skills/do-design/SKILL.md`.

**Acceptance**: Synthesis and envoy reference the same repo-relative source file; roles stay specialized.

---

## Slice 2 — Review change evidence

**Problem**: `inspect-envoy` used inline `review_brief` plus path-only diff lists — external providers could lack real change surface (same class of loss as advisory before Slice 1).

**Decision**:

- Gate A unchanged: `review-brief.md` per `template-review-brief.md`.
- **Gate A2 (recommended)**: `review-change-evidence.md` per `review-change-evidence-schema.md` — unified diff / patch / excerpts.
- `inspect-envoy` uses repo-relative `{review_brief_path}` and `{change_evidence_path}`; same paths for `inspect-synthesis`, verifier, and risk-reviewer when present.
- If change evidence is missing, deterministic coverage-gap string in the envoy prompt (not silent).

**Files**: `skills/run-review/references/inspect-envoy.md`, `inspect-synthesis.md`, `inspect-verifier.md`, `inspect-risk-reviewer.md`, `scope-context.md`, `review-change-evidence-schema.md`, `skills/run-review/SKILL.md`.

---

## Slice 3 — Shared envoy evidence plane

**Problem**: Per-phase contracts were implicit; missing evidence could degrade silently.

**Decision**: `skills/use-envoy/SKILL.md` defines a **per-phase evidence plane** table (`run-advise` vs `run-review`) and rules: required vs recommended paths, deterministic `[COVERAGE_GAP: ...]` on miss — no silent substitution of summary-only context.

---

## Non-goals (all slices)

- Provider count, selective fan-out, or model mix changes
- Broadly loosening role prompts into generic analysts
- A repo-wide evidence-manifest framework

## Validation

- Slice 1: representative `run-advise` with `{source_artifact_path}` end-to-end.
- Slice 2: representative `run-review` with `review-change-evidence.md` populated; confirm envoy prompt cites paths and synthesis loads both brief and change evidence.
- Slice 3: confirm `use-envoy` + phase refs agree on gap strings when paths are missing.

## Rollback

Revert the touched skill/reference files; no migrations.
