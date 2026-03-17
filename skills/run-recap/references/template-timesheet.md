# Template: Timesheet

Format-specific prompt template for `@miner` timesheet dispatch. Combined with [dispatch-preamble.md](dispatch-preamble.md) at dispatch time.

## Prompt

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
