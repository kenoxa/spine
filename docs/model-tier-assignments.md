---
updated: 2026-05-03
---

# Agent Tier Assignments

Durable reference for AI sessions. Full detail in `docs/model-selection.md`.

## Current Assignments

| Agent | Tier | Rationale |
|-------|------|-----------|
| consultant, debater, inspector, synthesizer, verifier | Frontier | Gate authority — quality of judgment and merge quality must exceed routine implementation |
| analyst, curator, envoy, implementer, navigator, researcher, visualizer | Standard | Advisory, research, cross-provider dispatch, and implementation with a Standard floor |
| miner, scout | Fast | Retrieval — speed over depth |

Source: `docs/model-selection.md` agent table + agent frontmatter.

## Provider Model Mapping

| Tier | Claude Code | OpenCode Go | OpenCode Free | Codex | Cursor |
|------|-------------|-------------|---------------|-------|--------|
| Frontier | opus | kimi-k2.6 | qwen3.6-plus-free | gpt-5.5 | composer-2 |
| Standard | sonnet | deepseek-v4-pro | minimax-m2.5-free | gpt-5.4 | composer-2 |
| Fast | haiku | deepseek-v4-flash | mimo-v2-pro-free | gpt-5.4-mini | auto |

**Rationale**: OpenCode mappings based on quality, effective context, and request volume. See model-selection.md for the full OpenCode Go session model table with per-model reasoning.

**Research source**: Detailed analysis in `docs/model-research.md`.

**Synthesizer (Frontier) vs implementer (Standard).** Not a tier mismatch: the synthesizer merges multiple subagent outputs behind the thin-orchestrator firewall (merge authority, quality-sensitive consolidation). The implementer executes scoped partition edits from a plan — not a merge gate — and is pinned to Standard so a Fast mainthread cannot drag writes to Fast-tier quality. See `docs/architecture.md` (thin orchestrator + tier system).

## Session Model (Main-Thread)

**Pick your session model by task depth and expected context.** For OpenCode Go, DeepSeek V4 Flash is the recommended daily driver (31,650 req/5h, 1.6pp gap to Pro). DeepSeek V4 Pro provides depth when Flash isn't enough (3,450 req/5h). See [model-selection.md#opencode-go-session-model](model-selection.md#opencode-go-session-model) for the full decision table with request volume, effective context, and why.

Frontier subagents (consultant, inspector, verifier, synthesizer) handle gate decisions regardless of session model — strong gates, efficient workers. Frontier gates absorb any benchmark gap by design; even Flash is sufficient for session orchestration because Frontier sub-agents handle all gate authority.

For Claude Code: Standard (Sonnet) for most sessions. Frontier (Opus) for heavy planning/architecture checkpoints and final critical review. Fast (Haiku) for cheap explore/summarization.

## Narrative Durability

Benchmark-anchored justifications ("Standard is safe because the gap is small") invalidate on every model release. Architecture-anchored justifications do not.

**Durable anchor**: "Frontier gates absorb any benchmark gap by design." Gate authority lives in the agent architecture — Frontier subagents handle judgment; the gap's magnitude is irrelevant. Applies to any performance-safety claim in docs or session artifacts.

**Anti-pattern**: citing a specific benchmark delta as the load-bearing reason for a tier default. When the delta widens, the recommendation looks wrong even when the architecture hasn't changed.

## Escalation: Session (Upgrade Mainthread to Frontier)

Use when the **orchestrator conversation** is the bottleneck:

- Session context exceeds ~50K tokens accumulated across subagent interactions
- Phase-gating requires 5+ simultaneous preconditions with complex interdependencies
- Conflicting/ambiguous subagent outputs requiring nuanced synthesis beyond structured routing

## Escalation: Implementer Workload (Not the Orchestrator)

Use when **implementation** is the bottleneck but you might keep a cheaper session for planning overhead:

- Multi-file architectural refactoring where the design artifact cannot fully specify cross-cutting concerns — escalate **implementation** (e.g. `@implementer` tier or partition scope), not "run everything on Opus" by default

If the mainthread cannot hold the task state or routing breaks down, upgrade the **session**; implementer-only escalation does not fix orchestration limits.

## Provider Notes

- **OpenCode Go**: See [model-selection.md#opencode-go-session-model](model-selection.md#opencode-go-session-model) for the full session model decision table. Daily driver: DeepSeek V4 Flash (31,650 req/5h). Depth: DeepSeek V4 Pro (3,450 req/5h). Frontier models (Kimi K2.6, GLM-5.1) are sub-agent only — 880–1,150 req/5h too tight for session use. Standard fanout includes MiMo-V2.5-Pro for token-efficient agentic dispatch.
- **OpenCode Free**: Lower quota, recommended for lighter orchestrators. See mapping table above.
- **Claude Code**: Standard (Sonnet) for most sessions. Frontier (Opus) for heavy planning/architecture checkpoints and final critical review. Fast (Haiku) for cheap explore/summarization.
- **Cursor**: `auto` and `composer-2` draw from the same included pool — no cost advantage between them. Both are cheaper than API-pool models (Claude/GPT selections).
- **Codex**: Frontier uses `gpt-5.5` (high effort); Standard uses `gpt-5.4` (medium effort). GPT-5.4-mini (Fast) rejected for main-thread — 33.6% MRCR v2 long-context score is unacceptable for orchestrators accumulating multi-phase output.
