# Recap Prompt Templates

## Shared Preamble

Include this section at the start of every miner dispatch prompt, substituting the `{variables}` below, before the format-specific template.

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

1. `duration_minutes` if present AND > 0 (Claude defaults 0 = unknown — treat as missing)
2. Token-based: `(tokens.input + tokens.output) / 800` minutes — only for Claude sessions with token data
3. `len(user_prompts) * 5` minutes
4. Default: 15 minutes
5. Round to whole hours for timesheet (minimum 1 hour)
6. Cap: 8 hours per session, 8 hours per day
7. Mark all estimated durations with `~` prefix

### Task Description Derivation Priority

`brief_summary` > `title` > `thread_name` > `summary` > first `user_prompt` (truncated 80 chars) > file paths from `files_touched` > `"unspecified task"`

### Edge Cases

- `duration_minutes: 0` — treat as unknown, apply estimation chain
- Session with no identifiable task description — use "unspecified task" and note the session ID
- Empty `user_prompts` AND no summary fields — rely on `files_touched` for context; if also empty, "unspecified task"
- Git log entries supplement but never replace session-derived descriptions
- When git log has commits but session has no description, use the most relevant commit message as the task description

### Session Data

Read session data from these files in the scratch directory. Skip any file that does not exist. Each `*_sessions.json` file has the structure `{"provider": "name", "sessions": [...]}` — iterate the `sessions` array.

- `{scratch_dir}/claude_sessions.json` — Claude Code sessions
- `{scratch_dir}/codex_sessions.json` — Codex sessions
- `{scratch_dir}/cursor_sessions.json` — Cursor sessions
- `{scratch_dir}/git_log.json` — Git commit log keyed by project name (supplementary)

### Project Filter

{project_filter}

Each session object has a `project` field (e.g., `kenoxa/spine`). Match against `project`.

## Standup Prompt Template

```
You are producing a standup update from AI-assisted work sessions.

{preamble}

## Output Format

Group by project. For each project:
- Heading: `## project-name`
- Bullet points: one per logical task (merge related sessions)
- Each bullet: task description + estimated duration + session count when > 1
- Include total duration per project

Example:

## spine
- Implement history-recap skill (~3h, 2 sessions)
- Fix parser edge case for empty prompts (~1h)

## website
- Update auth session handling (~2h)

If no sessions found: "No AI sessions found in the last {date_range}."
If project filter matches nothing: "No sessions found for project matching '<filter>'." (use the raw filter value, not the preamble instruction) followed by available project names.

Write your complete output to {output_path}.
```

## Timesheet Prompt Template

```
You are producing a billable timesheet from AI-assisted work sessions.

{preamble}

## Duration & Time Rules

- Map each session's timestamp to the nearest whole hour within 9:00-17:00
- Sessions outside 9-17 (evening/weekend): normalize into the workday window
- Round durations to whole hours (minimum 1 hour per entry)
- Maximum 8 hours per day; if exceeded, compress proportionally
- Consolidate sub-hour sessions on the same project into one entry

## Output Format

Group by date (most recent first). For each day:
- Heading: `### YYYY-MM-DD (Weekday)`
- Entries: `HH-HH project-name: task description`
- Daily total: `**Total: Nh**`
- Grand total at the bottom

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

If all durations are estimated, add: "Note: All durations are estimates based on session activity."
If no sessions found: "No AI sessions found in the last {date_range}."

Write your complete output to {output_path}.
```

## Recap Prompt Template

```
You are producing a narrative work recap from AI-assisted work sessions.

{preamble}

### Analytics Summary
{analytics_summary}

## Output Format

Structure:
1. **Header**: date range, total sessions, providers used, total estimated hours
2. **Per-project sections**: narrative paragraphs describing what was accomplished, key files changed, challenges noted
3. **Metrics**: total hours by project, sessions by provider, files touched count
4. If commit_stats available in analytics: lines added/deleted
5. If multiple providers: note cross-tool usage patterns

Keep the tone professional but concise. Each project section should be 2-4 sentences.

If no sessions found: "No AI sessions found in the last {date_range}."

Write your complete output to {output_path}.
```
