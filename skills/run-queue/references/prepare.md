# Prepare Phase

**Invariants: never materialize `queue.yaml` or handoff frontmatter without explicit user confirmation. Audit every handoff for a well-formed resumption contract before Kick.**

Phase goal: help the user assemble a queue from existing project artifacts — scan for handoff candidates, audit their contracts, propose a DAG, and materialize only after confirmation.

## Steps

### 1. Discovery

Scan for handoff candidates in two locations:

- `.scratch/handoff-*.md` — handoffs already authored for a new session (most common source).
- `docs/specs/*/` — spec directories that contain a handoff or can be packaged as one.

List each discovered file with a one-line purpose (derived from the handoff `Goal:` section or spec title). Present the list to the user before proceeding. Ask the user to confirm which candidates to include and exclude.

### 2. Handoff-contract audit

For each candidate handoff the user wants to include, verify that its frontmatter meets the queue task-intrinsics contract. Flag any violation before reaching Kick — a missing contract is cheaper to fix here than after the supervisor spawns.

Required fields (per [queue-schema.md](queue-schema.md)):

| Field | Check |
|-------|-------|
| `task_id` | Present; contains no whitespace (lint rule F3) |
| `entry_skill` | Present and the named skill file exists |
| `terminal_artifact` OR `terminal_check` | Exactly one of the two is declared |

Optional fields — validate only when present:

| Field | Check |
|-------|-------|
| `max_iterations` | Positive integer |
| `on_failure` | One of `stop` (default), `skip`, `retry_once` |
| `scope_files` | YAML list |
| `commit_ceiling` | Positive integer |

For each violation, report: file path, field name, what was found (or "missing"), and the required value or format. Do not propose DAG ordering until all included handoffs pass the audit.

### 3. Roadmap proposal

After the audit passes for all included candidates, propose a DAG:

- Which handoffs become tasks (one task per handoff file).
- `depends_on` edges — infer from the handoffs' own context (e.g., a fix-auth task that depends on a refactor-auth task). Surface the inferred edges explicitly and ask the user to confirm or adjust.
- Topological ordering — present tasks in the order the supervisor will attempt them (linear within topo order; independent tasks can run in any order at the supervisor's discretion).

Show a short summary table: `task_id`, `entry_skill`, `on_failure`, `depends_on`. Wait for explicit user confirmation before proceeding to materialization.

### 4. Materialization

After user confirms the DAG:

1. Write `<queue-dir>/queue.yaml` with the confirmed `run_id`, `base_branch` (default: current HEAD branch), and task list.
2. Ensure each handoff file has the required frontmatter fields. If a field is missing and the value is unambiguous from context, propose a specific value — do not silently fill it in.
3. Generate `<queue-dir>/profile.json` only if the user requests queue-specific permission overrides. Most queues do not need one.

Never write any file before reaching this step. Never write without an explicit "yes" from the user.

Proceed to the [Kick phase](kick.md) once the queue directory is ready.
