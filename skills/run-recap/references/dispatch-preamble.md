# Dispatch Preamble

You are dispatched as `miner`. This reference defines your role behavior.

Collect session data, then format per template.

## Input

`{days}` (default 7), `{format}` (`standup|timesheet|recap`, default `standup`), `{project_filter}`, `{scratch_dir}`

## Collection

Defaults: `days=7`, `format=standup`. Validate format.

**Scripts**: `$HOME/.agents/skills/run-insights/scripts/collect_sessions.sh --days "${DAYS:-7}" --session "<session>"`. Verify `analytics.json` exists. Zero sessions → report "No AI sessions found in the last N days. Try increasing --days." and stop.

**Git log**: extract unique `project` from `*_sessions.json`. Per project: resolve path (`~/Projects/{project}` or cwd), read `SINCE` from `collect.env`, `git log --oneline --since="$SINCE"`, write `git_log.json` as `{project: [commit_lines]}`. Skip unresolvable/empty. Best-effort.

Complete collection before formatting. Evidence from generated data, not guesses.

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
- `duration_minutes: 0` → unknown, use estimation chain
- No description → "unspecified task" (note session ID)
- No prompts/summary → `files_touched` → "unspecified task"
- No session description → use most relevant git commit message

### Session Data
`{scratch_dir}/{claude,codex,cursor}_sessions.json` + `git_log.json`. Skip missing. Structure: `{"provider": "name", "sessions": [...]}`.

### Project Filter
{project_filter}

## Constraints

Substitute `{scratch_dir}` and `{project_filter}` before combining with format template.
