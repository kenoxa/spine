---
name: handoff
description: >
  Distill current session context into a structured prompt for a fresh session.
  Use when handing off work mid-session — discovered bugs, emerging features,
  follow-up tasks, or continuation after hitting context limits. Also trigger
  when the user says "hand this off", "create a handoff", "package this for
  a new session", or "continue in a new chat".
  Do NOT use for session summaries without a continuation goal (use
  run-recap) or for cross-skill phase transitions (built into
  do-analyze and do-build).
argument-hint: "[direction or goal for the next session]"
---

Distill accumulated session context into a self-contained prompt a fresh session can act on.

## Workflow

1. **Gather** — inventory goal, files, decisions, discoveries, progress. Run `git branch --show-current` and `git status --short`. If `.scratch/<session>/session-log.md` exists, read as primary source for Current State (prefer over conversation reconstruction). Insufficient context → ask what to include rather than producing hollow artifact.
2. **Filter** — select relevant context using user's direction. Goal-directed distillation, not a session dump. No direction → derive goal from session's overall purpose.
3. **Structure** — produce the handoff artifact using the sections below.
4. **Write** — save to `.scratch/handoff-<slug>-<hash>.md` where `slug` is 5–7 words
   from the direction and `hash` is 4 hex chars from `openssl rand -hex 2` (e.g., `handoff-fix-auth-token-refresh-retry-logic-3c8d.md`).
   Create the directory if needed. Display the full artifact inline.
5. **Confirm** — present for user review. The user may adjust, approve, or discard.

## Artifact Format

Actionable without session history — no "what we discussed", no conversation-turn pointers. All paths repo-relative. Under 800 tokens — longer means Filter was too loose.

| Section | Required | Content |
|---------|----------|---------|
| Goal | Always | One sentence: next session's objective, from user's direction. |
| Context | Always | Key decisions, approaches tried, discoveries. Tag material claims with E-levels. |
| Files | When relevant | Repo-relative paths annotated: `modified`, `read`, `created`, `planned`. |
| Current State | Always | Done, in progress, blocked. Note uncommitted changes and branch. |
| Open Questions | When unresolved | Blocking or advisory unknowns. Omit if none. |
| Suggested Approach | When signal exists | How to proceed or which skill to start. Omit when clear from Goal + Context. |

## Anti-Patterns

- Dumping the session transcript instead of distilling toward the stated direction
- Including files not relevant to the handoff goal
- Omitting uncommitted changes that affect the next session's starting state
- Referencing conversation turns ("as we discussed") instead of stating facts directly
- Including secrets, tokens, or credentials in the artifact
