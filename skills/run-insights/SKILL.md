---
name: run-insights
description: >-
  Mine session history. Use when: 'analyze my sessions', 'improve my workflow', 'automate tasks'.
argument-hint: "[--days N, default 14] [--project filter]"
---

Cross-tool session analysis. Python scripts compress ~256MB raw data into ~100KB normalized analytics. Subagents analyze patterns, produce recommendations in 7 categories.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context.

**Reference paths** (backticked): dispatch to subagent — do NOT Read into mainthread.

**Session ID**: Generate per SPINE.md Sessions convention. Reuse across all phases.

**Phase Trace**: Log row at collect, analyze, synthesize, present. Include dispatch count.

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Collect | `@miner` | `references/collect-miner.md` |
| Analyze | `@miner` (source-expert) | `references/analyze-source-expert.md` |
| Synthesize | `@synthesizer` | `references/synthesize-synthesizer.md` |
| Present | `@visualizer` | `references/present-visualizer.md` |

### 1. Collect

Dispatch `@miner` (`collector`) → `references/collect-miner.md`.

Output: `.scratch/<session>/insights-collect-collector.md`

### 2. Analyze

For each provider in `summary.provider_breakdown` with `sessions >= 1`, dispatch one `@miner` (source-expert) in parallel → `references/analyze-source-expert.md`. Cap: 6 per batch (per SPINE.md).

**Null-telemetry short-circuit:** if all of a provider's sessions have empty `tool_calls` AND empty `skills_used`, do not dispatch. Write a 1-paragraph "no usable telemetry — N sessions detected, no per-call attribution available" note to `.scratch/<session>/insights-analyze-{provider}-expert.md` and proceed.

| Role | Input | Output |
|------|-------|--------|
| `{provider}-expert` | provider-specific sections + per_project entries where `providers` includes `{provider}` + cross-cutting sections relevant to that provider (friction, subagent, operational_health, cross_tool — apply per focus block in ref) | `.scratch/<session>/insights-analyze-{provider}-expert.md` |

Include relevant analytics data inline in each dispatch prompt.

### 3. Synthesize

Dispatch 1 `@synthesizer` → `references/synthesize-synthesizer.md`.

Input: all `insights-analyze-*.md` files + `cross_tool` + `sample_prompts` sections from `analytics.json`.

7 recommendation categories: Skills, Hooks, MCP Servers, Plugins, Agents, CLAUDE.md rules, Anti-patterns.

Output: `.scratch/<session>/insights-synthesize-synthesizer.md`

### 4. Present

**Terminal summary** (always): read synthesizer output. Activity stats table (sessions by provider, avg duration, top projects), then recommendations by category sorted by priority. Lead with highest-impact. Include only non-empty categories.

**HTML dashboard**: Guard: `.scratch/<session>/insights-synthesize-synthesizer.md` exists and non-empty. Inform user before dispatch.

Dispatch `@visualizer` → `references/present-visualizer.md`.

Inputs: `.scratch/<session>/insights-synthesize-synthesizer.md`, `.scratch/<session>/analytics.json`

Output: `.scratch/<session>/history-insights.html`

## Anti-Patterns

- Recommendations without session evidence ("seen in N sessions" or "e.g., session X on date Y")
- Conflating project-level and global patterns
- Creating new skill when existing skill just needs better description triggers
- Ignoring cross-tool patterns (highest-value findings)
- Auto-applying recommendations instead of presenting as proposals
