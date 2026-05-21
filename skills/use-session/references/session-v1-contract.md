# Session V1 Contract

## `session.json`

Required fields:

| Field | Contract |
|---|---|
| `schema_version` | `1` |
| `session_id` | Directory basename under `.scratch/`; must match events |
| `mode` | `workflow`, `goal`, `worktree`, or `handoff` |
| `status` | `in_progress`, `complete`, `partial`, `blocked` |
| `attention_required` | Boolean; true means stop for user adjudication |
| `attention_reason` | `null`, `stale`, `writer_conflict`, `state_contradiction`, or `missing_terminal` |
| `current_phase` | Human phase label; matches latest meaningful event/log row |
| `next_step` | Concrete next action or terminal summary |
| `branch` | Active branch at last writer update |
| `worktree_path` | Absolute or repo-relative path of the active writer checkout |
| `active_writer` | `{id, provider, role, branch, worktree_path, started_at, last_seen_at}` |
| `artifacts` | Array of `{path, kind, status}` for linked outputs |
| `created_at`, `updated_at` | ISO-8601 timestamps |

`session.json` is a snapshot, not history. Update by writing a temp file in the
same directory and renaming it over the old snapshot.

## `events.jsonl`

Each line is one JSON object:

```json
{"schema_version":1,"session_id":"...","seq":1,"ts":"2026-05-21T10:00:00Z","type":"session.start","actor":{"id":"codex-main","role":"writer"},"branch":"main","worktree_path":".","payload":{}}
```

Allowed `type` values: `session.start`, `session.attach`, `phase.start`,
`phase.finish`, `decision`, `artifact`, `verification`, `attention`, `terminal`.

`terminal.payload.status` must be `complete`, `partial`, or `blocked`. Terminal
events are authoritative evidence that a non-`in_progress` snapshot really ended.

## Contradictions

Mark `attention_required` and stop when any condition is true:

- Directory basename, `session.json.session_id`, or event `session_id` disagree.
- `session.json.status` is terminal but no `terminal` event exists.
- Latest terminal event exists but `session.json.status` is `in_progress`.
- Current branch/worktree differs from `active_writer` while the old writer is
  still active and no `session.attach` event records the handoff.
- `session-log.md` reports a terminal state that conflicts with machine files.
- `updated_at` / `active_writer.last_seen_at` is stale for the workflow's stated
  resume window and no recent event explains the gap.

Do not resolve contradictions silently. Report both sides and ask for the next
writer.

## Worktree Attach

`use-worktree` bridges `.scratch` into `.worktrees/<slug>-<hash>/`. A writer in
that checkout attaches to the existing session: append `session.attach`, update
`active_writer.branch` and `active_writer.worktree_path`, then continue. If the
parent writer is still active, mark `writer_conflict` instead.
