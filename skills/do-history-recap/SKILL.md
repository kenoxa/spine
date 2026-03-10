---
name: do-history-recap
description: >
  Generate work reports from AI agent session history — standup bullets, billable
  timesheets, or narrative recaps. Parses session data from Claude Code, Codex,
  and Cursor to produce project-grouped summaries with estimated hours. Use this
  skill whenever the user wants to know what they worked on, needs to report time,
  or is preparing a work summary. Trigger on: "what did I do", "standup update",
  "weekly recap", "timesheet", "activity report", "summarize my work", "what was
  done", "session recap", "daily summary", "weekly summary", "billing hours",
  "what I accomplished", "work report", "invoice my time", "quarterly review",
  "client report". Also trigger when the user asks what they or their AI tools
  worked on over a time period, even without using the word "recap".
  Do NOT use for workflow improvement or automation recommendations (use
  do-history-insights), session pattern analysis (use do-history-insights),
  cross-tool comparison (use do-history-insights), or single-session code review
  (use do-review).
argument-hint: "[--days N, default 7] [--format standup|timesheet|recap] [--project filter]"
---

Work reporting from cross-tool AI session history. Reuses `do-history-insights/scripts/` to collect session data from Claude Code, Codex, and Cursor, then dispatches a single `@miner` subagent to produce standup bullets, billable timesheets, or narrative recaps.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context explicitly.

**Subagent dispatch policy**: Each role uses the `@miner` agent type. Every dispatch prompt MUST include:
- The exact output file path (`.scratch/<session>/<prescribed-filename>.md`)
- The constraint: "Write your complete output to that path. You may read any repository file. Do NOT edit, create, or delete files outside `.scratch/<session>/`. Do NOT run build commands, tests, or destructive shell commands."

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
SCRIPTS="$HOME/.agents/skills/do-history-insights/scripts"
mkdir -p "$SCRATCH"

PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_claude.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_codex.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_cursor.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/aggregate.py" --input "$SCRATCH" --output "$SCRATCH/analytics.json"
```

Verify `analytics.json` exists and has sessions. If `summary.total_sessions == 0`, report "No AI sessions found in the last N days. Try increasing --days." and stop.

**Git log collection**: After parsers run, extract unique `project` values from `*_sessions.json` files (e.g., `kenoxa/spine`, `carv/identity-scribe`). Resolve each to a filesystem path by checking `~/Projects/{project}` and the current working directory. For each resolved path that is a git repository, run `git log --since=$SINCE --oneline --no-merges`. Write results to `.scratch/<session>/git_log.json` as `{project: [commit_lines]}`. Skip projects that can't be resolved, aren't git repos, or have no commits in range. This is best-effort — not all projects will resolve.

### 2. Dispatch

Single `@miner` subagent dispatch. Mode: `recap`.

The miner reads session files directly from disk — do not inline file contents in the dispatch prompt. Pass the scratch directory path so the miner can read `*_sessions.json`, `git_log.json`, and `analytics.json` as needed.

Construct the dispatch prompt by combining:
1. Substitute variables into the Shared Preamble from [references/recap-prompts.md](references/recap-prompts.md):
   - `{scratch_dir}` → `.scratch/<session>`
   - `{project_filter}` → if `--project` is set: `Filter to sessions where \`project\` contains "<value>" (case-insensitive). If no match, list available projects.` — if not set: `No filter. Include all sessions.`
2. Select the format-specific template matching `--format`. Substitute:
   - `{preamble}` → the fully-substituted Shared Preamble from step 1
   - `{date_range}` → `N days (YYYY-MM-DD to YYYY-MM-DD)` using the `--days` value and computed start/end dates
   - `{output_path}` → `.scratch/<session>/report-{format}.md`
   - `{analytics_summary}` (recap format only) → read the `summary` object from `analytics.json` and format as: `Total sessions: N. Date range: YYYY-MM-DD to YYYY-MM-DD. Providers: Claude N, Codex N, Cursor N. Avg duration: N min. Total prompts: N.` If `--project` filter is active, append: `Sessions matching "<filter>": N.`

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `report-{format}` | `@miner` | Scratch dir path + format-specific prompt | `.scratch/<session>/report-{format}.md` |

### 3. Present

Read `.scratch/<session>/report-{format}.md`. Display the contents directly in the terminal as markdown. No post-processing — the subagent output IS the final output.

## Guidelines

- **Data source**: The miner reads raw `*_sessions.json` files for per-session detail. `analytics.json` is only for summary stats (total sessions, provider breakdown, date range).
- **Project filter**: Case-insensitive substring match on `session.project`. When no sessions match, list available projects.
- **Format-specific rules**: Encoded in the prompt templates — do not override them in the dispatch prompt.

## Anti-Patterns

- Reading only `analytics.json` for session detail — it loses per-session data; the miner must read raw `*_sessions.json`
- Processing or formatting data in the main thread — dispatch to `@miner`
- Inventing task descriptions when no data exists — use "unspecified task" with files list
- Dispatching multiple subagents — single `@miner` dispatch per invocation
- Modifying scripts in `do-history-insights/scripts/`
