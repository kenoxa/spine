---
updated: 2026-06-04
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
| Frontier | opus | kimi-k2.6 | qwen3.6-plus-free | gpt-5.5 | composer-2.5 |
| Standard | sonnet | mimo-v2.5-pro | minimax-m2.5-free | gpt-5.5 | composer-2.5 |
| Fast | haiku | deepseek-v4-flash | mimo-v2-pro-free | gpt-5.4-mini | auto |

**Rationale**: Provider mappings are based on role fit, effective context, request volume, and benchmark evidence. DeepSWE is now the primary public signal for long-horizon delegated coding, but it does not directly measure Spine's native provider harnesses. See model-selection.md for the full decision table.

**Research source**: Detailed analysis in `docs/model-research.md`.

**Synthesizer (Frontier) vs implementer (Standard).** Not a tier mismatch: the synthesizer merges multiple subagent outputs behind the thin-orchestrator firewall (merge authority, quality-sensitive consolidation). The implementer executes scoped partition edits from a plan — not a merge gate — and is pinned to Standard so a Fast mainthread cannot drag writes to Fast-tier quality. See `docs/architecture.md` (thin orchestrator + tier system).

## Session Model (Main-Thread)

**Pick your session model by task depth and expected context.** For long-horizon delegated implementation, Codex/GPT-5.5 is the quality default; use high or xhigh effort when failure cost is high. Claude Sonnet remains a good planning/review mainthread, with Opus for judgment-heavy escalation. OpenCode Go defaults optimize cost and diversity: DeepSeek V4 Flash is the light-work daily driver, MiMo is the Standard worker, and Kimi remains the Frontier gate/diversity choice. See [model-selection.md#opencode-go-session-model](model-selection.md#opencode-go-session-model).

Frontier subagents (consultant, inspector, verifier, synthesizer) handle gate decisions regardless of session model — strong gates, efficient workers. Frontier gates reduce worker-model risk; they do not erase a large implementation-quality gap. If implementation is the bottleneck, route the work to a stronger implementation model or split the patch smaller.

For Claude Code: Standard (Sonnet) for most sessions. Frontier (Opus) for heavy planning/architecture checkpoints and final critical review. Fast (Haiku) for cheap explore/summarization.

## Narrative Durability

Benchmark-anchored justifications ("Standard is safe because the gap is small") invalidate on every model release. Architecture-anchored justifications do not.

**Durable anchor**: "Frontier gates reduce worker-model risk, but implementation still needs a capable worker." Gate authority lives in the agent architecture — Frontier subagents handle judgment — yet a weak implementer still creates rework and missed requirements on long-horizon tasks.

**Anti-pattern**: citing a specific benchmark delta as the load-bearing reason for a tier default. When the delta widens, the recommendation looks wrong even when the architecture hasn't changed.

## Escalation: Session (Upgrade Mainthread to Frontier)

Use when the **orchestrator conversation** is the bottleneck:

- Session context exceeds ~50K tokens accumulated across subagent interactions
- Phase-gating requires 5+ simultaneous preconditions with complex interdependencies
- Conflicting/ambiguous subagent outputs requiring nuanced synthesis beyond structured routing

## Escalation: Implementer Workload (Not the Orchestrator)

Use when **implementation** is the bottleneck but you might keep a cheaper session for planning overhead:

- Multi-file architectural refactoring where the design artifact cannot fully specify cross-cutting concerns — escalate **implementation** (e.g. `@implementer` tier or partition scope), not "run everything on Opus" by default
- Long-horizon delegated coding where DeepSWE-style failure modes matter — prefer Codex/GPT-5.5, use Opus for high-risk implementation, or split the patch until Standard is a safe worker

If the mainthread cannot hold the task state or routing breaks down, upgrade the **session**; implementer-only escalation does not fix orchestration limits.

## Provider Notes

- **OpenCode Go**: See [model-selection.md#opencode-go-session-model](model-selection.md#opencode-go-session-model) for the full session model decision table. Daily driver: DeepSeek V4 Flash (31,650 req/5h) for light work. Standard maps to MiMo-V2.5-Pro. MiniMax M3 is now the stronger secondary Standard fanout model after DeepSWE; DeepSeek V4 Pro is no longer part of the default Standard fanout.
- **OpenCode Free**: Lower quota, recommended for lighter orchestrators. See mapping table above.
- **Claude Code**: Standard (Sonnet) for most sessions. Frontier (Opus) for heavy planning/architecture checkpoints and final critical review. Fast (Haiku) for cheap explore/summarization.
- **Cursor**: `auto` and `composer-2.5` draw from the same included pool — no cost advantage between them. Both are cheaper than API-pool models (Claude/GPT selections).
- **Codex**: Frontier uses `gpt-5.5` (envoy effort `high`; Frontier subagent TOML uses `xhigh`); Standard uses `gpt-5.5` (`medium` effort). DeepSWE makes Codex the long-horizon implementation quality default. GPT-5.4-mini (Fast) remains rejected for main-thread — 33.6% MRCR v2 long-context score is unacceptable for orchestrators accumulating multi-phase output.
