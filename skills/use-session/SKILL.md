---
name: use-session
description: >-
  Use when: 'session state', 'resume work', 'worktree session'.
argument-hint: "[init|attach|update|attention|terminal] [session-id/path]"
---

Workflow continuity contract. Keeps long-running Spine work reconstructable across
context loss, provider switch, and worktree switch.

## Core Directives

1. **Find or create one session directory.** Use explicit argument first, then the
   current `.scratch/<session>/` from the active workflow. If none exists, create
   `.scratch/<slug>-<hash>/` and bootstrap `session-log.md` before machine files.
2. **Maintain three durable files.**
   - `session.json` — atomic current-state snapshot.
   - `events.jsonl` — append-only event stream, one JSON object per line.
   - `session-log.md` — human-readable recovery log; required until consumers
     prove equivalent recovery from machine files.
3. **Single active writer.** Main workflow agent owns `session.json`,
   `events.jsonl`, and `session-log.md`. Subagents write assigned artifacts only.
   Worktree agent may write session files only after explicit attach to the same
   session.
4. **Fail closed on conflict.** Different active writer, branch, worktree path,
   contradictory session id, stale state, or missing terminal state => set
   `attention_required: true`, set `attention_reason`, append `attention`, stop.
5. **Atomic snapshot writes.** Write `session.json` to temp path in same directory,
   then `mv` into place. Never leave a partial JSON file.
6. **Append events only.** Never rewrite `events.jsonl`. Add monotonic `seq`,
   timestamp, actor, branch, and worktree path on every event.
7. **Worktree attach, not fork.** If `.scratch` is bridged into a worktree, reuse
   the existing session and append `session.attach`. Creating a second session for
   the same goal is a failure.
8. **Keep roles separate.** `use-session` stores continuity state only. It does
   not run DAGs, retries, permissions, review/merge automation, aggregation, or
   queue supervision.

Read `references/session-v1-contract.md` before creating or updating machine
state. Read `references/session-v1-examples.md` when writing examples, fixtures,
or proofs.

## Completion

- `session.json` valid JSON with schema version, status, writer, branch,
  worktree path, attention fields, and next step. [E3: `jq`]
- Every `events.jsonl` line valid JSON and tied to the same `session_id`. [E3:
  line-by-line `jq`]
- Terminal `session.json.status` (`complete`, `partial`, `blocked`) has a
  matching `terminal` event; otherwise mark `missing_terminal`. [E2/E3]
- `session-log.md` contains a phase row for the same current state. [E2]

## Anti-Patterns

- Forking a new session because the worktree path changed.
- Letting a subagent update session files.
- Treating `events.jsonl` as a replay engine or analytics stream.
- Hiding contradictions by choosing whichever file looks newer.
- Reintroducing `run-queue` behavior under a session name.
