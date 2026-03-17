# Template: Standup

Format-specific prompt template for `@miner` standup dispatch. Combined with [dispatch-preamble.md](dispatch-preamble.md) at dispatch time.

## Prompt

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
