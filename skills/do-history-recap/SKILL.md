---
name: do-history-recap
description: >
  Summarize work done across AI agent sessions for standups, timesheets, and
  activity reports. Use this skill whenever the user asks for a recap, summary,
  standup update, timesheet, or activity report of their AI-assisted work. Trigger
  phrases: "what did I do", "standup update", "weekly recap", "timesheet",
  "activity report", "summarize my work", "what was done", "session recap",
  "daily summary", "weekly summary". Shares session parsing infrastructure with
  do-history-insights.
  Do NOT use for workflow improvement recommendations (use do-history-insights)
  or single-session code review (use do-review).
argument-hint: "[--days N, default 7] [--format standup|timesheet|recap] [--project filter]"
---

Summarize AI-assisted work across sessions. Reuses the session parsers from `do-history-insights/scripts/` to collect and normalize session data, then produces human-readable work summaries.

## Phases (planned)

### 1. Collect

Same as `do-history-insights` phase 1 — run parser scripts to extract session data into `analytics.json`.

### 2. Summarize

Extract work-focused data from `analytics.json`: files changed, tasks completed, projects touched, time spent. Group by project and date.

### 3. Format

Transform the summary into the requested output format:

- **standup** — brief bullet points of what was done, grouped by project
- **timesheet** — date/duration/project/task table suitable for time tracking
- **recap** — narrative summary with key accomplishments and metrics

### 4. Present

Display formatted output in the terminal. Support markdown and plain text.

## Status

Skeleton — implementation planned. The session parsing infrastructure in `do-history-insights/scripts/` is ready to reuse.
