---
name: run-recap
description: >-
  Use when: 'what did I do', 'standup', 'timesheet', 'billing'.
argument-hint: "[--days N, default 7] [--format standup|timesheet|recap] [--project filter] [--note 'DATE HH-HH: description [project]']"
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

**Pre-compute before dispatch**:
- Working days in range (exclude weekends + Berlin Feiertage); inject as `{working_days}`
- `--project` values → `{known_projects}`
- `--note` values → `{hard_pinned_notes}`
- Preserve every detected customer project as candidate billable work; the miner decides allocation from evidence, not session-count dominance.

Construct prompt by combining:
1. [dispatch-preamble.md](references/dispatch-preamble.md) — substitute `{days}`, `{scratch_dir}`, `{project_filter}`, `{working_days}`, `{known_projects}`, `{hard_pinned_notes}`
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
- Inventing task descriptions — follow full fallback chain (brief_summary → underlying_goal → title → thread_name → summary → all user_prompts → files_touched → git commit → session ID placeholder); never use "unspecified task"
- Collapsing smaller customer projects into the dominant repo when they have explicit session, prompt, file, or commit evidence
- Customer-facing timesheet lines that name internal process labels instead of the product scenario or release value
- Activity descriptions instead of outcome descriptions — "investigated X" is not billable language; "X now works correctly for customers" is
- Weak prose: passive voice, vague quantities ("significant"), banned AI vocabulary (leverage, robust, seamless) — see Writing Quality section in template-timesheet.md
- Multiple subagent dispatches — single `@miner` per invocation
- Modifying scripts in `run-insights/scripts/`
