# Template: Planning & Documentation

**When**: a brief is confirmed and the next step is producing the doc set (roadmap + decisions + risks, plus backward docs if extending) that the build phase will execute against.

**User-specific slots**: `[brief_reference]`, `[codebase_state]`, `[doc_convention]`.

```
GOAL:
Produce cross-linked planning docs (roadmap + decisions + risks) that drive every implementation step. Add current-state docs if extending. Size to project scale.

CONTEXT:
Brief confirmed: [brief_reference].
Codebase: [codebase_state] — empty (greenfield) or present (extending).
Doc convention: [doc_convention] — user-specified, or ask for a recommendation sized to scale and domain.
Use the `/do-design` skill to produce the doc set.

CONSTRAINTS:
- Use the user's doc convention; no invented filenames.
- Don't invent scope. Surface gaps; do not fill them.
- Every implementation step references its governing decision(s).
- Every decision the build phase needs exists before build starts.
- Diagrams generated from the actual dependency graph, not from memory.
- Every doc carries owner, last-updated, stale-by date.
- Size depth to scale; flag drift between intent and behavior.

PRIORITY:
1. Forward docs drive end-to-end implementation
2. Backward docs complete before structural changes
3. Every seam cross-linked

PLAN:
Confirm doc convention. If none, recommend one sized to scale and domain.

Forward docs (always):
- Roadmap: milestones in order with exit criteria. Each milestone decomposed into ordered implementation steps with their own exit criteria, decision references, and required tests.
- Decisions: every architectural choice with alternatives, reasoning, revisit trigger.
- Risks: failure modes with blast radius, mitigation, owner, monitoring signal.

Backward docs (if extending):
- Architecture: entry-point map, module responsibilities, dependency-graph diagram.
- Tribal knowledge: undocumented assumptions, historical context, debt, change-impact matrix.
- APIs: version history, deprecation, SLA where applicable.
- Production-critical: on-call ownership per component.

Domain extensions (if applicable): security/compliance for regulated industries, runbook for ops-heavy, glossary for cross-team, model/dataset cards for ML.

Cross-link: each step → its decisions; each milestone with risk → risks; each module with drift → tribal.

Before declaring complete: walk every roadmap step, list its decisions, flag missing, resolve all flags.

DONE WHEN:
- Every milestone has exit criteria and ordered implementation steps with decision references.
- Every decision the roadmap references exists with a revisit trigger.
- Every risk has owner and monitoring signal.
- If extending: entry points mapped, modules documented, drift flagged.
- Every seam cross-linked.
- Gaps surfaced explicitly.
- Build-readiness walk performed: every step listed with its decisions; nothing missing.

VERIFY:
- Walk cross-links; confirm each resolves.
- Validate backward-doc diagrams against the code.
- State unverifiables and why.

OUTPUT:
- Doc set (user filenames, one-line purpose each).
- Full roadmap with step-level decomposition; architecture doc if extending.
- Cross-link map (step → decisions).
- Gaps list.
- Build-readiness walk: every step listed with its decisions; nothing missing.

STOP RULES:
Halt when the brief is missing required information.
Halt when a step references a decision not in the decisions doc.
Halt when a load-bearing seam cannot be confirmed against the code.
Do not invent decisions, risks, milestones, steps, responsibilities, or filenames.
Do not declare complete until the build-readiness walk is performed and clean.
Do not exceed depth appropriate to project scale.
```
