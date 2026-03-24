---
name: run-recap
description: >
  Work reports from AI session history — standup bullets, billable timesheets, narrative recaps.
  Parses Claude Code, Codex, Cursor into project-grouped summaries with estimated hours.
  Use when: "what did I do", "standup update", "weekly recap", "timesheet",
  "activity report", "summarize my work", "what was done", "session recap",
  "daily summary", "weekly summary", "billing hours", "what I accomplished",
  "work report", "invoice my time", "quarterly review", "client report",
  or any query about work over a time period.
  Do NOT use for workflow/automation recommendations, session pattern analysis,
  cross-tool comparison (run-insights), single-session code review (run-review).
argument-hint: "[--days N, default 7] [--format standup|timesheet|recap] [--project filter]"
---

Cross-tool AI session history reporting. Reuses `run-insights/scripts/` for data; dispatches single `@miner` for format-specific report.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context explicitly.

**Reference paths** (backticked): dispatch to subagent — do NOT Read into mainthread.

**Session**: per SPINE.md; reuse across phases.

**Phase Trace**: Log row at dispatch, present. Include format.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Dispatch | `@miner` (`recap`) | [dispatch-preamble.md](references/dispatch-preamble.md), [template-*.md](references/) |
| Present | `@visualizer` | `references/present-visualizer.md` |

### 1. Dispatch

Generate session ID. Single `@miner` subagent dispatch — collects data then formats report. Mode: `recap`.

Construct prompt by combining:
1. [dispatch-preamble.md](references/dispatch-preamble.md) — substitute `{days}`, `{scratch_dir}`, and `{project_filter}`
2. Select template by `--format`:
   - `standup` → [template-standup.md](references/template-standup.md)
   - `timesheet` → [template-timesheet.md](references/template-timesheet.md)
   - `recap` → [template-recap.md](references/template-recap.md)
3. Substitute into template: `{preamble}`, `{date_range}`, `{output_path}`, `{analytics_summary}` (recap only)

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `report-{format}` | `@miner` | Scratch dir path + format-specific prompt | `.scratch/<session>/report-{format}.md` |

### 2. Present

Read `.scratch/<session>/report-{format}.md`. Display directly as markdown.

Dispatch `@visualizer` → `references/present-visualizer.md` if complexity warrants or requested. Input: `.scratch/<session>/report-{format}.md`. Output: `.scratch/<session>/history-recap.html`. Otherwise suggest. Skip if user declined.

## Anti-Patterns

- Reading only `analytics.json` for detail — miner must read raw `*_sessions.json`
- Processing/formatting in main thread — dispatch to `@miner`
- Inventing task descriptions — use "unspecified task" with files list
- Multiple subagent dispatches — single `@miner` per invocation
- Modifying scripts in `run-insights/scripts/`
