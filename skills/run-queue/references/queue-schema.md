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
queue-report.html       # optional self-contained HTML dashboard (when generate_dashboard: true)
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

# --- pipeline ---
review_check: true                           # OPTIONAL; default true — spawn /run-review per task
review_depth: standard                       # OPTIONAL; default standard — focused|standard|deep
merge_policy: auto                           # OPTIONAL; default auto — auto|manual
branch_cleanup: after_success                # OPTIONAL; default after_success — after_success|never
generate_dashboard: false                    # OPTIONAL; default false — true|false; emits queue-report.html alongside queue-report.md

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
model: sonnet                               # optional; pins the spawned child's main-thread model (see §model below)

# --- pipeline overrides (win over queue.yaml defaults) ---
review_check: true                          # override queue-level default; true|false
review_depth: deep                          # override queue-level default; focused|standard|deep
merge_policy: manual                        # override queue-level default; auto|manual
---

# Handoff body — the actual prompt / task description
...
```

Required: `task_id`, `entry_skill`, and exactly one of `terminal_check` or `terminal_artifact`.

### model

`model:` is a provider-scoped runtime selector passed as `--model <value>` to the `claude --print` child process the supervisor spawns for this task. It is a flat string — the value is handed to the CLI verbatim; lint catches structural problems (whitespace, shell metachars, length, and charset — see Lint Rules table) but does not validate against an enum. Omit to inherit whatever model the parent `claude` process defaults to.

`model:` pins the **spawned child's main-thread model** — the model the queue task itself runs as. It does not affect subagents dispatched inside that task; those are governed by `docs/model-tier-assignments.md`. In-session main-thread model switching of the orchestrator process is an Anthropic CLI feature and is outside the scope of this field.

### review_check

`review_check:` controls whether the supervisor spawns `/run-review` after the implementation stage completes with `complete`.

- **Default**: `true` (queue-level and per-handoff).
- **Allowed values**: `true` | `false`.
- **Placement**: queue.yaml top-level (queue default) and per-handoff frontmatter (task override). Per-handoff value wins.

`review_check: false` skips the review stage entirely. The task branch is left on disk and the task is marked `complete` — the same behavior as pre-Slice-H. Use this for tasks where review is not meaningful (e.g. doc-only updates, generated files).

`review_check: true` requires the review stage to pass before the task branch is merged into the integration branch. A blocking finding from `/run-review` marks the task `blocked/review-blocking-findings`.

**Precedence**: supervisor checks handoff frontmatter first → falls back to `queue.yaml` → falls back to `true`.

### review_depth

`review_depth:` sets the depth argument forwarded to `/run-review` when it is spawned.

- **Default**: `standard`.
- **Allowed values**: `focused` | `standard` | `deep`.
- **Placement**: queue.yaml top-level (queue default) and per-handoff frontmatter (task override). Per-handoff value wins.

`focused` is permitted but the supervisor logs a warning: "review_depth: focused writes no findings artifact at /run-review side; sidecar is still emitted." The warning is advisory — lint does not reject `focused`.

`deep` triggers a more exhaustive review and may increase spawn time. Suitable for high-risk tasks where thoroughness matters more than speed.

**Precedence**: supervisor checks handoff frontmatter first → falls back to `queue.yaml` → falls back to `standard`.

### merge_policy

`merge_policy:` governs what happens when `/run-review` accepts the implementation (no blocking findings).

- **Default**: `auto`.
- **Allowed values**: `auto` | `manual`.
- **Placement**: queue.yaml top-level (queue default) and per-handoff frontmatter (task override). Per-handoff value wins.

`auto`: on review-accept the supervisor merges the task branch into the integration branch (`queue/<run_id>/result`) via `git merge --no-ff`. At queue end the integration branch is fast-forwarded into `base_branch`. When the merge has conflicts, the supervisor spawns `/run-merge` to attempt agentic resolution (one attempt per task, capped by `SPINE_QUEUE_MERGE_TIMEOUT`). If resolution succeeds and re-review passes, the integration branch is fast-forwarded from the resolved scratch branch. If resolution fails, the task is retained with `blocked-by-merge-conflict` for morning triage.

`manual`: review still runs in full. On review-accept the branch is flagged but NOT merged automatically — the task is marked `review-passed-pending-merge`. No merge into the integration branch occurs; `/run-merge` is never spawned. The morning engineer inspects and merges by hand.

**Precedence**: supervisor checks handoff frontmatter first → falls back to `queue.yaml` → falls back to `auto`.

### branch_cleanup

`branch_cleanup:` controls whether task branches are deleted at queue end after a successful merge.

- **Default**: `after_success`.
- **Allowed values**: `after_success` | `never`.
- **Placement**: queue.yaml top-level ONLY. No per-handoff override (applies to the whole queue run).

`after_success`: task branches (`queue/<run_id>/<task_id>`) whose merge into the integration branch succeeded are deleted at queue end. Failed, blocked, and flagged branches (including `review-passed-pending-merge`) are retained for morning inspection.

`never`: all task branches are retained regardless of outcome. Useful for post-mortems and when the engineer wants to inspect every branch.

The integration branch (`queue/<run_id>/result`) is NOT a task branch and is not subject to `branch_cleanup`. It is retained until the end-of-queue fast-forward into `base_branch`; on successful delivery it is then deleted. If the fast-forward fails, it is retained for inspection.

### generate_dashboard

`generate_dashboard:` controls whether the supervisor emits a self-contained HTML dashboard (`queue-report.html`) alongside the Markdown report (`queue-report.md`).

- **Default**: `false`.
- **Allowed values**: `true` | `false`.
- **Placement**: queue.yaml top-level ONLY. No per-handoff override.

`true`: after writing `queue-report.md`, the supervisor invokes `scripts/generate-dashboard.sh` to produce `queue-report.html` in the queue directory. The HTML file is fully self-contained (inline CSS/JS) with no external dependencies. It includes a task table with color-coded status chips, an overall progress bar, a horizontal task timeline, and collapsible sections for conflicts and action items.

`false`: no HTML report is generated.

If `generate_dashboard: true` but `generate-dashboard.sh` is missing or not executable, the supervisor logs a warning and continues — the queue does not fail.

### Terminal check

The supervisor decides how to proceed after each child exits using two paths:

- `terminal_artifact` is set: supervisor reads `.status` from the artifact. **Artifact-read condition** (parseable): `.status ∈ {complete, partial, blocked, in_progress}`. **Loop-termination condition** (break): only `complete` or `blocked` stop the loop; `partial` and `in_progress` continue iteration. This is the default and recommended path; enables intra-task looping.
- `terminal_check` is set and is a shell expression returning exit 0. Single-shot: exit 0 → `complete`; non-zero → `blocked`. No loop continuation. Escape hatch for tasks whose entry skill is not do-build.

The sentinel `build-status.json` (string literal) is shorthand for `.scratch/${SESSION}/build-status.json` — the supervisor resolves `${SESSION}` from its own per-task scratch directory.

### Terminal-status semantics

**Supervisor implementation:** `run.sh:_classify_terminal_status` (artifact read and terminal-check logic) and `run.sh:_rot_iterate` (loop control case). Pinned line numbers drift; symbol names are stable.

**`terminal_check`** is single-shot: the shell expression runs once after each child exits. Exit 0 → task `complete`. Non-zero → task `blocked`. The loop never continues from `terminal_check`. Use this path for tasks whose entry skill is not `do-build` and that have no multi-iteration contract.

**`terminal_artifact`** enables intra-task looping. The supervisor reads `.status` from the artifact after each child exits. `complete` or `blocked` breaks the loop (terminal). `partial` or `in_progress` keeps the loop running — the supervisor respawns `claude -p` with a resumption header prepended to the original handoff body.

**Worked trace — 3-iteration task:**

**Iter 1:** Child starts from the original handoff body. Child writes:
```json
{"status": "in_progress", "exit_reason": "iter-1-not-done"}
```
Supervisor reads `in_progress` → non-terminal → loop continues.

**Iter 2:** Supervisor prepends a resumption header before the handoff body. The child receives:
```
## Continuing task <task-id> (iteration 2 of 10)
Prior iteration ended at <timestamp> with status=in_progress, exit_reason=iter-1-not-done.
Session-log (if exists): .scratch/queue-<run_id>-<task_id>/session-log.md
Prior iteration transcript: .scratch/queue-<run_id>-<task_id>/iterations/1-1.jsonl
Branch: queue/<run_id>/<task_id> (current HEAD: <sha>)

Continue per the original handoff body below. Pick up where the prior iteration stopped — do not restart from scratch.

---
...original handoff body follows...
```
Child writes:
```json
{"status": "in_progress", "exit_reason": "iter-2-not-done"}
```
Supervisor reads `in_progress` → non-terminal → loop continues.

**Iter 3:** Same resumption header pattern (references `1-2.jsonl`). Child writes:
```json
{"status": "complete", "exit_reason": "all-done"}
```
Supervisor reads `complete` → loop breaks; task is final `complete`.

See [§Intra-task loop](#intra-task-loop) for the full decision table mapping each status to supervisor action.

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
| `commit_ceiling` (when set) is a positive integer | `<task>: commit_ceiling must be a positive integer, got '<v>'` |
| `task_id` (queue.yaml `id` + frontmatter) contains no whitespace | `<task>: task_id may not contain whitespace` |
| `model` (when set) contains no whitespace, no shell metachars, ≤128 chars, charset `[A-Za-z0-9._:/[]_-]` | `<task>: model contains whitespace \| contains shell metachars \| exceeds 128 characters \| contains characters outside allowed set` |
| `review_check` (queue or per-handoff, when set) is `true` or `false` | `queue.yaml: invalid review_check '<v>' \| <task>: invalid review_check '<v>'` |
| `review_depth` (queue or per-handoff, when set) in {focused, standard, deep}; no whitespace, no shell metachars, ≤64 chars, charset `[A-Za-z0-9_-]` | `queue.yaml: review_depth contains whitespace \| ... \| invalid review_depth '<v>' (expected: focused\|standard\|deep)` |
| `merge_policy` (queue or per-handoff, when set) in {auto, manual}; no whitespace, no shell metachars, ≤64 chars, charset `[A-Za-z0-9_-]` | `queue.yaml: merge_policy contains whitespace \| ... \| invalid merge_policy '<v>' (expected: auto\|manual)` |
| `branch_cleanup` (queue-level only, when set) in {after_success, never}; no whitespace, no shell metachars, ≤64 chars, charset `[A-Za-z0-9_-]` | `queue.yaml: branch_cleanup contains whitespace \| ... \| invalid branch_cleanup '<v>' (expected: after_success\|never)` |
| `generate_dashboard` (queue-level only, when set) is `true` or `false` | `queue.yaml: invalid generate_dashboard '<v>' (expected: true\|false)` |

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

**Interaction with `max_iterations`:** when `retry_once` fires, the second attempt starts a fresh intra-task loop with its own `max_iterations` cap. The cap resets — it is not shared across attempts. A task with `max_iterations: 3` and `retry_once` can consume up to 6 iterations total (3 per attempt) before the outer `retry-exhausted` verdict fires.

**Attempt counter:** each spawn increments `attempts` in the task's state. Attempts are tracked in `queue-state.json`; report surfacing is deferred to a later slice. Note: `attempts` counts setup attempts including dep-merge-conflict aborts; it does NOT count intra-task loop iterations. Iterations are observable via the JSONL naming grid.

## Branch naming

Per task, the supervisor creates local branch `queue/<run_id>/<task_id>`. The supervisor refuses to start if any such branch already exists — to namespace a re-run, change `run_id` or delete old branches.

**Independent tasks** (`depends_on: []`): branch forks from `base_rev = rev-parse(base_branch or HEAD-at-start)`.

**DAG-child tasks** (tasks with `depends_on` entries): the supervisor forks from `base_rev`, then merges all parent branches via `git merge --no-ff -m "queue/<run_id> merge deps for <id>" <parent-branches...>`. Only parent branches that produced a branch (i.e., reached `complete` or `partial`) are included in the merge list. Parents with no branch (blocked or skipped before spawn) are omitted.

If the merge has conflicts, the dependent task is marked `blocked` with exit_reason `dep-merge-conflict`. The child process is not spawned. `git merge --abort` is called and the partially-created branch is deleted.

If ALL parents are `blocked` or `skipped` (no parent branch exists), the task is blocked with `transitive-block` — no merge, no spawn.

### Integration branch

The supervisor creates `queue/<run_id>/result` at queue start. This is the integration branch — the moving accumulation target for all accepted task branches.

- **Created**: at queue start, forking from `base_rev`.
- **Updated**: each task branch that passes review (and has `merge_policy: auto`) is merged into it via `git merge --no-ff`. The integration branch moves forward; `base_rev` stays frozen.
- **Delivered**: at queue end, the integration branch is fast-forwarded into `base_branch` (typically `main`) as a single atomic operation. This is the only point where `main` is written.
- **Retained/deleted**: on successful delivery, deleted (cleanup). On failed or partial delivery, retained for morning inspection.

The integration branch is NOT subject to `branch_cleanup`. It follows its own lifecycle above.

### Iteration artifacts

Each intra-task loop iteration writes a JSONL file under the task's scratch directory. The naming grid is `<attempts>-<iter>.jsonl`:

- `attempts` — outer retry counter: `1` for a normal run, `2` when `retry_once` fires a second spawn.
- `iter` — intra-task loop counter within that attempt, starting at `1`.
- A `.stderr` sibling file is written alongside each JSONL.

Files live at `.scratch/queue-<run_id>-<task_id>/iterations/<attempts>-<iter>.jsonl`. Examples: `1-1.jsonl` and `1-2.jsonl` are the first and second iterations of the first attempt; `2-1.jsonl` is the first iteration after `retry_once` fires.

## Intra-task loop

The supervisor re-invokes `claude -p` per iteration until the task is terminal, `max_iterations` (default 10) is reached, or a trip-wire fires. Each iteration is a fresh `claude -p` process.

**Iteration 1** uses the original handoff body unchanged. **Iterations ≥ 2** prepend a short resumption header referencing the prior iteration's JSONL path, the current branch state, and the session-log location; the rest of the handoff body follows unchanged.

**Resumption header fields (iterations ≥ 2):** the supervisor prepends five fields before the original handoff body: task ID + current iteration/max-iterations, prior iteration end timestamp + status + exit_reason, session-log path, prior iteration JSONL path, and branch + current HEAD short-SHA. These are informational context for the child — they do not change the handoff body or entry skill.

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

## Supervisor environment variables

| Variable | Default | Purpose |
|---|---|---|
| `SPINE_QUEUE` | _(required)_ | Must be `1`; arms the PreToolUse guard hook |
| `SPINE_QUEUE_RL_BASE_SEC` | `120` | Rate-limit backoff base (seconds); test-mode only |
| `SPINE_QUEUE_REVIEW_TIMEOUT` | `1200` | Per-task review-stage wall-time cap (seconds). Mirrors the role of the implement-stage timeout. Increase for deep reviews on large diffs. |
| `SPINE_QUEUE_MERGE_TIMEOUT` | `1800` | Per-task merge-stage wall-time cap (seconds). Conflict resolution may take longer than review; increase for large multi-file conflicts. |

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
| `review-blocking-findings` | `/run-review` returned ≥1 blocking finding; task marked `blocked`; branch retained for inspection |
| `review-malformed-verdict` | `review-verdict.json` missing or unparseable after `/run-review` exits; fail-secure; task marked `blocked` |
| `merge-conflict-aborted` | _Historical (Slice H only)._ `git merge --no-ff` aborted on conflict before `/run-merge` was added. After Slice I this exit_reason is no longer produced — merge conflicts route through `_mrg_resolve_stage` and produce `merge-resolve-failed` or `merge-conflict-after-resolution`. May appear in old queue reports. |
| `merge-resolved-accepted` | `/run-merge` resolved all conflicts; re-review at `depth=focused` accepted; integration branch fast-forwarded |
| `merge-resolve-failed` | `/run-merge` returned `failed` or `aborted` verdict, or verdict file missing/malformed; `status=blocked`; branch retained |
| `merge-conflict-after-resolution` | Second merge conflict after `/run-merge` resolved the first (another task merged to integration in the interim); `status=blocked`; branch retained |
| `review-passed-pending-merge` | Review accepted but `merge_policy: manual`; branch flagged for manual merge; not auto-merged into integration branch |

## Open Questions (deferred past Slice B)

- Schema evolution: currently v1 is implicit. Adding a `schema_version` field at `queue.yaml` root is planned for v2 when the first breaking change lands.
- Distributed queues across multiple machines / repos: out of v1 scope.
- Parallel execution within topological order: Slice B is still linear within topo order. Concurrent independent branches arrive in a future slice.
