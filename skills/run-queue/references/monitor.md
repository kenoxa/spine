# Monitor Phase

**Invariants: Trip-wire (`WOKE-ME-UP.md` presence) is the authoritative "attention required" signal, independent of cadence guidance. Executable monitor (`monitor.sh`) writes per-terminal snapshots to `/tmp/` — outside the queue directory; supervisor write exclusivity is preserved.**

Phase goal: delta-aware check-in on a running queue — read current state, surface the trip-wire if present, report per-task progress, and suggest when to check back.

## Invocation

```
sh skills/run-queue/scripts/monitor.sh <queue-dir> [--watch] [--interval N]
```

- `--watch` — re-run on every iteration (delta mode); first run shows full table, subsequent runs show only changes
- `--interval N` — seconds between iterations when `--watch` is set (default: 30)

Without flags, runs once and exits.

## Steps

### 1. Files to read

Read these files from `<queue-dir>`:

| File | Purpose | How to Read |
|------|---------|-------------|
| `queue-state.json` | Machine view — current task, branch per task, `base_rev` | `jq '.' <queue-dir>/queue-state.json` |
| `queue-log.md` | Append-only supervisor log — task transitions, rate-limit events | `tail -40 <queue-dir>/queue-log.md` |
| `WOKE-ME-UP.md` | Trip-wire file — present only if a permission deny fired | Check existence, then read verbatim if present |
| `health.json` | Task-scratch sidecar — present if watchdog detected a transcript stall | Check existence per task at `.scratch/queue-<run_id>-<task_id>/health.json` |

Read `queue-state.json` via `jq`, not prose grep. The file is machine-written JSON; string-scanning for task names is fragile.

### 2. Current-state output

Report for each task in the queue (derived from `queue-state.json`):

- Task id + current status (`pending`, `pending_retry`, `complete`, `blocked`, `skipped`)
- Current iteration (read from `queue-log.md` — look for `task=<id> iter=N` lines, or count files in `.scratch/queue-<run_id>-<task_id>/iterations/`)
- Branch name if created
- Last relevant line from `queue-log.md` for running or recently-completed tasks

**Stuck-task detection (stateless):** For each task, check whether `.scratch/queue-<run_id>-<task_id>/health.json` exists. If it does, the transcript watchdog detected a stall — prepend `⚠️ STUCK` to the task's status display. Sort tasks with `health.json` to the top of the table, before non-stuck tasks. The presence of `health.json` indicates the task was SIGTERM'd by the watchdog due to transcript silence; check the task transcript and `queue-log.md` for the stall timestamp.

**If `WOKE-ME-UP.md` exists**, show it first, prominently, before the per-task table:

```
TRIP-WIRE FIRED — WOKE-ME-UP.md present
<verbatim contents of WOKE-ME-UP.md>
```

Do not proceed to per-task reporting until the user has seen the trip-wire contents. When run via `monitor.sh`, the trip-wire check fires on every iteration; if the file is present the script prints it prominently and exits with code 2.

### 3. Delta behavior

On first run (no prior snapshot), `monitor.sh` renders the full per-task table.

On subsequent runs with `--watch`, it diffs against the last snapshot in `/tmp/spine-monitor-<run_id>-<pid>.json` and shows only changed tasks (status, iteration, branch, last log line). Unchanged tasks are listed as `— unchanged —`.

Snapshots are per-terminal (written to `/tmp/`); they are not shared across terminals. Each terminal sees its own delta stream. This preserves the supervisor's write exclusivity in the queue directory.

### 4. When to check back

Mid-task (iter 1–3 of 10): check back in ~15–30 min. Near-end iterations (iter ≥ 8/10) or last task: ~5 min. `WOKE-ME-UP.md` present: act now — do not wait.

These are coarse floor estimates. Rate-limit backoff can extend any task by up to 2 hours (120 s → 2 h cap) — and if the 5h rolling or weekly request window is exhausted, the supervisor sleeps through the window-reset rather than failing the task. Long `rate_limited` sleep entries in `queue-log.md` are intentional, not stuckness; the queue is honoring the window and will resume the same iteration on reset. The trip-wire is the only time-sensitive signal that demands immediate attention regardless of cadence.

### 5. Safe to /clear and re-invoke

The executable monitor holds no state in the queue directory. Re-reading `queue-state.json`, `queue-log.md`, and checking for `WOKE-ME-UP.md` is idempotent. Each terminal's snapshot in `/tmp/` is independent; clearing the session and re-invoking this phase at any time has no effect on queue state.

**The old AI-driven prose approach still works for manual check-ins** — when you want a full re-render without installing `monitor.sh`, invoke the Monitor phase directly and read files as described above. The executable is the recommended path; the AI-driven approach remains the fallback.

When the queue log shows all tasks in terminal states (`complete`, `blocked`, or `skipped`), proceed to the [Review phase](review.md).
