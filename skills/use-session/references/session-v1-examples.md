# Session V1 Examples

## `session.json`

```json
{
  "schema_version": 1,
  "session_id": "goal-session-contract-be04",
  "mode": "goal",
  "status": "partial",
  "attention_required": true,
  "attention_reason": "writer_conflict",
  "current_phase": "verify",
  "next_step": "User selects the active writer before more session writes.",
  "branch": "main",
  "worktree_path": "/repo/.worktrees/session-proof-a1b2",
  "active_writer": {
    "id": "codex-main-019e49fa",
    "provider": "codex",
    "role": "writer",
    "branch": "main",
    "worktree_path": "/repo/.worktrees/session-proof-a1b2",
    "started_at": "2026-05-21T09:00:00Z",
    "last_seen_at": "2026-05-21T09:32:00Z"
  },
  "artifacts": [
    {"path": ".scratch/goal-session-contract-be04/goal.md", "kind": "goal", "status": "current"}
  ],
  "created_at": "2026-05-21T09:00:00Z",
  "updated_at": "2026-05-21T09:32:00Z"
}
```

## `events.jsonl`

```jsonl
{"schema_version":1,"session_id":"goal-session-contract-be04","seq":1,"ts":"2026-05-21T09:00:00Z","type":"session.start","actor":{"id":"codex-main-019e49fa","role":"writer"},"branch":"main","worktree_path":"/repo","payload":{"mode":"goal"}}
{"schema_version":1,"session_id":"goal-session-contract-be04","seq":2,"ts":"2026-05-21T09:10:00Z","type":"session.attach","actor":{"id":"codex-main-019e49fa","role":"writer"},"branch":"main","worktree_path":"/repo/.worktrees/session-proof-a1b2","payload":{"from_worktree_path":"/repo","via":"use-worktree bridge"}}
{"schema_version":1,"session_id":"goal-session-contract-be04","seq":3,"ts":"2026-05-21T09:30:00Z","type":"attention","actor":{"id":"codex-main-019e49fa","role":"writer"},"branch":"main","worktree_path":"/repo/.worktrees/session-proof-a1b2","payload":{"reason":"writer_conflict","other_writer":"claude-main-88"}}
{"schema_version":1,"session_id":"goal-session-contract-be04","seq":4,"ts":"2026-05-21T09:32:00Z","type":"terminal","actor":{"id":"codex-main-019e49fa","role":"writer"},"branch":"main","worktree_path":"/repo/.worktrees/session-proof-a1b2","payload":{"status":"partial","reason":"writer_conflict"}}
```

## Validation

```sh
jq -e '.schema_version == 1 and .session_id and .active_writer.id' session.json
while IFS= read -r line; do printf '%s\n' "$line" | jq -e '.schema_version == 1 and .session_id and .seq and .type'; done < events.jsonl
```
