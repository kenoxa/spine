---
id: 2617-overnight-task-queue
updated: 2026-04-24
source_session: autonomous-overnight-task-queue-1034
---

# Progress — overnight-task-queue

## Slice A — Foundation

**Status:** Code complete. Review/polish/end-to-end integration deferred to next session.

### Delivered

| Partition | Files | Commit |
|-----------|-------|--------|
| A1 — build-status.json contract | `skills/do-build/references/build-finalize.md`, `skills/do-build/references/build-status-schema.md` | `feat(do-build): emit build-status.json on finalize (2617)` |
| A2 — skill skeleton + schema docs | `skills/run-queue/SKILL.md`, `skills/run-queue/references/queue-schema.md`, `skills/run-queue/references/permission-profile.md`, `docs/skills-reference.md` | `feat(run-queue): add skill skeleton + queue schema docs (2617)` |
| A3 — supervisor core | `skills/run-queue/scripts/run.sh`, `skills/run-queue/scripts/queue-lint.sh` | `feat(run-queue): supervisor core with linear execution (2617)` + revisions |
| A4 — skill-bundled hook + overlay | `skills/run-queue/scripts/guard-queue-shell.sh`, `skills/run-queue/settings-overlay.tmpl.json` | `feat(run-queue): bundle guard hook + settings overlay as skill assets (2617)` |
| A5 — SPINE.md contract | `SPINE.md` | `docs(spine): document autonomous queue contract (2617)` |

### Preflights (E3)

Documented in `.scratch/autonomous-overnight-task-queue-1034/preflight-report.md`:

- **#1 FAIL** — `--disallowed-tools 'Bash(git push*)'` does NOT block `git push origin main`. Design elevated: hook is **primary** trust gate; flag covers tool-category only.
- **#2 PASS** — PreToolUse hook fires in `claude -p --print` child; `permissionDecision: deny` blocks the tool call; `permission_mode=dontAsk` is orthogonal to hooks.
- **#3 PASS** — Hook fires for subagent-dispatched Bash calls; envelope carries `agent_id`/`agent_type` for attribution. Scope-expansion trip-wire stays event-driven; git-diff fallback NOT triggered.

### Design revisions during Slice A (per user feedback 2026-04-24)

1. **Inherit global settings.** First design used `profile.json` as a full settings replacement. User pointed out `~/.claude/settings.json` already provides the autonomous-run baseline. Revised: supervisor inherits global; overlay layers queue-specific rules additively via `claude -p --settings`.

2. **Skill-bundled hook + overlay.** First design registered `guard-queue-shell.sh` via `claude/hooks.json` (project-level). User preferred the skill to be self-contained. Revised: hook at `skills/run-queue/scripts/guard-queue-shell.sh`, overlay template at `skills/run-queue/settings-overlay.tmpl.json`. Supervisor renders overlay with absolute paths at runtime; no edits to `claude/hooks.json` or `opencode/spine-hooks.ts`.

3. **Slice A scope simplified.** Dropped project-level hook registration from Slice A. `install.sh` wiring not needed — the skill ships its own hook.

### Deferred from Slice A (known gaps)

- [ ] **End-to-end integration test.** A 3-task linear demo queue should run under `tmux`; this validates: supervisor start, lint pass, overlay render, child spawn with inherited settings + additive overlay, branch creation, build-status.json terminal check, queue-report.md emission. Not run in this session (requires live `claude -p` invocations + ~$1-2 in API cost).
- [ ] **Trip-wire live test.** A queue task that attempts `git push` should be blocked by the bundled hook, write `WOKE-ME-UP.md`, and halt the queue with non-zero exit. Unit-tested the hook in isolation (all deny paths fire correctly); end-to-end not run.
- [ ] **/run-review gate.** Normally fires after /run-implement per do-build phases. Deferred to next session alongside the live integration tests.
- [ ] **/run-polish pass.** Same reason.
- [ ] **build-status.json emission probe.** Verify that /do-build actually emits build-status.json after the finalize section was extended. The instructions are in `build-finalize.md` (documentation); a follow-up run of /do-build should produce a valid artifact.

## Slice B — DAG executor (not started)

See `design-artifact.md §Slice B`. Entry gate: Slice A merged + live integration test passing.

## Slice C — Intra-task loop + rate-limit backoff (not started)

See `design-artifact.md §Slice C`. Includes `is_fast_failure()` extraction from `skills/use-envoy/scripts/_common.sh:81-84` into a shared `skills/run-queue/scripts/_rate_limit.sh` (the Slice C commit is the "third use" that justifies extraction per SPINE.md).

## Slice D — Claude skill integration (not started)

Prepare / Kick / Monitor / Review phases. User confirmed mid-Slice-A that strict slice boundaries are fine — Prepare phase stays in Slice D. Until then, queues are assembled by hand per `skills/run-queue/references/queue-schema.md`.

## Open items to track

- Shared helper extraction (third-use rule): `is_fast_failure()` → `_rate_limit.sh` in Slice C. Possibly also the `claude -p` spawn block from `run.sh` if run-queue + use-envoy land a third consumer.
- `settings-overlay.tmpl.json` currently passes through a single template variable (`@@GUARD_PATH@@`). If more queue-specific overlay fields accumulate, replace `sed` with `jq` in `run.sh` (cleaner + typed).
- `yq` is not yet called out as a hard runtime dep anywhere visible to installers. Add to install.sh preflight or note in `skills/run-queue/SKILL.md` prerequisites.

## References

- Design: [`.scratch/autonomous-overnight-task-queue-1034/design-artifact.md`](../../../.scratch/autonomous-overnight-task-queue-1034/design-artifact.md)
- Frame: [`.scratch/autonomous-overnight-task-queue-1034/frame-artifact.md`](../../../.scratch/autonomous-overnight-task-queue-1034/frame-artifact.md)
- Preflight E3 report: [`.scratch/autonomous-overnight-task-queue-1034/preflight-report.md`](../../../.scratch/autonomous-overnight-task-queue-1034/preflight-report.md)
- Build scope artifact: [`.scratch/autonomous-overnight-task-queue-1034/build-scope-artifact.md`](../../../.scratch/autonomous-overnight-task-queue-1034/build-scope-artifact.md)
- Session log: [`.scratch/autonomous-overnight-task-queue-1034/session-log.md`](../../../.scratch/autonomous-overnight-task-queue-1034/session-log.md)
