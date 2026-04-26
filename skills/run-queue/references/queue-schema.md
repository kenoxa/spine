# Queue Schema

A queue is a directory. Its contents are:

```
<queue-dir>/
├── queue.yaml                    # orchestration — run_id, base_branch, DAG edges
├── profile.json                  # permission profile (generated or user-supplied)
├── handoff-<task_id>.md          # one per task; frontmatter + body
└── ...
```

At runtime, `<queue-dir>` also accumulates:

```
queue-state.json        # per-run mutable state (atomic writes)
queue-log.md            # append-only supervisor log
queue-report.md         # morning report (written on completion)
WOKE-ME-UP.md           # only if a trip-wire fired
```

The authority split is strict: **task intrinsics live in handoff frontmatter; orchestration lives in `queue.yaml`**. No dual-source of truth — if a field needs to be declared, it lives in exactly one of the two.

## `queue.yaml` — Orchestration

```yaml
# --- identity ---
run_id: overnight-2026-04-25-a1b2          # REQUIRED; also forms branch prefix
description: "Apr-25 overnight: 3 UI fixes + 1 refactor"   # optional; shown in report

# --- git + trust ---
base_branch: main                            # OPTIONAL; defaults to HEAD at supervisor start
profile: profile.json                        # OPTIONAL; per-queue permission overlay; absent → hook defaults
backoff_cap_ms: 7200000                      # OPTIONAL; default 7200000 (2 h); Slice C

# --- tasks ---
tasks:
  - id: refactor-auth                        # REQUIRED; matches handoff-<id>.md
    handoff: handoff-refactor-auth.md        # OPTIONAL; defaults to handoff-<id>.md
    depends_on: []                           # OPTIONAL; default [] (independent)

  - id: fix-login-bug
    depends_on: [refactor-auth]

  - id: add-signup-page
    depends_on: [refactor-auth]              # runs sequentially after refactor-auth (parallel execution is a future slice)
```

Required top-level: `run_id`, `tasks`.
Required per task: `id`. Other task fields default as documented.

`profile` is optional — when absent, the queue hook uses built-in defaults (see [permission-profile.md](permission-profile.md)). Add a profile only when you need queue-specific overrides like extra deny patterns or out-of-repo write allowances.

## Per-Handoff Frontmatter — Task Intrinsics

Each `handoff-<task_id>.md` opens with YAML frontmatter:

```yaml
---
task_id: refactor-auth                      # REQUIRED; must match queue.yaml entry
entry_skill: /do-build                      # REQUIRED; skill invoked inside the fresh claude -p
terminal_check: build-status.json           # ONE-OF with terminal_artifact; pattern or `build-status.json`
terminal_artifact: .scratch/${SESSION}/build-status.json  # ONE-OF with terminal_check

# --- optional overrides ---
max_iterations: 10                          # default 10; Slice C loop cap
on_failure: stop                            # stop | skip | retry_once; default stop
scope_files: [src/auth/**]                  # informational; supervisor does not enforce
commit_ceiling: 8                           # advisory; supervisor warns if exceeded
---

# Handoff body — the actual prompt / task description
...
```

Required: `task_id`, `entry_skill`, and exactly one of `terminal_check` or `terminal_artifact`.

### Terminal check

The supervisor decides a task is terminal when EITHER:

- `terminal_artifact` is set and the file exists AND parses as valid `build-status.json` with `status ∈ {complete, partial, blocked}` (not `in_progress`). This is the default and recommended path.
- `terminal_check` is set and is a shell expression returning exit 0. Escape hatch for tasks whose entry skill is not do-build.

The sentinel `build-status.json` (string literal) is shorthand for `.scratch/${SESSION}/build-status.json` — the supervisor resolves `${SESSION}` from its own per-task scratch directory.

## Lint Rules (`scripts/queue-lint.sh`)

Enqueue-time static validation. Refuses invalid queues before spawning any process. Exit 0 = valid, exit 1 = invalid (reason on stderr).

| Rule | Error on violation |
|------|--------------------|
| `queue.yaml` parses as YAML | parse error line + column |
| Required top-level fields present | list of missing fields |
| Each `tasks[].id` is unique | `duplicate task id: <id>` |
| Handoff file exists for each task | `missing handoff: <path>` |
| Handoff frontmatter parses + has required fields | `<handoff>: missing <field>` |
| `depends_on` references existing task ids | `<task>: unknown dep: <id>` |
| DAG has no cycles (via `tsort`) | `cycle: <a> → <b> → ... → <a>` (Slice B) |
| `profile` (when declared) file exists and is valid JSON | `profile not found \| profile invalid json` |
| `on_failure` in {stop, skip, retry_once} | `<task>: invalid on_failure: <v>` |
| `max_iterations` is a positive integer | `<task>: invalid max_iterations: <v>` |
| `task_id` (queue.yaml `id` + frontmatter) contains no whitespace | `<task>: task_id may not contain whitespace` |

## Failure propagation (`on_failure`)

Each task's `on_failure` (declared in handoff frontmatter, default `stop`) governs what happens to its dependents when it ends `blocked`:

| `on_failure` | Effect on the blocked task | Effect on dependents |
|---|---|---|
| `stop` (default) | Remains `blocked` | Direct dependents marked `blocked`, exit_reason `transitive-block`. NOT spawned. Propagation walks the DAG: those direct dependents cascade `blocked/transitive-block` to their own direct dependents, and so on, each step respecting the intermediate task's own `on_failure` policy. |
| `skip` | Remains `blocked` | Direct dependents marked `skipped`, exit_reason `dependency-failed-skip`. NOT spawned. Propagation walks the DAG respecting each intermediate task's own `on_failure`. A `skipped` parent at any depth cascades `skipped/dependency-failed-skip` to its direct dependents; those dependents in turn cascade according to their OWN `on_failure` policy to their direct dependents. |
| `retry_once` | First block → marked `pending_retry` (transient). Exception: if the block reason is `dep-merge-conflict`, the task is NOT retried — the same merge will conflict again, so it stays `blocked/dep-merge-conflict` and dependents propagate as if `retry_once` were `stop`. | Dependents wait until retry resolves (or propagate `transitive-block` on the merge-conflict exception). |

Independent branches (tasks not in the failed task's transitive dependency set) continue running regardless of another branch's failure.

**Trip-wire always supersedes `on_failure`.** If `WOKE-ME-UP.md` appears after any task or retry, the queue halts unconditionally.

### retry_once timing

Retry is lazy: when a `retry_once` task blocks on the first attempt, it is marked `pending_retry` and the supervisor continues with subsequent topological-order tasks that do not depend on it (siblings proceed). The retry fires just-in-time when the loop reaches the first task that depends on the `pending_retry` parent.

**Backoff:** if no other tasks ran between the first failure and the retry trigger (i.e., there were no siblings and the retry would fire immediately), the supervisor sleeps 30 seconds before respawning. If siblings ran, their runtime already provides implicit backoff — sleep is skipped.

If the retry attempt also blocks, the task becomes final `blocked` with exit_reason `retry-exhausted`, and its dependents receive `transitive-block`.

**dep-merge-conflict exception:** a task blocked with `dep-merge-conflict` is never retried, even when `retry_once` is set. The supervisor marks it final `blocked/dep-merge-conflict` immediately and propagates `transitive-block` to dependents.

If the queue ends with `pending_retry` tasks that had no dependents, they are flushed (retried with the 30s backoff) before the report is written.

**Attempt counter:** each spawn increments `attempts` in the task's state. Attempts are tracked in `queue-state.json`; report surfacing is deferred to a later slice. Note: `attempts` counts setup attempts including dep-merge-conflict aborts; it does NOT count intra-task loop iterations. Iterations are observable via the JSONL naming grid.

## Branch naming

Per task, the supervisor creates local branch `queue/<run_id>/<task_id>`. The supervisor refuses to start if any such branch already exists — to namespace a re-run, change `run_id` or delete old branches.

**Independent tasks** (`depends_on: []`): branch forks from `base_rev = rev-parse(base_branch or HEAD-at-start)`.

**DAG-child tasks** (tasks with `depends_on` entries): the supervisor forks from `base_rev`, then merges all parent branches via `git merge --no-ff -m "queue/<run_id> merge deps for <id>" <parent-branches...>`. Only parent branches that produced a branch (i.e., reached `complete` or `partial`) are included in the merge list. Parents with no branch (blocked or skipped before spawn) are omitted.

If the merge has conflicts, the dependent task is marked `blocked` with exit_reason `dep-merge-conflict`. The child process is not spawned. `git merge --abort` is called and the partially-created branch is deleted.

If ALL parents are `blocked` or `skipped` (no parent branch exists), the task is blocked with `transitive-block` — no merge, no spawn.

### Iteration artifacts

Each intra-task loop iteration writes a JSONL file under the task's scratch directory. The naming grid is `<attempts>-<iter>.jsonl`:

- `attempts` — outer retry counter: `1` for a normal run, `2` when `retry_once` fires a second spawn.
- `iter` — intra-task loop counter within that attempt, starting at `1`.
- A `.stderr` sibling file is written alongside each JSONL.

Files live at `.scratch/queue-<run_id>-<task_id>/iterations/<attempts>-<iter>.jsonl`. Examples: `1-1.jsonl` and `1-2.jsonl` are the first and second iterations of the first attempt; `2-1.jsonl` is the first iteration after `retry_once` fires.

## Intra-task loop

The supervisor re-invokes `claude -p` per iteration until the task is terminal, `max_iterations` (default 10) is reached, or a trip-wire fires. Each iteration is a fresh `claude -p` process.

**Iteration 1** uses the original handoff body unchanged. **Iterations ≥ 2** prepend a short resumption header referencing the prior iteration's JSONL path, the current branch state, and the session-log location; the rest of the handoff body follows unchanged.

**Decision table** (terminal status → supervisor action):

| Status | Action |
|--------|--------|
| `complete` | Loop breaks; task final `complete`. |
| `blocked` | Loop breaks; task final `blocked` (outer `retry_once` may still fire). |
| `partial` | Loop continues — another iteration; resumption prompt references prior iteration's JSONL. |
| `in_progress` | Loop continues — treated as non-terminal (child did not finish writing final status). |
| missing artifact | Loop breaks; task `blocked/missing-terminal-artifact`. |
| invalid artifact status | Loop breaks; task `blocked/invalid-terminal-status` (`.status` not in `{complete, partial, blocked, in_progress}`). |

`max_iterations` default: `10`. When the cap is reached the task is marked `blocked/max-iterations-exceeded`.

## Rate-limit backoff

When a child exits and its stderr matches the rate-limit pattern (from `skills/use-envoy/scripts/_rate_limit.sh`), the supervisor treats the spawn as a fast failure and sleeps before retrying the **same iteration** (the iteration counter does not advance).

**Backoff schedule (seconds):** 120 → 240 → 480 → 960 → 1920 → cap at 7200 (2 h). The counter resets on any non-rate-limited spawn completion.

**Test-mode override:** set `SPINE_QUEUE_RL_BASE_SEC` to a small value (e.g. `1`) to use a shorter base for timing-sensitive integration tests. This variable is intended for test use only; do not set it in production.

## Exit reasons

| `exit_reason` | Meaning |
|---|---|
| `trip-wire` | Guard hook denied a tool call; `WOKE-ME-UP.md` written |
| `terminal-check-pass` | `terminal_check` shell expression exited 0 |
| `terminal-check-fail` | `terminal_check` exited non-zero |
| `artifact-status-only` | `terminal_artifact` file present; exit_reason came from artifact (not supervisor) |
| `missing-terminal-artifact` | `terminal_artifact` path not found after child exits |
| `signal-INT` / `signal-TERM` | Supervisor received SIGINT/SIGTERM during this task |
| `transitive-block` | A `depends_on` parent is blocked with `on_failure: stop` |
| `dependency-failed-skip` | A `depends_on` parent is blocked with `on_failure: skip` |
| `retry-exhausted` | `on_failure: retry_once`; both attempts blocked |
| `retry-not-flushed` | Task was in `pending_retry` when the queue halted abnormally (trip-wire or unexpected error); retry was not attempted |
| `dep-merge-conflict` | `git merge --no-ff` of parent branches had conflicts |
| `max-iterations-exceeded` | Intra-task loop reached `max_iterations` without a terminal status |
| `invalid-terminal-status` | `terminal_artifact` file present but `.status` value not in `{complete, partial, blocked, in_progress}` |

## Open Questions (deferred past Slice B)

- Schema evolution: currently v1 is implicit. Adding a `schema_version` field at `queue.yaml` root is planned for v2 when the first breaking change lands.
- Distributed queues across multiple machines / repos: out of v1 scope.
- Parallel execution within topological order: Slice B is still linear within topo order. Concurrent independent branches arrive in a future slice.
