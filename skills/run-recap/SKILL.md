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

Cross-tool AI session history reporting. Reuses `run-insights/scripts/` for Claude Code, Codex, Cursor data; dispatches single `@miner` subagent for standup bullets, billable timesheets, or narrative recaps.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context explicitly.

**Session ID**: Generate per SPINE.md Sessions convention. Reuse across all phases.

### 1. Collect

Parse arguments, run parser scripts, collect git log.

**Arguments**:
- `--days N` (default 7) — time window
- `--format standup|timesheet|recap` (default standup) — output format
- `--project filter` (optional) — case-insensitive substring match on project name

Generate session ID. Run parser scripts via Bash:

```bash
PYTHON=$(command -v python3 || command -v python)
if [ -z "$PYTHON" ]; then echo "Error: Python 3.9+ required but not found"; exit 1; fi
SINCE=$(date -v-${DAYS:-7}d +%Y-%m-%d)
SCRATCH=".scratch/<session>"
SCRIPTS="$HOME/.agents/skills/run-insights/scripts"
mkdir -p "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_claude.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_codex.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_cursor.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/aggregate.py" --input "$SCRATCH" --output "$SCRATCH/analytics.json"
```

Verify `analytics.json` exists and has sessions. If `summary.total_sessions == 0`, report "No AI sessions found in the last N days. Try increasing --days." and stop.

**Git log collection**: Extract unique `project` values from `*_sessions.json`. Resolve each to filesystem path via `~/Projects/{project}` or cwd. For each git repo, run `git log --since=$SINCE --oneline --no-merges`. Write to `.scratch/<session>/git_log.json` as `{project: [commit_lines]}`. Skip unresolvable projects, non-repos, or empty ranges. Best-effort.

### 2. Dispatch

Single `@miner` subagent dispatch. Mode: `recap`.

The miner reads session files from disk — pass scratch directory path, do not inline file contents.

Construct the dispatch prompt by combining:
1. Substitute into Shared Preamble from [references/recap-prompts.md](references/recap-prompts.md):
   - `{scratch_dir}` → `.scratch/<session>`
   - `{project_filter}` → if set: `Filter to sessions where \`project\` contains "<value>" (case-insensitive). If no match, list available projects.` — if not: `No filter. Include all sessions.`
2. Select format-specific template for `--format`. Substitute:
   - `{preamble}` → fully-substituted Shared Preamble
   - `{date_range}` → `N days (YYYY-MM-DD to YYYY-MM-DD)`
   - `{output_path}` → `.scratch/<session>/report-{format}.md`
   - `{analytics_summary}` (recap only) → `summary` object from `analytics.json` formatted as: `Total sessions: N. Date range: YYYY-MM-DD to YYYY-MM-DD. Providers: Claude N, Codex N, Cursor N. Avg duration: N min. Total prompts: N.` With active `--project` filter, append: `Sessions matching "<filter>": N.`

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `report-{format}` | `@miner` | Scratch dir path + format-specific prompt | `.scratch/<session>/report-{format}.md` |

### 3. Present

Read `.scratch/<session>/report-{format}.md`. Display directly as markdown. No post-processing — subagent output IS final output.

### Visual recap

Dispatch `@visualizer` if complexity warrants it or requested: work activity recap for <time-window>. Data: `.scratch/<session>/report-{format}.md`. Output: `.scratch/<session>/history-recap.html`. Otherwise suggest to user. Skip only if user has declined.

## Guidelines

- **Data source**: Miner reads raw `*_sessions.json` for detail; `analytics.json` for summary stats only
- **Project filter**: Case-insensitive substring on `session.project`. No match → list available projects.
- **Format-specific rules**: Encoded in prompt templates — do not override in dispatch

## Anti-Patterns

- Reading only `analytics.json` for detail — miner must read raw `*_sessions.json`
- Processing/formatting in main thread — dispatch to `@miner`
- Inventing task descriptions — use "unspecified task" with files list
- Multiple subagent dispatches — single `@miner` per invocation
- Modifying scripts in `run-insights/scripts/`
