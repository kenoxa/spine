# Template: Build & Implementation

**When**: the planning doc set exists (roadmap + decisions + risks) and the next step is end-to-end implementation of every milestone in order — not a slice or prototype.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**Must-ask inputs**: `[planning_docs_location]`, `[codebase_state]`, `[scope_label]`. Everything else below is a scaffold — adapt it to the task.

```
GOAL:
Implement every milestone in roadmap order. Ship the full system. Every architectural decision traces to the decisions doc.

CONTEXT:
Planning doc set (roadmap, decisions, risks) at [planning_docs_location] in the user's convention.
Codebase: [codebase_state] — empty (greenfield) or present (extending).
Scope: [scope_label] — full-system / subsystem / module. Not a slice or prototype.
Build discipline: See `skills/use-goal-prompt/references/phase-discipline-build.md`. MANDATORY: load before proceeding. In autonomous (/goal) flows, user-STOP gates become emit-artifact-and-halt signals.
SESSION: Use `/use-session`; maintain session.json + events.jsonl + session-log.md. If worktree needed, use `/use-worktree` attach, not fork.

CONSTRAINTS:
- No architecture or decisions outside the decisions doc.
- No scope beyond the roadmap.
- Every file traces to a milestone or decision.
- Milestones execute in roadmap order; exit criteria gate the next.

PRIORITY:
1. Complete implementation of every milestone in the roadmap
2. Architectural fidelity to the decisions doc at every step
3. Test coverage growing with each milestone, not deferred to the end

PLAN:
Read roadmap, decisions, risks before writing code.
Restate every milestone and its exit criteria.
For each milestone:
- Restate its exit criteria and dependent decisions.
- Build components + cover with tests for the exit criteria.
- Run full suite; confirm clean exit before the next milestone.
- Surface any decision proved insufficient, ambiguous, or contradicted.
Update decisions/risks docs when reality forces deviation. Never silently deviate.

DONE WHEN:
- Every milestone complete with exit criteria met.
- Tests cover every milestone's exit criteria.
- Full system runs end-to-end; no mocks block core paths.
- Every deviation captured in decisions or risks doc.

VERIFY:
- Run the system end-to-end; confirm exit criteria per milestone.
- Run the test suite; confirm coverage spans all milestones.
- Trace every architectural choice in code to the decisions doc.
- Walk risks doc; each mitigation implemented or accepted.
- State anything unverifiable and why.

OUTPUT:
- Per-milestone delivery: exit criteria, components built, tests written, exit confirmed.
- Full diff and test suite for the system.
- Updated decisions/risks docs reflecting deviations.

STOP RULES:
Halt when the planning doc set is absent or incomplete. Surface what's missing and recommend running the planning prompt first, OR surface ranked proposals for the missing decisions and proceed only with explicit user approval.
Halt when reality contradicts a decision and the user must adjudicate. Surface the contradiction.
Halt on scope expansion beyond the roadmap.
Halt when a milestone's exit criteria cannot be met without violating a decision or a constraint.
Do not invent architecture. Do not skip milestones. Do not defer test coverage to the end.
Build-phase discipline stops: See `skills/use-goal-prompt/references/phase-discipline-build.md`. MANDATORY: load `skills/use-goal-prompt/references/phase-discipline-build.md` before proceeding.
```
