# Template: Migrations

**When**: a dependency upgrade, schema migration, data migration, routing refactor, or platform migration with zero downtime tolerance and a tested rollback path at every step.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**Must-ask inputs**: `[migration_type]`, `[cutover_strategy]`, `[observation_window]`, `[rollback_sla]`. Everything else below is a scaffold — adapt it to the task.

```
GOAL:
Execute a [migration_type] migration with zero downtime tolerance and a tested rollback path at every step.

CONTEXT:
Existing system with consumers that must continue working through the migration.
Migration type: [migration_type] — dependency upgrade / schema / data / routing / platform.
Cutover strategy: [cutover_strategy] — dual-write / dual-read / blue-green / canary / feature flag.
Observation window: [observation_window].
Rollback SLA: [rollback_sla].
Build discipline: See `skills/use-goal-prompt/references/phase-discipline-build.md`. MANDATORY: load before proceeding. In autonomous (/goal) flows, user-STOP gates become emit-artifact-and-halt signals.
SESSION: Use `/use-session`; maintain session.json + events.jsonl + session-log.md. If worktree needed, use `/use-worktree` attach, not fork.

CONSTRAINTS:
No big-bang cutovers. Dual-write, dual-read, blue-green, canary, or feature flag only.
For schema: write up + down in one commit; test both.
For data: validate row counts, checksums, encoding, timezone handling, and referential integrity at source and destination. Dry-run on a representative sample before the full migration.
For dependency upgrades: pin the new version, run the full test suite, audit the changelog for breaking changes.
For platform: build the new path parallel to the old. Old path stays runnable until the observation window passes.

PRIORITY:
1. Zero downtime for consumers
2. Tested rollback at every step
3. Old path removed only after observation window confirms stability

PLAN:
Map every consumer of the thing being migrated.
Define the dual-write or dual-read window with explicit duration.
For data migrations: define the sampling strategy, the integrity checks, and the cutover criteria before any data moves.
Restate the cutover strategy before the first migration step.
Execute steps incrementally. Observe at each step before continuing.

DONE WHEN:
Every consumer migrated to the new path.
Dual-write or dual-read window observed long enough to confirm parity.
Down migration tested, not just written.
For data migrations: source-to-destination integrity checks (row counts, checksums, encoding, timezones, referential integrity) all passed.
Old path removed only after the observation window passed.
Observability hooks confirm the new path is healthy under real traffic.

VERIFY:
Test the down migration against a copy of production data or its closest available equivalent.
For data migrations: run integrity checks on the migrated data and compare against the source.
Confirm observability hooks fire on the new path under load.
Confirm parity between old and new paths during the dual window.
State any verification that could not run and why.

OUTPUT:
Consumer map.
Cutover plan with explicit dual-window definition.
For data migrations: integrity check report (sample dry-run and full migration).
Forward and rollback diffs for the first step.
Observability hook list with the signal each one watches.

STOP RULES:
Halt when parity between old and new paths cannot be confirmed.
Halt when data integrity checks fail or are skipped.
Surface ranked proposals when the cutover strategy is ambiguous for a given consumer class.
Do not remove the old path until the observation window has fully passed.
Do not skip the down migration test.
Do not skip the data-migration dry-run.
Build-phase discipline stops: See `skills/use-goal-prompt/references/phase-discipline-build.md`. MANDATORY: load `skills/use-goal-prompt/references/phase-discipline-build.md` before proceeding.
```
