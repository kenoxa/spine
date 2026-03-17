# Dispatch Preamble

Shared preamble for `@miner` dispatch — not a standalone role, prepended to every format template.

## Input

- `{scratch_dir}` — session scratch directory path
- `{project_filter}` — substituted filter instruction or "No filter. Include all sessions."

## Instructions

### Provider Field Availability
| Field | Claude | Codex | Cursor |
|-------|--------|-------|--------|
| duration_minutes | yes (0 = unknown) | yes | NO (null) |
| brief_summary | Tier1 only | no | no |
| underlying_goal | Tier1 only | no | no |
| thread_name | no | yes | no |
| title | no | no | yes |
| summary | no | no | yes |
| user_prompts | yes (up to 10) | yes (up to 10) | yes |
| files_touched | yes (up to 20) | yes (up to 20) | yes |
| tokens | yes (input/output) | no | no |

### Duration Estimation Priority
1. `duration_minutes` if > 0 (0 = unknown, treat as missing)
2. Token-based: `(tokens.input + tokens.output) / 800` min — Claude only
3. `len(user_prompts) * 5` min
4. Default: 15 min

Post-process: round to whole hours (min 1h), cap 8h/session + 8h/day, prefix `~`.

### Task Description Derivation Priority
`brief_summary` > `title` > `thread_name` > `summary` > first `user_prompt` (truncated 80 chars) > `files_touched` paths > `"unspecified task"`

### Edge Cases
- `duration_minutes: 0` — treat as unknown, use estimation chain
- No task description — use "unspecified task", note session ID
- Empty `user_prompts` AND no summary — fall back to `files_touched`; if also empty, "unspecified task"
- Git log supplements session data; if no session description, use most relevant commit message

### Session Data
Scratch dir; skip missing files. Structure: `{"provider": "name", "sessions": [...]}`.
- `{scratch_dir}/claude_sessions.json`
- `{scratch_dir}/codex_sessions.json`
- `{scratch_dir}/cursor_sessions.json`
- `{scratch_dir}/git_log.json` — commit log keyed by project (supplementary)

### Project Filter
{project_filter} — match against each session's `project` field (e.g., `kenoxa/spine`).

## Output

N/A — preamble only. Combined with format template at dispatch time.

## Constraints

Substitute `{scratch_dir}` and `{project_filter}` before combining with format-specific template.
