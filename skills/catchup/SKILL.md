---
name: catchup
description: >-
  Use when: 'catch up', 'session state'.
argument-hint: "[session-id or path to session artifacts]"
---

Reconstruct working state from persisted session artifacts. Never guess state from
conversation — read the filesystem.

## Phases

### 1. Locate

If the explicit argument contains a `/`, treat it as a direct path. If it is a
file, read it and use its directory as the session directory. If it is a
directory, use it directly. Do not stop after one file when sibling session
artifacts exist.

Otherwise, use `fd` (preferred) or `ls -t` (fallback) to search within `.scratch/` — the Glob tool ignores gitignored paths.

Priority order (stop when found):
1. Explicit argument: `<session-id>` → `.scratch/<session-id>/`
2. Most recent `session.json` by mtime: `fd 'session\.json$' .scratch/ --max-depth 2 -t f -0 | xargs -0 ls -lt`
3. Most recent `session-log.md` by mtime: `fd 'session-log\.md$' .scratch/ --max-depth 2 -t f -0 | xargs -0 ls -lt`
4. Most recent `handoff-*.md` by mtime: `fd 'handoff-.*\.md$' .scratch/ --max-depth 2 -t f -0 | xargs -0 ls -lt`

Report what was found and its path. If nothing found: stop with "No session state found. Pass a session ID or run handoff before /clear."

### 2. Ingest

Read all found artifacts:
- `session.json` — machine current-state snapshot when present
- `events.jsonl` — recent event stream when present; read the latest meaningful events
- `session-log.md` — human recovery log; fallback primary source when machine files are absent
- `handoff-*.md` — supplementary (goal, current state, open questions, suggested approach)
- `plan.md` — if exists in session directory (task list, completion criteria)

Build state inventory: current phase, status, attention reason, active writer,
branch, worktree path, terminal state, open decisions, rejected approaches,
uncommitted files, next step.

If `session.json` exists, compare:
- directory basename vs `session_id`
- all event `session_id` values vs `session.json.session_id`
- terminal `session.json.status` vs latest `terminal` event
- `attention_required` / `attention_reason` vs latest `attention` event
- `session-log.md` current/terminal state vs machine files

Contradictions: report both sides exactly, mark the reconstructed state
`attention_required`, and stop. Do not choose a winner.

### 3. Verify

Present reconstructed state. Ask: "Does this match your understanding?"

Run `git status --short` and `git branch --show-current` — confirm file state matches session record.

State display:
- **Phase**: where in the workflow (discuss/plan/execute/commit)
- **Status**: `in_progress`, `complete`, `partial`, or `blocked`
- **Attention**: reason if machine files report stale/contradictory/conflicted state
- **Writer**: active writer id, branch, and worktree path when machine files exist
- **Recent events**: newest session/phase/decision/verification/attention/terminal events
- **Decisions**: key decisions made with rationale
- **Rejected**: approaches ruled out and why
- **Open**: unresolved questions or blocking items
- **Files**: uncommitted changes relevant to session
- **Next step**: recommended action

If `attention_required` is true, or if contradictions were found, do not
recommend a next skill. Ask the user to select the active writer or source of
truth.

### 4. Resume

After user confirms state, recommend the next skill to invoke:
- In-progress build → `/do-build`
- No direction yet → `/do-design`
- Plan complete, no commit → `/commit`
- Unclear phase → ask before recommending

## Anti-Patterns

- Reconstructing state from conversation history when session-log.md exists
- Resuming without user confirmation of reconstructed state
- Recommending next step before Verify phase completes
