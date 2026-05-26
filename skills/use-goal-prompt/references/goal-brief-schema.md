# Goal Brief Schema

Emitted by `/use-goal-prompt` when rendered goal-prompt references overflow context. Path: `.scratch/<session>/goal-brief.md`.

## Required Sections

### Session Reference
```
Session: `<session-id>`
Design artifact: `.scratch/<session>/design-artifact.md` (authoritative — read first)
Frame artifact: `.scratch/<session>/frame-artifact.md`
```

### Authoritative Artifact Paths

One line per artifact path + role annotation. Design artifact is always authoritative.

### Per-Slice File Lists + Verification Recipes

For each slice:
- **Files (write/edit/delete):** exact repo-relative paths
- **Verification recipe:** numbered steps + expected outputs
- **Pass criteria:** condition gating the next slice
- **Fail action:** what to write to `build-status.json` + whether to halt

### build-status.json Schema

```json
{ "session", "slice", "status": "pass|blocked|failed",
  "reason", "evidence": [...], "learnings": [...], "next" }
```

Emit on ALL outcomes. `learnings` is MANDATORY.

### Failure Escalation Table

| Failure | Action |
|---------|--------|
| Slice N fails | `build-status` blocked + halt; escalate to frame |
| Render >4000 chars | tighten content; NEVER raise the cap |
| Lint/gate violation | fix or surface; never weaken gate |

### Constraints Reminder

MUST/SHOULD/MAY carried from frame artifact. One line per constraint with source tag (M/S/Y + number).
