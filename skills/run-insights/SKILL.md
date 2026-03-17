---
name: run-insights
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
  (run-recap), Claude Code setup (claude-automation-recommender).
argument-hint: "[--days N, default 14] [--project filter]"
---

Cross-tool session analysis. Python scripts compress ~256MB raw data into ~100KB normalized analytics. Subagents analyze patterns, produce recommendations in 7 categories.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context.

**Session ID**: Generate per SPINE.md Sessions convention. Reuse across all phases.

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Collect | `@miner` | [collect-miner.md](references/collect-miner.md) |
| Analyze | `@miner` (source-expert) | [analyze-source-expert.md](references/analyze-source-expert.md) |
| Synthesize | `@miner` (synthesizer) | [synthesize-miner.md](references/synthesize-miner.md) |
| Present | `@visualizer` | [present-visualizer.md](references/present-visualizer.md) |

### 1. Collect

Dispatch `@miner` (`collector`) → [collect-miner.md](references/collect-miner.md).

Output: `.scratch/<session>/insights-collect-collector.md`

### 2. Analyze

Dispatch 3 `@miner` in parallel → [analyze-source-expert.md](references/analyze-source-expert.md). Skip providers with 0 sessions.

| Role | Input | Output |
|------|-------|--------|
| `claude-expert` | Claude sections + per_project Claude data + friction_patterns + subagent_patterns + operational_health | `.scratch/<session>/insights-analyze-claude-expert.md` |
| `codex-expert` | Codex sections + per_project Codex data | `.scratch/<session>/insights-analyze-codex-expert.md` |
| `cursor-expert` | Cursor sections + per_project Cursor data + cross_tool | `.scratch/<session>/insights-analyze-cursor-expert.md` |

Include relevant analytics data inline in each dispatch prompt.

### 3. Synthesize

Dispatch 1 `@miner` → [synthesize-miner.md](references/synthesize-miner.md).

Input: all `insights-analyze-*.md` files + `cross_tool` + `sample_prompts` sections from `analytics.json`.

7 recommendation categories: Skills, Hooks, MCP Servers, Plugins, Agents, CLAUDE.md rules, Anti-patterns.

Output: `.scratch/<session>/insights-synthesize-synthesizer.md`

### 4. Present

**Terminal summary** (always): read synthesizer output. Activity stats table (sessions by provider, avg duration, top projects), then recommendations by category sorted by priority. Lead with highest-impact. Include only non-empty categories.

**HTML dashboard**: Guard: `.scratch/<session>/insights-synthesize-synthesizer.md` exists and non-empty. Inform user before dispatch.

Dispatch `@visualizer` → [present-visualizer.md](references/present-visualizer.md).

Inputs: `.scratch/<session>/insights-synthesize-synthesizer.md`, `.scratch/<session>/analytics.json`

Output: `.scratch/<session>/history-insights.html`

## Anti-Patterns

- Recommendations without session evidence ("seen in N sessions" or "e.g., session X on date Y")
- Conflating project-level and global patterns
- Creating new skill when existing skill just needs better description triggers
- Ignoring cross-tool patterns (highest-value findings)
- Auto-applying recommendations instead of presenting as proposals
