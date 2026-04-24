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
profile: profile.json                        # REQUIRED; path relative to queue-dir
backoff_cap_ms: 1800000                      # OPTIONAL; default 1800000 (30 min); Slice C

# --- tasks ---
tasks:
  - id: refactor-auth                        # REQUIRED; matches handoff-<id>.md
    handoff: handoff-refactor-auth.md        # OPTIONAL; defaults to handoff-<id>.md
    depends_on: []                           # OPTIONAL; default [] (independent)

  - id: fix-login-bug
    depends_on: [refactor-auth]

  - id: add-signup-page
    depends_on: [refactor-auth]              # runs in parallel with fix-login-bug in Slice B
```

Required top-level: `run_id`, `profile`, `tasks`.
Required per task: `id`. Other task fields default as documented.

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
max_budget_usd: 2.50                        # forwarded to claude -p --max-budget-usd
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
| `profile` file exists and is valid JSON | `profile not found \| profile invalid json` |
| `on_failure` in {stop, skip, retry_once} | `<task>: invalid on_failure: <v>` |
| `max_iterations` is a positive integer | `<task>: invalid max_iterations: <v>` |

## Branch naming

Per task, the supervisor creates local branch `queue/<run_id>/<task_id>`. The supervisor refuses to start if any such branch already exists — to namespace a re-run, change `run_id` or delete old branches.

For independent tasks, the branch forks from `base_rev = rev-parse(base_branch or HEAD-at-start)`. For DAG-child tasks (Slice B), the branch forks from a merge of all `depends_on` branch heads (`git merge --no-ff`).

## Open Questions (deferred past Slice A)

- Schema evolution: currently v1 is implicit. Adding a `schema_version` field at `queue.yaml` root is planned for v2 when the first breaking change lands.
- Distributed queues across multiple machines / repos: out of v1 scope.
