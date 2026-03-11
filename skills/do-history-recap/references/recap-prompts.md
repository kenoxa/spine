# Recap Prompt Templates

## Shared Preamble

Prepend to every miner dispatch. Substitute `{variables}` before format template.

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

## Standup Prompt Template
```
Produce a standup update from AI-assisted work sessions.

{preamble}

## Output Format
Group by project:
- Heading: `## project-name`
- One bullet per logical task (merge related sessions)
- Bullet: task description + estimated duration + session count if > 1
- Total duration per project

Example:

## spine
- Implement history-recap skill (~3h, 2 sessions)
- Fix parser edge case for empty prompts (~1h)

No sessions → "No AI sessions found in the last {date_range}."
Filter matches nothing → "No sessions found for project matching '<filter>'." (raw filter value, not preamble instruction) + available project names.

Write complete output to {output_path}.
```

## Timesheet Prompt Template
```
Produce a billable timesheet from AI-assisted work sessions.

{preamble}

## Duration & Time Rules
- Map to nearest whole hour within 9:00–17:00; outside 9-17: normalize into workday window
- Round to whole hours (min 1h); max 8h/day (compress proportionally); consolidate sub-hour same-project sessions
## Output Format
Group by date (most recent first):
- `### YYYY-MM-DD (Weekday)`
- `HH-HH project-name: task description`
- `**Total: Nh**` per day
- Grand total at bottom
### Worked Example
Input: Claude, 14:32, ~45 min, project "spine", brief_summary "Add recap skill" → `14-15 spine: Add recap skill`
Input: Cursor, 09:15, 3 prompts (~15 min → 1h), project "website", title "Fix auth" → `9-10 website: Fix auth`
### Example Output
### 2026-03-10 (Tuesday)
9-12  spine: Implement history-recap skill
13-15 website: Fix auth session handling
15-17 spine: Add parser test coverage
**Total: 8h**

### 2026-03-09 (Monday)
9-11  spine: Debug collection phase
11-12 website: Update landing page
**Total: 3h**

**Grand total: 11h**

All estimated → append: "Note: All durations are estimates based on session activity."
No sessions → "No AI sessions found in the last {date_range}."

Write complete output to {output_path}.
```

## Recap Prompt Template
```
Produce narrative work recap from AI-assisted work sessions.

{preamble}

### Analytics Summary
{analytics_summary}

## Output Format
1. **Header**: date range, sessions, providers, total estimated hours
2. **Per-project**: narrative of accomplishments, key files changed, challenges
3. **Metrics**: hours by project, sessions by provider, files touched
4. If commit_stats available: lines added/deleted
5. If multiple providers: note cross-tool usage patterns

Concise. 2-4 sentences per project.

No sessions → "No AI sessions found in the last {date_range}."

Write complete output to {output_path}.
```
