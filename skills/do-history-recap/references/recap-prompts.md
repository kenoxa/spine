# Recap Prompt Templates

## Shared Preamble

Include at start of every miner dispatch, substituting `{variables}`, before format-specific template.

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
5. Round to whole hours for timesheet (min 1h)
6. Cap: 8h/session, 8h/day
7. Prefix all estimates with `~`
### Task Description Derivation Priority
`brief_summary` > `title` > `thread_name` > `summary` > first `user_prompt` (truncated 80 chars) > `files_touched` paths > `"unspecified task"`
### Edge Cases
- `duration_minutes: 0` — treat as unknown, use estimation chain
- No task description — use "unspecified task", note session ID
- Empty `user_prompts` AND no summary — fall back to `files_touched`; if also empty, "unspecified task"
- Git log supplements, never replaces session-derived descriptions
- Git commits but no session description — use most relevant commit message
### Session Data
Read from scratch directory; skip missing files. Structure: `{"provider": "name", "sessions": [...]}`.
- `{scratch_dir}/claude_sessions.json`
- `{scratch_dir}/codex_sessions.json`
- `{scratch_dir}/cursor_sessions.json`
- `{scratch_dir}/git_log.json` — commit log keyed by project (supplementary)
### Project Filter
{project_filter}

Match against each session's `project` field (e.g., `kenoxa/spine`).

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

## website
- Update auth session handling (~2h)

No sessions → "No AI sessions found in the last {date_range}."
Filter matches nothing → "No sessions found for project matching '<filter>'." (raw filter value, not preamble instruction) + available project names.

Write complete output to {output_path}.
```

## Timesheet Prompt Template
```
Produce a billable timesheet from AI-assisted work sessions.

{preamble}

## Duration & Time Rules
- Map timestamps to nearest whole hour within 9:00–17:00
- Outside 9–17: normalize into workday window
- Round to whole hours (minimum 1h per entry)
- Max 8h/day; if exceeded, compress proportionally
- Consolidate sub-hour sessions on same project into one entry
## Output Format
Group by date (most recent first):
- `### YYYY-MM-DD (Weekday)`
- `HH-HH project-name: task description`
- `**Total: Nh**` per day
- Grand total at bottom
### Worked Example
Input: Claude session at 14:32, estimated ~45 min, project "spine", brief_summary "Add recap skill"
Output: `14-15 spine: Add recap skill`

Input: Cursor session at 09:15, 3 user prompts (~15 min estimated, rounds to 1h), project "website", title "Fix auth"
Output: `9-10 website: Fix auth`
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
Produce a narrative work recap from AI-assisted work sessions.

{preamble}

### Analytics Summary
{analytics_summary}

## Output Format
1. **Header**: date range, sessions, providers, total estimated hours
2. **Per-project**: narrative of accomplishments, key files changed, challenges
3. **Metrics**: hours by project, sessions by provider, files touched
4. If commit_stats available: lines added/deleted
5. If multiple providers: note cross-tool usage patterns

Professional, concise. Each project section should be 2-4 sentences.

No sessions → "No AI sessions found in the last {date_range}."

Write complete output to {output_path}.
```
