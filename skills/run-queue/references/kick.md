# Kick Phase

**Invariants: never spawn the supervisor without lint pass + preview + explicit user confirmation. Preview confirms queue shape; supervisor handles rate-limit backoff automatically.**

Phase goal: run enqueue lint, show a queue preview, confirm with the user, then spawn the supervisor under tmux (or nohup/screen on request).

## Steps

### 1. Lint first

Run the queue validator:

```sh
sh skills/run-queue/scripts/queue-lint.sh <queue-dir>
```

On any lint failure, show the error output and route the user to fix the issue. Do not offer to kick. Return to the [Prepare phase](prepare.md) if the fix requires changing `queue.yaml` or handoff frontmatter.

On clean lint (exit 0), proceed to preview.

### 2. Preview

Render the following on one screen before any confirmation prompt. Goal: confirm queue shape — what runs, where, with what dependencies. All numbers come from user-authored frontmatter — no empirical multipliers or invented estimates.

**DAG shape**

```
  Tasks: 2   Dependency edges: 1
```

If the topology fits in 1–3 lines, sketch it (e.g. `A → B`, `C → D`, `E (independent)`).

**Tasks**

```
  Task     Depends on   on_failure    max_iterations
  ──────   ──────────   ───────────   ──────────────
  task-a   —            retry_once    10
  task-b   task-a       stop          5
```

One row per task. `—` for roots. Numbers come from user-authored frontmatter.

**Branches**

Run `git branch --list 'queue/<run_id>/*'`. List the branches that will be created:

```
  queue/<run_id>/task-a
  queue/<run_id>/task-b
```

If any of these branches already exist, warn: "These branches will conflict — change `run_id` in `queue.yaml` or delete old branches before spawning."

**Base revision**

```
  Base rev: <SHA from git rev-parse HEAD>
```

**Tmux command**

Show the exact command that will run, verbatim, for the user to inspect or copy:

```sh
tmux new-session -d -s queue-<run_id> \
  'SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh <queue-dir> 2>&1 | tee <queue-dir>/kick.log'
```

**Rate-limit handling.** Supervisor sleeps through any 5h rolling or weekly request-window exhaustion (`_rot_rate_limit_retry`, 120 s → 2 h cap) and resumes the same iteration on reset. Long sleeps in `queue-log.md` are intentional, not stuckness.

**Worst-case spawn count.** Only for queues with ≥ 5 tasks, append one line:

```
  Worst-case spawns: N   (Σ max_iterations × 2 for retry_once tasks, × 1 otherwise)
```

Skip for smaller queues — the Tasks table already shows the per-task values.

### 3. Confirmation gate

After rendering the full preview, ask for explicit confirmation:

> Spawn the supervisor? (yes / go — or edit the queue first)

Do not proceed on anything other than an explicit "yes" or "go". An unclear response → ask again. Never auto-spawn.

### 4. Spawn mechanism

Default: tmux. Ask the user if they prefer nohup or screen — use tmux unless they request otherwise.

**tmux (default):**

```sh
tmux new-session -d -s queue-<run_id> \
  'SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh <queue-dir> 2>&1 | tee <queue-dir>/kick.log'
```

**nohup:**

```sh
nohup sh -c 'SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh <queue-dir>' \
  > <queue-dir>/kick.log 2>&1 &
echo "PID: $!"
```

**screen:**

```sh
screen -dmS queue-<run_id> \
  sh -c 'SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh <queue-dir> 2>&1 | tee <queue-dir>/kick.log'
```

Assemble the exact command for the chosen mechanism and run it after the user confirms.

> Before running the command, verify `<run_id>` matches `[A-Za-z0-9_-]+` — `queue-lint.sh` enforces most metachar rejections, but this preview is the human's last check. If you edit substituted values by hand, wrap them in single quotes.

### 5. Post-kick

After the supervisor spawns, report:

- Tmux session name (or PID/screen session for alternatives): `queue-<run_id>`
- Queue log path: `<queue-dir>/queue-log.md` (append-only supervisor log)
- Expected artifacts on completion: `<queue-dir>/queue-state.json`, `<queue-dir>/queue-report.md`
- Trip-wire signal: `<queue-dir>/WOKE-ME-UP.md` — created only if a permission deny fires; its presence means attention required now.

For check-in guidance, proceed to the [Monitor phase](monitor.md) when the queue is running.
