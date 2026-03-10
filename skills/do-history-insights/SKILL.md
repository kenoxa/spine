---
name: do-history-insights
description: >
  Mine AI agent session history across Claude Code, Codex, and Cursor to produce
  actionable workflow and setup improvement recommendations. Use this skill whenever
  the user asks to analyze sessions, review workflow patterns, compare tool usage,
  find automation candidates, or understand where they waste time across AI coding
  tools. Trigger phrases: "what should I automate", "what patterns keep repeating",
  "analyze my sessions", "what should become a skill", "compare my tools", "where am I
  inefficient", "history insights", "what anti-patterns do you see", "mine my
  session data", "cross-tool comparison", "audit my AI usage", "improve my workflow",
  "improve my setup". Also trigger when the user asks to mine, audit, or retrospect
  on their AI assistant history, even without naming specific tools. This is the only
  skill that can parse actual session history files from disk and produce data-driven
  workflow analysis.
  Do NOT use for single-session review (use do-review), work reporting
  (use do-history-recap), or when the user asks to set up Claude Code
  (use claude-automation-recommender).
argument-hint: "[--days N, default 14] [--project filter]"
---

Periodic cross-tool session analysis. Python scripts extract and compress ~256MB of raw session data into ~100KB of normalized analytics. Subagents analyze patterns and produce recommendations in 7 categories.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context explicitly.

**Subagent dispatch policy**: Each role uses the `@miner` agent type. Every dispatch prompt MUST include:
- The exact output file path (`.scratch/<session>/<prescribed-filename>.md`)
- The constraint: "Write your complete output to that path. You may read any repository file. Do NOT edit, create, or delete files outside `.scratch/<session>/`. Do NOT run build commands, tests, or destructive shell commands."

**Session ID**: generate once at phase entry using `{YYWW}-{slug}-{hash}` (e.g., `2610-insights-weekly-a3f2`). `YYWW` is two-digit year + zero-padded ISO week. `slug` is 3–5 words derived from the initial user prompt (lowercase, hyphen-separated, alphanumeric only). `hash` is a 4-character random hex. Reuse the same session ID across all phases.

### 1. Collect

Run parser scripts via Bash. Generate session ID first.

```bash
PYTHON=$(command -v python3 || command -v python)
if [ -z "$PYTHON" ]; then echo "Error: Python 3.9+ required but not found"; exit 1; fi

SINCE=$(date -v-${DAYS:-14}d +%Y-%m-%d)
SCRATCH=".scratch/<session>"
SCRIPTS="$HOME/.agents/skills/do-history-insights/scripts"
mkdir -p "$SCRATCH"

PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_claude.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_codex.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_cursor.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/aggregate.py" --input "$SCRATCH" --output "$SCRATCH/analytics.json"
```

Verify `analytics.json` exists and has sessions. If `summary.total_sessions == 0`, report "no sessions found" and suggest expanding the time window.

Read `analytics.json`. Produce a brief collection summary (sessions found per provider, date range, top projects).

### 2. Analyze

Dispatch 3 source-expert subagents in parallel. Each receives their provider's sections from `analytics.json`.

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `claude-expert` | `@miner` | Claude sections of analytics + per_project Claude data + friction_patterns | `.scratch/<session>/insights-analyze-claude-expert.md` |
| `codex-expert` | `@miner` | Codex sections of analytics + per_project Codex data | `.scratch/<session>/insights-analyze-codex-expert.md` |
| `cursor-expert` | `@miner` | Cursor sections of analytics + per_project Cursor data + cross_tool | `.scratch/<session>/insights-analyze-cursor-expert.md` |

Use the prompt templates from `~/.agents/skills/do-history-insights/references/analysis-prompts.md` — include the relevant analytics data inline. Skip providers with 0 sessions.

### 3. Synthesize

Dispatch 1 synthesizer subagent with all source-expert outputs.

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `synthesizer` | `@miner` | All insights-analyze-*.md files + cross_tool + sample_prompts sections | `.scratch/<session>/insights-synthesize-synthesizer.md` |

The synthesizer produces recommendations in 7 categories:

1. **Skills** — Repeated multi-step workflows where the sequence is stable but inputs vary. Threshold: 3+ occurrences across sessions.
2. **Hooks** — Automatic actions on tool events. Signal: manual post-edit formatting/linting runs, repeated protective checks before edits, consistent post-save validation steps. If a user runs `prettier` or `eslint --fix` after every edit, that's a hook. If they manually avoid `.env` files, that's a PreToolUse block hook.
3. **MCP Servers** — External service integrations. Signal: repeated shell commands for the same CLI tool or API (`gh`, `psql`, `curl` to the same endpoint, `docker` commands). If sessions show 3+ shell invocations of the same external tool, recommend the corresponding MCP server.
4. **Plugins** — Capabilities requiring external tooling beyond native agent tools. Signal: repeated shell commands for the same external tool.
5. **Agents** — Self-contained, parallelizable tasks that don't need interactive feedback. Signal: independent sub-tasks within larger workflows.
6. **CLAUDE.md / AGENTS.md rules** — Persistent preferences, conventions, corrections repeated across sessions. Distinguish project-level from global rules.
7. **Anti-patterns** — Behaviors that waste time: high tool-call-to-change ratio, repeated nudges, same error class across sessions.

Each recommendation must include: title, type, priority (high/medium/low), evidence (which sessions, how often), concrete action (what to create/write), example (what the skill/rule would look like).

### 4. Present

Main thread reads synthesizer output.

**Terminal summary** (always): activity stats table (sessions by provider, avg duration, top projects), then recommendations by category sorted by priority. Lead with highest-impact findings. Include only non-empty categories.

**HTML dashboard** (when user requests detailed view): invoke `visual-explainer` skill to generate an interactive page with activity heatmap, tool usage chart, cross-tool comparison table, and recommendation cards.

## Guidelines

- Every recommendation needs evidence: "seen in N sessions" or "e.g., session X on date Y"
- Distinguish project-level patterns (project CLAUDE.md) from global patterns (user CLAUDE.md)
- If a pattern already has a skill but isn't triggering, recommend description improvement — not a new skill
- Cross-tool patterns (same workflow in multiple agents) are the highest-value findings
- Threshold for skill/plugin recommendations: 3+ occurrences across sessions
- All recommendations are proposals for user review — never auto-apply
