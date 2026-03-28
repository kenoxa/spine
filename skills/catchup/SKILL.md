---
name: catchup
description: >
  Reconstruct session state after /clear or compaction. Use when resuming a
  session, recovering from context loss, or verifying state before continuing.
  Also trigger on "catch up", "what's the session state", "resume session",
  "pick up where we left off", or after any /clear or auto-compaction.
  Do NOT use for creating new sessions — start with do-analyze or do-consult.
argument-hint: "[session-id or path to session artifacts]"
---

Reconstruct working state from persisted session artifacts. Never guess state from conversation — read the filesystem.

## Phases

### 1. Locate

Priority order (stop when found):
1. Explicit argument: `<session-id>` → look for `.scratch/<session-id>/session-log.md`
2. Most recent `session-log.md` by mtime: scan `.scratch/*/session-log.md`
3. Most recent `handoff-*.md` by mtime: scan `.scratch/handoff-*.md`

Report what was found and its path. If nothing found: stop with "No session state found. Pass a session ID or run handoff before /clear."

### 2. Ingest

Read all found artifacts:
- `session-log.md` — primary source (decisions, rationale, phase transitions)
- `handoff-*.md` — supplementary (goal, current state, open questions, suggested approach)
- `plan.md` — if exists in session directory (task list, completion criteria)

Build state inventory: current phase, open decisions, rejected approaches, uncommitted files, next step.

### 3. Verify

Present reconstructed state. Ask: "Does this match your understanding?"

Run `git status --short` and `git branch --show-current` — confirm file state matches session record.

State display:
- **Phase**: where in the workflow (discuss/plan/execute/commit)
- **Decisions**: key decisions made with rationale
- **Rejected**: approaches ruled out and why
- **Open**: unresolved questions or blocking items
- **Files**: uncommitted changes relevant to session
- **Next step**: recommended action

### 4. Resume

After user confirms state, recommend the next skill to invoke:
- In-progress build → `/do-build`
- No direction yet → `/do-consult`
- Plan complete, no commit → `/commit`
- Unclear phase → ask before recommending

## Anti-Patterns

- Reconstructing state from conversation history when session-log.md exists
- Resuming without user confirmation of reconstructed state
- Recommending next step before Verify phase completes
