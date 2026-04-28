# Prepare Phase

**Invariants: never materialize `queue.yaml` or handoff files without explicit user confirmation. Audit every handoff for a well-formed resumption contract before Kick.**

Phase goal: assemble a queue from any combination of conversational task descriptions and pre-authored handoff files. Draft well-formed handoffs for new tasks, audit all contracts, propose a DAG, and materialize only after two confirmation gates.

## Steps

### 1. Intake and Discovery

Two input modes — handle both, then merge into one candidate list.

**Pre-authored handoffs**: scan `.scratch/handoff-*.md` and `docs/specs/*/` for existing handoff candidates. List each with a one-line purpose from the handoff `Goal:` section or spec title.

**Conversational tasks**: if the user has described tasks in the current conversation, treat each as a candidate. Also check `TODO.md` and open items in `docs/specs/*/progress.md`.

For each conversationally described task, draft a handoff. Three fields are required — prompt the user if any are missing or ambiguous:

| Field | What to draft |
|-------|---------------|
| Success criterion | One sentence with a concrete observable outcome (e.g., "auth tests pass and session TTL extends on each API call") |
| File/symbol scope | Explicit files or directories; verify each against the repo and flag any that do not exist |
| Not-in-scope boundary | One sentence bounding what the task does NOT do |

Plus skill-derivable metadata (propose, do not assume):

| Field | How to derive |
|-------|--------------|
| `task_id` | Slug from description — lowercase, alphanumeric + hyphens, no whitespace |
| `entry_skill` | Default `/do-build`; ask explicitly if the task does not map to a build workflow |
| `terminal_artifact` | **Only for `/do-build`**: derive as `.scratch/queue-<run_id>-<task_id>/build-status.json`. For any other entry skill, ask — the supervisor waits forever on a path the skill never writes. |

Hybrid mode: if pre-authored handoffs and conversational tasks both exist, include both. Mark drafted tasks visually distinct (e.g., "drafted" tag) so the user knows which ones the agent authored.

Present the full candidate list. Ask the user to confirm which to include before proceeding.

### 2. Gate 1 — Draft review

For each included task, show its full contract:

```
Task: <task_id>   [drafted | pre-authored]
Entry skill:      <entry_skill>
Success criterion: ...
File scope:       ...
Not in scope:     ...
Terminal artifact: ...
```

User reviews each task. If a task needs revision, re-draft that task only and re-show it. Repeat per-task until accepted. Pre-authored handoffs are shown in the same format; propose edits but do not silently rewrite pre-authored content.

Gate 1 closes when the user has accepted every task.

### 3. Handoff-contract audit

After Gate 1, verify all accepted handoffs — both drafted and pre-authored — against the required contract:

| Field | Check |
|-------|-------|
| `task_id` | Present; no whitespace (lint rule F3) |
| `entry_skill` | Present; the named skill file exists in the repo |
| `terminal_artifact` OR `terminal_check` | Exactly one declared |

For drafted handoffs: additionally verify the `terminal_artifact` path is consistent with the entry skill's documented write contract. Flag mismatches before proceeding.

For each violation: report file path, field name, what was found (or "missing"), and the required value or format. Do not proceed to DAG proposal until all violations are resolved.

### 4. Roadmap proposal

After the audit passes, propose the DAG:

- One task per handoff file.
- `depends_on` edges — infer from handoff context and task semantics. Surface inferred edges explicitly and ask the user to confirm or adjust.
- Topological order — present tasks in the order the supervisor will attempt them.

Show a summary table: `task_id`, `entry_skill`, `on_failure`, `depends_on`.

### 5. Gate 2 — DAG + materialization confirm

Show what will be written:

- DAG shape (e.g., `A → B`, `C independent`)
- Files: `<queue-dir>/queue.yaml` + each drafted handoff file path (pre-authored files are not rewritten)
- Run ID and base branch

Ask for explicit "yes" before writing any file. An unclear response → ask again. Never auto-proceed.

On confirm:
1. Write `<queue-dir>/queue.yaml` with the confirmed `run_id`, `base_branch`, and task list.
2. Write each drafted handoff file to `<queue-dir>/`. Do not rewrite pre-authored files.
3. Generate `<queue-dir>/profile.json` only if the user requested queue-specific permission overrides.

Proceed to the [Kick phase](kick.md).
