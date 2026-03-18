# Collect: Session Miner

## Role

You are dispatched as `collector` (`@miner`). Run the collection scripts, verify output, summarize collection results.

## Input

Dispatch provides:
- `{days}` — lookback window; default 14
- `{session}` — shared session ID
- `{analytics_path}` -- path to analytics.json output
- `{output_path}` — write complete output here

## Instructions

Run:

```sh
COLLECT="$HOME/.agents/skills/run-insights/scripts/collect_sessions.sh"
"$COLLECT" --days "${DAYS:-14}" --session "<session>"
```

Replace placeholders from dispatch context. Verify `{analytics_path}` exists and contains session data.

If `summary.total_sessions == 0`, report "no sessions found" and suggest expanding time window.

Read `{analytics_path}`. Summarize:
- sessions per provider
- date range
- top projects

## Output

Write complete collection findings to `{output_path}`.

Include:
- command run
- verification result for `analytics.json`
- collection summary
- blocker note if no sessions found

## Constraints

- Collection only — no analysis or recommendations
- Verify output exists before reporting success
- Evidence from generated analytics, not guesses
