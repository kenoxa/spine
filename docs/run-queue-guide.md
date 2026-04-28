# Run Queue — User Guide

Overnight batch runner for staged AI coding tasks. Describe what you want done, confirm the queue, and wake up to a report.

## How It Works

Invoke `/run-queue` from Claude Code. The skill walks four phases:

1. **Prepare** — describe your tasks; the agent drafts handoffs, audits contracts, and proposes the run order. You confirm twice: first the individual task drafts, then the overall DAG and what gets written.
2. **Kick** — lint check, queue preview, one final confirmation, then the supervisor spawns under tmux.
3. **Monitor** — stateless check-ins while the queue runs: `tail -f queue-log.md` or ask the agent.
4. **Review** — the agent walks you through `queue-report.md` each morning, proposing merge, re-queue, or discard per task.

## Preparing a Queue

Invoke `/run-queue` and describe what you want done tonight:

> "Fix the session expiry bug, refactor the billing module, and update the integration tests."

The agent will:
- Draft a handoff for each task (success criterion, file scope, not-in-scope boundary)
- Propose a run order (with dependency edges if tasks must be sequenced)
- Show you each draft for review and revision before writing anything

You'll see two confirmation screens:
- **Gate 1**: review each task's drafted body — request edits per task, accept when satisfied
- **Gate 2**: confirm the DAG shape and the files that will be written — one "yes" writes everything

If you already have `.scratch/handoff-*.md` files from a prior session, the agent picks those up automatically and merges them with any new tasks you describe.

## Kicking Off

After Prepare, the agent runs the queue linter and shows a preview:
- DAG shape and task table
- Branches that will be created
- Exact tmux command

Confirm with "yes" or "go" and the supervisor spawns.

## Concepts

**Queue run**: one `queue.yaml` + a set of handoff files → one overnight session. Identified by `run_id` (a short slug you pick, e.g. `overnight-2026-04-27`).

**Task branch**: `queue/<run_id>/<task_id>` — the supervisor creates this branch, runs the task on it, and (on success) merges it into the integration branch.

**Integration branch**: `queue/<run_id>/result` — accumulates all tasks that passed review. At queue end, `base_branch` is fast-forwarded to this branch's HEAD.

**Trip-wire**: if the guard hook fires (e.g., a task tries `git push`), `WOKE-ME-UP.md` is written to the queue directory and the queue halts. Check this file first every morning.

## What Happens Overnight

For each task the supervisor:

1. **Creates** `queue/<run_id>/<task_id>` branch from `base_branch`
2. **Spawns** a fresh `claude -p` child with your handoff as the prompt
3. **Loops** (up to `max_iterations`) until `terminal_artifact` reports `complete` or `blocked`
4. **Reviews** the branch via `/run-review` (when `review_check: true`)
5. **Merges** the branch into the integration branch (when `merge_policy: auto` and review passed)

**On merge conflict** (when `merge_policy: auto`): the supervisor spawns `/run-merge` to attempt agentic resolution. If resolved and re-review passes, the integration branch is fast-forwarded. If resolution fails, the task is marked `blocked-by-merge-conflict` and retained for morning triage.

**On rate-limit**: the supervisor sleeps exponentially (2 min → 2 h cap) and retries the same iteration automatically. Long gaps in `queue-log.md` are intentional.

**On trip-wire**: the guard hook fires, writes `WOKE-ME-UP.md`, and the queue halts. Check this file first in the morning.

## Monitoring

```sh
# Live log tail
tail -f .scratch/overnight-2026-04-27/queue-log.md

# Current task state
cat .scratch/overnight-2026-04-27/queue-state.json | jq '.tasks[] | {id, status, exit_reason}'

# Check for trip-wire
ls .scratch/overnight-2026-04-27/WOKE-ME-UP.md 2>/dev/null && echo "TRIP-WIRE FIRED"
```

Rule of thumb: mid-task ~15–30 min between log lines; near queue end ~5 min; a trip-wire requires immediate attention.

## Morning Review

```sh
cat .scratch/overnight-2026-04-27/queue-report.md
```

**Common outcomes:**

| Outcome | What happened | Action |
|---------|--------------|--------|
| `merged` | Task passed review and is already on `main` | Confirm and move on |
| `review-passed-pending-merge` | `merge_policy: manual` — review passed, no auto-merge | Review diff, merge by hand |
| `blocked-by-review` | Review found blocking issues | Inspect verdict, fix branch, re-queue |
| `blocked-by-merge-conflict` | Merge conflict; `/run-merge` could not resolve | Resolve manually, merge by hand |
| `blocked` | Task hit max iterations or another failure | Check iteration JSONLs, re-queue with adjusted handoff |
| `skipped` | Dependent of a failed task with `on_failure: skip` | Confirm skip was expected |
| `trip-wire` | Guard hook fired | Read `WOKE-ME-UP.md` verbatim before any other action |

**Iteration artifacts** — for `blocked` or `partial` tasks, inspect the intra-task loop:

```sh
ls .scratch/queue-overnight-2026-04-27-<task_id>/iterations/
tail -20 .scratch/queue-overnight-2026-04-27-<task_id>/iterations/1-3.jsonl
```

**Merging a task by hand** (for `review-passed-pending-merge` or after manual conflict resolution):

```sh
git merge queue/overnight-2026-04-27/<task_id>
```

Never batch-merge. Handle one task at a time.

## Configuration Reference

### Conflict Resolution (`merge_policy`)

| Value | Behavior on conflict |
|-------|---------------------|
| `auto` (default) | Supervisor spawns `/run-merge`; on failure escalates to morning triage |
| `manual` | No auto-merge, no `/run-merge`. Task flagged `review-passed-pending-merge` |

Set `merge_policy: manual` per-task in the handoff frontmatter to opt a specific task out of auto-resolution.

### Review Depth (`review_depth`)

| Value | When to use |
|-------|------------|
| `focused` | Small changes, low risk |
| `standard` (default) | Most tasks |
| `deep` | Auth, migrations, shared middleware |

### Retry Behavior (`on_failure`)

| Value | Behavior |
|-------|---------|
| `stop` (default) | Dependent tasks blocked |
| `skip` | Dependent tasks marked skipped |
| `retry_once` | Task retried once; `dep-merge-conflict` blocks are not retried |

## Troubleshooting

**Queue won't start**: run `queue-lint.sh` first — it catches missing fields, bad run_ids, invalid branch names, and frontmatter errors.

**Task stuck for hours**: check `queue-log.md` for `rate-limit sleep` entries. The supervisor is sleeping through a rate-limit window and will resume automatically.

**Trip-wire fired**: read `WOKE-ME-UP.md` completely. It contains the guard denial reason and the task/agent that triggered it. Do not merge any branches until you understand what happened.

**Branch collision warning at Kick**: a previous run used the same `run_id`. Either change `run_id` in `queue.yaml` or delete the old branches:
```sh
git branch --list 'queue/overnight-2026-04-27/*' | xargs git branch -D
```

**`merge-verdict.json` missing after `/run-merge`**: the agent crashed or timed out before writing the verdict. The supervisor treats a missing verdict as `failed` (fail-secure) and retains the task branch for morning triage.

## Generated File Reference

The agent writes these files on your behalf. You don't need to author them manually, but they're plain text and can be hand-tuned for advanced use.

### `queue.yaml`

The queue descriptor. Fields: `run_id`, `base_branch`, `review_check`, `merge_policy`, `branch_cleanup`, `tasks[]`.

Full schema: [`references/queue-schema.md`](../skills/run-queue/references/queue-schema.md).

### Handoff files (`<task_id>.md`)

One per task. YAML frontmatter (`task_id`, `entry_skill`, `terminal_artifact`) followed by the task description body.

Required frontmatter:

| Field | Notes |
|-------|-------|
| `task_id` | Must match the `id` in `queue.yaml` |
| `entry_skill` | Slash-command to invoke: `/do-build`, `/run-implement`, etc. |
| `terminal_artifact` | Path to the JSON artifact the skill writes on completion |

Common optional fields: `max_iterations` (default 10), `review_depth` (focused/standard/deep), `model` (pin a specific model for this task).

Full schema: [`references/queue-schema.md`](../skills/run-queue/references/queue-schema.md).
