---
name: log-history-insights
description: >
  Mine AI agent session history across Claude Code, Codex, and Cursor for
  workflow/setup improvement recommendations.
  Use when: "what should I automate", "what patterns keep repeating",
  "analyze my sessions", "what should become a skill", "compare my tools",
  "where am I inefficient", "history insights", "what anti-patterns do you see",
  "mine my session data", "cross-tool comparison", "audit my AI usage",
  "improve my workflow", "improve my setup", "extract skills from history",
  mine/audit/retrospect requests on AI assistant history. Only skill that
  parses session history files.
  Do NOT use for single-session review (run-review), work reporting
  (log-history-recap), Claude Code setup (claude-automation-recommender).
argument-hint: "[--days N, default 14] [--project filter]"
---

Every subagent prompt MUST be self-contained — include all prior-phase context.

Cross-tool session analysis. Python scripts compress ~256MB raw data into ~100KB normalized analytics. Subagents analyze patterns, produce recommendations in 7 categories.

## Phases

**Session ID**: Generate per SPINE.md Sessions convention. Reuse across all phases.

### 1. Collect

Run parser scripts via Bash. Generate session ID first.

```bash
PYTHON=$(command -v python3 || command -v python)
if [ -z "$PYTHON" ]; then echo "Error: Python 3.9+ required but not found"; exit 1; fi
SINCE=$(date -v-${DAYS:-14}d +%Y-%m-%d)
SCRATCH=".scratch/<session>"
SCRIPTS="$HOME/.agents/skills/log-history-insights/scripts"
mkdir -p "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_claude.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_codex.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/parse_cursor.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS" "$PYTHON" "$SCRIPTS/aggregate.py" --input "$SCRATCH" --output "$SCRATCH/analytics.json"
```

Verify `analytics.json` exists with sessions. If `summary.total_sessions == 0`, report "no sessions found", suggest expanding time window.

Read `analytics.json`. Produce brief collection summary (sessions per provider, date range, top projects).

### 2. Analyze

Dispatch 3 source-expert subagents in parallel. Each receives their provider's sections from `analytics.json`.

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `claude-expert` | `@miner` | Claude sections of analytics + per_project Claude data + friction_patterns | `.scratch/<session>/insights-analyze-claude-expert.md` |
| `codex-expert` | `@miner` | Codex sections of analytics + per_project Codex data | `.scratch/<session>/insights-analyze-codex-expert.md` |
| `cursor-expert` | `@miner` | Cursor sections of analytics + per_project Cursor data + cross_tool | `.scratch/<session>/insights-analyze-cursor-expert.md` |

Use prompt templates from `~/.agents/skills/log-history-insights/references/analysis-prompts.md` — include relevant analytics data inline. Skip providers with 0 sessions.

### 3. Synthesize

Dispatch 1 synthesizer subagent with all source-expert outputs.

| Role | Agent type | Input | Output |
|------|-----------|-------|--------|
| `synthesizer` | `@miner` | All insights-analyze-*.md files + cross_tool + sample_prompts sections | `.scratch/<session>/insights-synthesize-synthesizer.md` |

Recommendations in 7 categories:

1. **Skills** — Repeated stable-sequence workflows with varying inputs. Threshold: 3+ occurrences.
   - When candidate identified, produce draft SKILL.md per `use-skill-craft` conventions.
   - Quality gate: reusable (not one-off), non-trivial (required discovery), specific triggers (not vague).
   - Present drafts as proposals — never auto-save to `~/.claude/skills/`.
2. **Hooks** — Auto-actions on tool events (post-edit formatting, pre-edit guards, post-save validation).
3. **MCP Servers** — External service integrations via repeated CLI/API calls (`gh`, `psql`, `curl`, `docker`). 3+ shell invocations of same tool triggers recommendation.
4. **Plugins** — Capabilities requiring external tooling beyond native agent tools.
5. **Agents** — Self-contained parallelizable tasks not needing interactive feedback.
6. **CLAUDE.md / AGENTS.md rules** — Persistent preferences, conventions, corrections repeated across sessions. Distinguish project-level from global.
7. **Anti-patterns** — Time wasters: high tool-call-to-change ratio, repeated nudges, recurring error classes.

Each recommendation must include: title, type, priority (high/medium/low), evidence (sessions + frequency), concrete action, example.

### 4. Present

Main thread reads synthesizer output.

**Terminal summary** (always): activity stats table (sessions by provider, avg duration, top projects), then recommendations by category sorted by priority. Lead with highest-impact. Include only non-empty categories.

**HTML dashboard** (on request): invoke `visual-explainer` skill for interactive page with activity heatmap, tool usage chart, cross-tool comparison table, recommendation cards.

## Anti-Patterns

- Recommendations without session evidence ("seen in N sessions" or "e.g., session X on date Y")
- Conflating project-level and global patterns
- Creating new skill when existing skill just needs better description triggers
- Ignoring cross-tool patterns (highest-value findings)
- Auto-applying recommendations instead of presenting as proposals
