# Review Phase

**Invariants: never merge a task branch without explicit user confirmation. Trip-wire (`WOKE-ME-UP.md`) must be read verbatim before any merge anywhere in the queue.**

Phase goal: morning walk-through of `queue-report.md` per task — show what each task produced, propose merge/discard/re-queue per status, and merge only after per-task user confirmation.

## Auto-Review and Integration Branch

When `review_check: true` (the default), the supervisor ran `/run-review` automatically for each task that reached `complete` status, then merged accepted branches into `queue/<run_id>/result` (the integration branch). At queue end, `main` was fast-forwarded to the integration branch HEAD — a single atomic mutation. Tasks that passed all three stages (implement → review → merge) are already on `main`; no morning merge is needed for those.

The JSON verdict written by each review spawn lives at `.scratch/queue-<run_id>-<task_id>/review-verdict.json`. The queue-report outcome column reflects the pipeline result directly.

## Steps

### 1. Read inputs

Read the following before proposing any action:

```sh
# Morning report (task-by-task status summary)
cat <queue-dir>/queue-report.md

# Branches created by the run
git branch --list 'queue/<run_id>/*'

# Trip-wire file — check existence first
ls <queue-dir>/WOKE-ME-UP.md 2>/dev/null
```

The queue's base branch is declared in `queue.yaml:base_branch` and also appears in `queue-report.md` as `- Base rev: <SHA> (<base_branch>)`. Use this value in place of `<base_branch>` in all diff and merge steps below.

Read `queue-report.md` for status fields. Do not grep for status strings — the report is structured Markdown; read it fully.

### 2. Trip-wire first

If `<queue-dir>/WOKE-ME-UP.md` exists, show its contents verbatim before any proposal:

```
TRIP-WIRE FIRED — WOKE-ME-UP.md present

<verbatim contents of WOKE-ME-UP.md>
```

The user inspects the affected branch(es) before deciding on any merge. Do not propose merges until the user explicitly indicates they have reviewed the trip-wire.

### 3. Per-status action table

Walk through each task in topological order. For each task, look up its `status` and `exit_reason` in `queue-report.md` and propose the action below.

Statuses come from `queue-state.json`; `exit_reason` disambiguates within `blocked`.

| Outcome | Proposed action |
|---------|-----------------|
| `merged` | Task is already on `main` via the integration branch. No morning merge needed. Confirm with user and move on. |
| `review-passed-pending-merge` (`merge_policy: manual`) | Review passed but `merge_policy: manual` was set — the supervisor did not auto-merge. Show the verdict path (`.scratch/queue-<run_id>-<task_id>/review-verdict.json`) and branch reference (`queue/<run_id>/<task_id>`). User manually merges into `main` after reviewing the diff. |
| `blocked-by-review` | `/run-review` found ≥1 blocking finding. Show the verdict path. User reviews findings, may amend the branch, and may rerun `/run-review` manually before re-queuing or merging. |
| `blocked-by-merge-conflict` | `git merge --no-ff` aborted due to a conflict; branch retained. User resolves the conflict manually (Slice I will add `/run-merge` for auto-resolve). After resolving, merge the branch into `main` by hand. |
| `complete` | `review_check: false` was set — no auto-review ran. Show `git diff <base_branch> queue/<run_id>/<task_id>` summary. Offer `git merge queue/<run_id>/<task_id>` after the user reviews the diff. |
| `partial` (per-iteration status from `build-status.json`; task continues its loop — not a terminal queue status) | Show diff + exit_reason. Present three choices: merge as-is / discard branch / re-queue for another run. User decides. |
| `blocked` | Show `exit_reason` + tail of the final iteration JSONL (`<attempts>-<iter>.jsonl` — see step 4). Propose: re-queue with adjusted handoff / abandon. |
| `skipped` | Confirm the transitive skip was expected (parent task failed with `on_failure: skip`). No branch to merge. |
| `retry-exhausted` (status: `blocked`, exit_reason: `retry-exhausted`) | Show both attempt JSONLs (attempt 1 and 2 under iterations/). User decides: merge best attempt / discard both / re-queue. |
| `trip-wire` (status: `blocked`, exit_reason: `trip-wire`) | Show `WOKE-ME-UP.md` verbatim (already done in step 2). User inspects the branch before any merge decision. |

For `complete` and `partial` tasks, always show the diff before asking for merge confirmation — never merge blind.

### 4. Iteration artifacts

Each task's intra-task loop iterations are recorded as JSONL files at:

```
.scratch/queue-<run_id>-<task_id>/iterations/<attempts>-<iter>.jsonl
```

- `attempts` — outer retry counter: `1` for a normal run, `2` when `retry_once` fired.
- `iter` — iteration counter within that attempt, starting at `1`.

For `blocked`, `partial`, and `retry-exhausted` tasks, point the user at this grid for intra-task progression inspection. Example: `1-1.jsonl` and `1-2.jsonl` are the first and second iterations of the first attempt; `2-1.jsonl` is the first iteration after `retry_once` fired.

To examine a specific iteration:

```sh
tail -20 .scratch/queue-<run_id>-<task_id>/iterations/1-2.jsonl
```

### 5. Merge workflow

Handle one task at a time. Never batch-merge.

For each task the user decides to merge:

```sh
git merge queue/<run_id>/<task_id>
```

After the merge completes, confirm success and move to the next task.

For tasks the user decides to re-queue: note the task id and any handoff adjustments needed. A new run requires a fresh `run_id` in `queue.yaml` (branch collision check at Kick will catch duplicates).

For tasks the user decides to discard: delete the branch after confirming:

```sh
git branch -d queue/<run_id>/<task_id>
```

When all tasks are resolved, the run is complete.
