# Monitor Phase

**Invariants: Monitor writes NO files at v1 (stateless file-reading only). Trip-wire (`WOKE-ME-UP.md` presence) is the authoritative "attention required" signal, independent of cadence guidance.**

Phase goal: stateless check-in on a running queue — read current state, surface the trip-wire if present, report per-task progress, and suggest when to check back.

## Steps

### 1. Files to read

Read these files from `<queue-dir>`:

| File | Purpose | How to Read |
|------|---------|-------------|
| `queue-state.json` | Machine view — current task, branch per task, `base_rev` | `jq '.' <queue-dir>/queue-state.json` |
| `queue-log.md` | Append-only supervisor log — task transitions, rate-limit events | `tail -40 <queue-dir>/queue-log.md` |
| `WOKE-ME-UP.md` | Trip-wire file — present only if a permission deny fired | Check existence, then read verbatim if present |

Read `queue-state.json` via `jq`, not prose grep. The file is machine-written JSON; string-scanning for task names is fragile.

### 2. Current-state output

Report for each task in the queue (derived from `queue-state.json`):

- Task id + current status (`pending`, `pending_retry`, `complete`, `blocked`, `skipped`)
- Current iteration (read from `queue-log.md` — look for `task=<id> iter=N` lines, or count files in `.scratch/queue-<run_id>-<task_id>/iterations/`)
- Branch name if created
- Last relevant line from `queue-log.md` for running or recently-completed tasks

**If `WOKE-ME-UP.md` exists**, show it first, prominently, before the per-task table:

```
TRIP-WIRE FIRED — WOKE-ME-UP.md present
<verbatim contents of WOKE-ME-UP.md>
```

Do not proceed to per-task reporting until the user has seen the trip-wire contents.

### 3. When to check back

Mid-task (iter 1–3 of 10): check back in ~15–30 min. Near-end iterations (iter ≥ 8/10) or last task: ~5 min. `WOKE-ME-UP.md` present: act now — do not wait.

These are coarse floor estimates. Rate-limit backoff can extend any task by up to 2 hours (120 s → 2 h cap) — and if the 5h rolling or weekly request window is exhausted, the supervisor sleeps through the window-reset rather than failing the task. Long `rate_limited` sleep entries in `queue-log.md` are intentional, not stuckness; the queue is honoring the window and will resume the same iteration on reset. The trip-wire is the only time-sensitive signal that demands immediate attention regardless of cadence.

### 4. Safe to /clear and re-invoke

Monitor holds no state between invocations. Re-reading `queue-state.json`, `queue-log.md`, and checking for `WOKE-ME-UP.md` is idempotent. You can `/clear` the session and re-invoke this phase at any time without losing queue state.

**Monitor writes no state files at v1.** A cursor file (`.monitor-last.json`) for delta rendering is a v2 candidate tracked in `docs/specs/2617-overnight-task-queue/progress.md`.

When the queue log shows all tasks in terminal states (`complete`, `blocked`, or `skipped`), proceed to the [Review phase](review.md).
