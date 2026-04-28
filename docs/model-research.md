---
updated: 2026-04-28
---

# Model Research Reference

Durable reference for model selection decisions. Supersedes in-session research artifacts.

## Executive Summary

**Three-tier stack recommendation:**

| Layer | Claude Code | OpenCode Go | OpenCode Free |
|-------|-------------|-------------|---------------|
| Frontier / Orchestrator | opus | kimi-k2.6 | qwen3.6-plus-free |
| Standard / Worker | sonnet | minimax-m2.7 | minimax-m2.5-free |
| Fast / Fan-out | haiku | deepseek-v4-flash | mimo-v2-pro-free |

**Key principle**: Long-lived orchestrators optimize for drift resistance, not max request volume. High-volume subagents use cheap models.

## Research Findings

### OpenCode Go

**Primary orchestrator**: Kimi K2.6 — best quality/volume balance for long-lived orchestration (ranked 1). 3× promo makes it affordable.

**Fallback orchestrator**: MiniMax M2.7 — good daily driver, decent volume.

**Hard worker / build**: DeepSeek V4 Pro or Kimi — strong reasoning, but verbose/drifty over long loops.

**Cheap fan-out**: DeepSeek V4 Flash, Qwen3.5 Plus, MiniMax M2.5.

**Rare planning escalation**: GLM-5.1 — too request-expensive for daily use.

### Claude Code

**Main thread**: Sonnet — best balance of quality, speed, and Max-plan usage.

**Heavy planning / architecture checkpoint**: Opus — use for hard decisions, not as default.

**Final synthesis / critical review**: Opus — best as "judge" or escalation.

**Cheap explore / summarization**: Haiku — good for quick, bounded tasks.

**Implementation**: Sonnet strong enough; escalate to Opus only if stuck or risk is high.

### Model Selection Rules

1. **Long-lived orchestrator**: use quality-balanced model (Kimi K2.6 / Sonnet)
2. **High-volume subagents**: use cheap models (DeepSeek V4 Flash / Haiku)
3. **Hard implementation**: use strong reasoning model (DeepSeek V4 Pro / GPT-5.3-Codex)
4. **Planning escalation**: use frontier model only when needed (Opus / GLM-5.1)

## Detailed Provider Mappings

### OpenCode Go (resolve_tier from skills/use-envoy/scripts/_common.sh)

| Tier | Primary Model | Fan-out Options |
|------|---------------|-----------------|
| Frontier | kimi-k2.6 | kimi-k2.6, glm-5.1 |
| Standard | minimax-m2.7 | minimax-m2.7, deepseek-v4-pro, qwen3.6-plus |
| Fast | deepseek-v4-flash | deepseek-v4-flash, qwen3.5-plus, minimax-m2.5 |

### Claude Code

| Tier | Model | Effort |
|------|-------|--------|
| Frontier | opus | high |
| Standard | sonnet | medium |
| Fast | haiku | medium |

## Rationale

- **Drift resistance > raw volume**: For long-lived sessions, stability matters more than max requests. Models that stay on task over hundreds of turns outperform verbose high-volume options.
- **Tier backbone architecture**: 3-tier system (Frontier/Standard/Fast) is durable. Per-task recommendations change faster — they belong in documentation, not runtime code.
- **Frontier gates absorb benchmark gaps**: Gate authority lives in agent architecture, not benchmark scores. See `docs/model-tier-assignments.md`.

## Escalation Triggers

### Session (Upgrade Mainthread to Frontier)

- Context exceeds ~50K tokens accumulated
- 5+ simultaneous preconditions with complex interdependencies
- Conflicting/ambiguous subagent outputs

### Implementation (Not the Orchestrator)

- Multi-file architectural refactoring requiring judgment beyond spec
- Escalate implementer tier, not session tier

## Historical Notes

- Research conducted April 2026 based on OpenCode Go usage patterns, API benchmarks, and pricing analysis.
- Kimi K2.6 3× promo was active at time of research — recommendation may shift when promo ends.
- DeepSeek V4 Flash selected for highest request economy in Fast tier.