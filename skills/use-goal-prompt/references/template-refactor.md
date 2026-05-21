# Template: Refactoring & Restructuring

**When**: existing codebase has structural debt and the user wants a surgical refactor — smallest possible diff, zero behavior change.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**Must-ask inputs**: `[structural_goal]`, `[target_scope]`, `[test_suite_status]`. Everything else below is a scaffold — adapt it to the task.

```
GOAL:
Execute a surgical refactor that achieves [structural_goal] with the smallest possible diff and zero behavior change.

CONTEXT:
Existing codebase with structural debt.
Target scope: [target_scope].
Test suite: [test_suite_status] — present / absent / insufficient. If absent or insufficient, surface this before proceeding.
SESSION: Use `/use-session`; maintain session.json + events.jsonl + session-log.md. If worktree needed, use `/use-worktree` attach, not fork.

CONSTRAINTS:
Preserve behavior. Do not introduce features.
Never co-mingle behavior changes with structural changes.
Every commit leaves the build green and the test suite passing.
Reject the request if structural and behavioral changes are entangled and cannot be separated.

PRIORITY:
1. Behavior preservation
2. Smallest sufficient diff
3. Independently revertable commits

PLAN:
Map the call graph before touching code.
Identify every public API surface affected.
For each affected surface: confirm backward compatibility or flag as breaking.
Refactor in layered commits: pure renames first, then signature changes, then logic moves.
Restate the structural goal before the first non-trivial commit.

DONE WHEN:
Behavior provably unchanged (test suite green pre and post).
No breaking change to public APIs unless explicitly flagged and approved.
Every commit independently revertable.
Call graph map matches the new structure.
No dead code introduced or left behind.

VERIFY:
Run build, lint, typecheck, full test suite after each commit.
Confirm each commit can be reverted in isolation.
State any verification that could not run and why.

OUTPUT:
Call graph and surface map.
Ordered commit plan with rollback steps for each.
First commit's diff.
Summary of breaking-change flags if any.

STOP RULES:
Halt when the test suite is absent or insufficient to detect behavior change. Surface this and require explicit user acknowledgment that behavior change cannot be detected before proceeding. Do not silently lower the verification bar.
Halt on entanglement of structural and behavioral changes.
Surface ranked proposals when the structural goal could be achieved in multiple shapes.
Do not proceed to the next commit until the current commit is approved.
Do not expand scope beyond the stated target.
```
