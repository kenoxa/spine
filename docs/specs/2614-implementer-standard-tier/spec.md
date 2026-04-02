---
id: 2614-implementer-standard-tier
status: implemented
updated: 2026-04-02
---

# Implementer Standard Tier + Session Model Documentation

## Goal

Pin `agents/implementer.md` from Adaptive (`model: inherit`) to Standard (`model: sonnet`). Update all affected documentation in the same change. Produce end-user-facing guidance accessible to all co-workers and AI providers.

## Result

- `agents/implementer.md` — `model: sonnet`
- `docs/architecture.md` — tier table aligned with agent files; Standard floor + synthesizer Frontier rationale
- `docs/model-selection.md` — implementer Standard, escalation split (session vs implementer workload)
- `README.md` — model selection detail: escalation triggers + link to `model-tier-assignments.md`
- `docs/model-tier-assignments.md` — current assignments, two escalation sections
- `docs/skills-reference.md` — agent tier table corrected (synthesizer was already Frontier in repo)

## Design resolutions (2026-04-02)

Independent-advisor review (evidence tags use Spine E0–E3: E0 intuition, E1 documented reference, E2 code/structural, E3 executed/measured).

1. **Rationale placement (E1–E2)** — Keep `architecture.md` principle-level (gate hierarchy, Standard floor, pointer to numbers). Put SWE-Bench deltas, cost, and session-vs-subagent economics in `model-selection.md` + `model-tier-assignments.md` so benchmark revisions do not require rewriting the architecture narrative.
2. **Escalation (E1–E2)** — Session (mainthread) triggers and implementer-workload triggers stay in separate sections in `model-tier-assignments.md`; `model-selection.md` holds the detailed escalation subsection; README keeps a one-paragraph pointer. Reduces confusion between “upgrade my chat” and “heavy implementation partition.”
3. **Synthesizer vs implementer (E1–E2)** — In-repo `agents/synthesizer.md` is Frontier (`opus`), not Adaptive. Frontier merge step + Standard implementation is intentional role separation (merge authority vs scoped edits), not an accidental split to fix in the same change.
