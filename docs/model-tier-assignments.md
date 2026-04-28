---
updated: 2026-04-28
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
| Frontier | opus | kimi-k2.6 | qwen3.6-plus-free | gpt-5.4 | composer-2 |
| Standard | sonnet | minimax-m2.7 | minimax-m2.5-free | gpt-5.4 | composer-2 |
| Fast | haiku | deepseek-v4-flash | mimo-v2-pro-free | gpt-5.4-mini | auto |

**Rationale**: OpenCode mappings based on best quality/volume balance for long-lived orchestration. Claude Code default is Standard (Sonnet) with Frontier (Opus) for heavy planning/critical review only.

**Research source**: Detailed analysis in `docs/model-research.md`.

**Synthesizer (Frontier) vs implementer (Standard).** Not a tier mismatch: the synthesizer merges multiple subagent outputs behind the thin-orchestrator firewall (merge authority, quality-sensitive consolidation). The implementer executes scoped partition edits from a plan — not a merge gate — and is pinned to Standard so a Fast mainthread cannot drag writes to Fast-tier quality. See `docs/architecture.md` (thin orchestrator + tier system).

## Session Model (Main-Thread)

**Standard is the recommended default.** See provider mapping table above for actual model names per session provider.

Frontier subagents (consultant, inspector, verifier, synthesizer) handle gate decisions regardless of session model — strong gates, efficient workers. Frontier gates absorb any benchmark gap by design; Standard is sufficient for session orchestration (tool use, structured task execution, agent coordination).

Rolling window is cost-weighted: Opus drains the 5h/7-day window ~1.67× faster than Sonnet.

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

- **OpenCode Go**: Recommended tier routing via `skills/use-envoy/scripts/_common.sh`. Frontier (Kimi K2.6) for long-lived orchestration; Standard (MiniMax M2.7) for daily driver; Fast (DeepSeek V4 Flash) for fan-out/explore. Runtime mappings match research findings.
- **OpenCode Free**: Lower quota, recommended for lighter orchestrators. See mapping table above.
- **Claude Code**: Standard (Sonnet) for most sessions. Frontier (Opus) for heavy planning/architecture checkpoints and final critical review. Fast (Haiku) for cheap explore/summarization.
- **Cursor**: `auto` and `composer-2` draw from the same included pool — no cost advantage between them. Both are cheaper than API-pool models (Claude/GPT selections).
- **Codex**: Frontier/Standard both use `gpt-5.4`; differentiated by effort level (high vs medium). GPT-5.4-mini (Fast) rejected for main-thread — 33.6% MRCR v2 long-context score is unacceptable for orchestrators accumulating multi-phase output.
