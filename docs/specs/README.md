# Design specs (index)

Numbered folders match tracking IDs (issue/ADR-style). One `spec.md` (+ optional `progress.md`) per topic.

**ID format:** `{YY}{WW}-<slug>` — 2-digit year + ISO week. Multiple specs per week allowed (different slugs, same prefix).

| ID | Spec | One-line |
|----|------|----------|
| **2612** | [thin-orchestrator/spec.md](2612-thin-orchestrator/spec.md) | Orchestrator SKILL.md = thin; behavior in per-role refs; dispatch vs mainthread |
| **2613** | [prototype-first-workflow/spec.md](2613-prototype-first-workflow/spec.md) | **Archived** — discuss/plan/execute removed; historical rationale only |
| **2614** | [evidence-fidelity/spec.md](2614-evidence-fidelity/spec.md) | Advisory + review paths (`{source_artifact_path}`, `{change_evidence_path}` / `review-change-evidence.md`, `use-envoy` plane) |
| **2614** | [implementer-standard-tier/spec.md](2614-implementer-standard-tier/spec.md) | Done — implementer Standard (`sonnet`); session vs implementer escalation docs |
| **2617** | [overnight-task-queue/spec.md](2617-overnight-task-queue/spec.md) | Draft — project-local DAG queue runner; fresh `claude -p` per task; restricted permission profile; Ralph-pattern inheritance |

**Related:** [skills-reference.md](../skills-reference.md), [architecture.md](../architecture.md).
