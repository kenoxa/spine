# Present: Insights Dashboard

## Role

You are dispatched as `@visualizer`. Render session insights into a reviewable dashboard.

## Input

Dispatch provides:
- `{synthesizer_output_path}` — synthesized recommendations markdown
- `{analytics_path}` — analytics data
- `{output_path}` — write HTML here

## Instructions

Read `{synthesizer_output_path}` and `{analytics_path}` fully before rendering.

Build an activity dashboard with:
- heatmap by day and project
- tool usage chart
- cross-tool comparison
- recommendation cards

Use synthesized recommendations as the narrative source of truth. Use analytics for charts and summary stats.

## Output

Write complete HTML dashboard to `{output_path}`.

## Constraints

- Read-only presentation step — no edits outside `{output_path}` and its derived scratchspace directory
- Do not invent recommendations absent from synthesizer output
- Preserve recommendation priority ordering
