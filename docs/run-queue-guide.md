# Run Queue — User Guide

Overnight batch runner for staged AI coding tasks. You define a set of tasks in a `queue.yaml` file, each backed by a handoff document. The supervisor runs them sequentially while you sleep: implement → auto-review → merge into an integration branch. You wake up to a `queue-report.md` showing what passed, what failed, and what needs morning attention.

## Prerequisites

Install via `install.sh`. Required tools:

```sh
brew install jq yq tmux coreutils   # macOS
# Linux: apt/dnf equivalents; coreutils is GNU default
```

`coreutils` is required for `grealpath` (path canonicalization in the guard hook).

## Concepts

**Queue run**: one `queue.yaml` + a set of handoff files → one overnight session. Identified by `run_id` (a short slug you pick, e.g. `overnight-2026-04-27`).

**Task branch**: `queue/<run_id>/<task_id>` — the supervisor creates this branch, runs the task on it, and (on success) merges it into the integration branch.

**Integration branch**: `queue/<run_id>/result` — accumulates all tasks that passed review. At queue end, `base_branch` is fast-forwarded to this branch's HEAD.

**Trip-wire**: if the guard hook fires (e.g., a task tries `git push`), `WOKE-ME-UP.md` is written to the queue directory and the queue halts. Check this file first every morning.

## Quick Start

### 1. Create a queue directory

```sh
mkdir queues/overnight-2026-04-27
```

### 2. Write `queue.yaml`

```yaml
run_id: overnight-2026-04-27
base_branch: main
review_check: true        # auto-review each task (default)
merge_policy: auto        # merge accepted tasks into integration branch (default)
branch_cleanup: after_success  # delete task branches after successful merge (default)

tasks:
  - id: fix-auth-session
    handoff: queues/overnight-2026-04-27/fix-auth-session.md
    depends_on: []

  - id: refactor-billing
    handoff: queues/overnight-2026-04-27/refactor-billing.md
    depends_on: []
    on_failure: skip       # if this task fails, skip dependents gracefully

  - id: update-tests
    handoff: queues/overnight-2026-04-27/update-tests.md
    depends_on: [fix-auth-session]   # runs after fix-auth-session completes
```

**Key fields:**

| Field | Default | Notes |
|-------|---------|-------|
| `run_id` | required | Alphanumeric + `._-` only; becomes branch prefix |
| `base_branch` | `main` | Branch the supervisor launches from |
| `review_check` | `true` | Auto-run `/run-review` after each task |
| `merge_policy` | `auto` | `auto` merges accepted tasks; `manual` flags for morning merge |
| `branch_cleanup` | `after_success` | Delete task branches after successful merge |
| `depends_on` | `[]` | Task IDs this task must wait for |
| `on_failure` | `stop` | `stop` halts dependents; `skip` marks them skipped; `retry_once` retries once |

### 3. Write handoff files

Each task needs a handoff — a Markdown file with YAML frontmatter:

```markdown
---
entry_skill: /do-build
terminal_artifact: .scratch/queue-overnight-2026-04-27-fix-auth-session/build-status.json
max_iterations: 5
review_depth: standard
---

Fix the session expiry bug reported in issue #482. The session token TTL
is not being refreshed on activity — users are getting logged out after
30 minutes even when active.

Root cause is in `src/auth/session.ts:updateSession()` — the `expiresAt`
field is computed once at creation and never updated. Fix it so every
API call with a valid session extends the TTL by `SESSION_DURATION`.

Acceptance: existing auth tests pass; add a test for TTL extension.
```

**Required frontmatter:**

| Field | Notes |
|-------|-------|
| `entry_skill` | Slash-command to invoke: `/do-build`, `/run-implement`, etc. |
| `terminal_artifact` | Path to the JSON artifact the skill writes on completion |

**Common optional fields:**

| Field | Default | Notes |
|-------|---------|-------|
| `max_iterations` | `10` | Intra-task loop cap per attempt |
| `review_depth` | `standard` | `focused` / `standard` / `deep` |
| `merge_policy` | queue default | Override queue-level `merge_policy` for this task |
| `model` | session model | Pin a specific model for this task's child process |

### 4. Validate the queue

```sh
sh skills/run-queue/scripts/queue-lint.sh queues/overnight-2026-04-27
```

Zero output = valid. Errors are printed to stderr with counts on stdout. Fix all errors before spawning.

### 5. Kick off

Use `/run-queue` from Claude Code, or kick directly:

```sh
tmux new-session -d -s overnight \
  'SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh queues/overnight-2026-04-27 2>&1 | tee queues/overnight-2026-04-27/kick.log'
```

The supervisor prints a startup summary to the log, then begins processing tasks in topological order.

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
tail -f queues/overnight-2026-04-27/queue-log.md

# Current task state
cat queues/overnight-2026-04-27/queue-state.json | jq '.tasks[] | {id, status, exit_reason}'

# Check for trip-wire
ls queues/overnight-2026-04-27/WOKE-ME-UP.md 2>/dev/null && echo "TRIP-WIRE FIRED"
```

Rule of thumb: mid-task ~15–30 min between log lines; near queue end ~5 min; a trip-wire requires immediate attention.

## Morning Review

```sh
cat queues/overnight-2026-04-27/queue-report.md
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
