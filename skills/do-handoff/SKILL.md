---
name: do-handoff
description: >
  Distill current session context into a structured prompt for a fresh session.
  Use when handing off work mid-session — discovered bugs, emerging features,
  follow-up tasks, or continuation after hitting context limits. Also trigger
  when the user says "hand this off", "create a handoff", "package this for
  a new session", or "continue in a new chat".
  Do NOT use for session summaries without a continuation goal (use
  do-history-recap) or for cross-skill phase transitions (built into
  do-discuss and do-execute).
argument-hint: "[direction or goal for the next session]"
---

Distill accumulated session context into a self-contained prompt a fresh session can act on.

## Workflow

1. **Gather** — inventory the session: goal pursued, files read or modified, decisions
   made, discoveries, current progress. Run `git branch --show-current` and
   `git status --short` to capture branch and dirty state. If a session log exists
   at `.scratch/<session>/session-log.md` (where `<session>` is the current session
   ID from conversation context), read it as the primary source for the Current
   State section. Prefer log entries over conversation-turn reconstruction. If the
   session lacks sufficient context for a useful handoff, report this and ask what
   to include rather than producing a hollow artifact.
2. **Filter** — use the user's direction to select relevant context. The direction
   shapes what gets extracted — this is goal-directed distillation, not a session
   dump. When no direction is given, derive the goal from the session's overall
   purpose.
3. **Structure** — produce the handoff artifact using the sections below.
4. **Write** — save to `.scratch/handoff-<slug>-<hash>.md` where `slug` is 2-4 words
   from the direction and `hash` is 4 random hex chars (e.g., `handoff-auth-bug-a3f2.md`).
   Create the directory if needed. Display the full artifact inline.
5. **Confirm** — present for user review. The user may adjust, approve, or discard.

## Artifact Format

The artifact must be actionable without this session's history — no references to
"what we discussed", no conversation-turn pointers. All paths repo-relative.
Aim for under 80 lines — if longer, the Filter step was too loose.

| Section | Required | Content |
|---------|----------|---------|
| Goal | Always | One sentence: what the next session should accomplish. Derived from user's direction. |
| Context | Always | Key decisions, approaches tried, discoveries. Tag material claims with evidence levels when they would change the receiving agent's approach. |
| Files | When relevant | Repo-relative paths annotated: `modified`, `read`, `created`, or `planned` (not yet created). |
| Current State | Always | What is done, in progress, blocked. Note uncommitted changes and current branch. |
| Open Questions | When unresolved items exist | Blocking or advisory unknowns. Omit entirely if none. |
| Suggested Approach | When agent has signal | Brief guidance on how to proceed or which skill to start with. Omit when clear from Goal + Context. |

## Anti-Patterns

- Dumping the session transcript instead of distilling toward the stated direction
- Including files not relevant to the handoff goal
- Omitting uncommitted changes that affect the next session's starting state
- Referencing conversation turns ("as we discussed") instead of stating facts directly
- Including secrets, tokens, or credentials in the artifact
