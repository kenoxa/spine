# Template: Recap

Format-specific prompt template for `@miner` narrative recap dispatch. Combined with [dispatch-preamble.md](dispatch-preamble.md) at dispatch time.

## Prompt

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
