---
updated: 2026-05-03
---

# Model Research Reference

Durable reference for model selection decisions. Supersedes in-session research artifacts.

## Executive Summary

**Three-tier stack recommendation:**

| Layer | Claude Code | OpenCode Go | OpenCode Free |
|-------|-------------|-------------|---------------|
| Frontier / Orchestrator | opus | kimi-k2.6 (sub-agent only) | qwen3.6-plus-free |
| Standard / Worker | sonnet | deepseek-v4-pro | minimax-m2.5-free |
| Fast / Daily Driver | haiku | deepseek-v4-flash | mimo-v2-pro-free |

**Key principle**: Pick your session model by task depth and expected context size, not a fixed tier label. DeepSeek V4 Flash handles 70–80% of sessions; V4 Pro provides depth when Flash isn't enough. Frontier models are sub-agent only due to tight request volumes.

## Research Findings

### OpenCode Go

**Daily driver (session model)**: DeepSeek V4 Flash — 31,650 req/5h (effectively unlimited), 2.3× faster than Pro, 1.6pp SWE-bench gap to Pro is invisible at IDE-task scale. Real-world A/B test: Flash matches/exceeds Claude on 76% of tasks.

**Depth model (session)**: DeepSeek V4 Pro — strongest coding benchmarks in Standard tier (80.6% SWE-bench Verified, 67.9% Terminal-Bench 2.0, 93.5% LiveCodeBench), 3,450 req/5h. Reach for this when Flash isn't enough. Effective context ~200K — compact around this despite 1M claim.

**Agentic tool-calling (session)**: MiniMax M2.5 — 80.2% SWE-bench (matches Opus 4.6), #1 BFCL multi-turn tool calling (76.8%, beats Opus by 13.5pt). Only 197K context — use when codebase fits. 6,300 req/5h.

**Frontend/visual (session)**: Qwen3.6 Plus — niche leader: 91% 3D ELO, 88% Game Dev in Design Arena. Fixes Qwen3.5's agentic bugs. 3,300 req/5h.

**Long agentic sessions (session)**: MiMo-V2.5-Pro — 40–60% fewer tokens per trajectory, harness awareness for self-managed context. 1,290 req/5h — use for focused long sessions.

**Frontier sub-agents (not session)**: Kimi K2.6 (1,150 req/5h) and GLM-5.1 (880 req/5h) — tight volumes make them sub-agent only. Reserved for gate authority roles (consultant, inspector, verifier, synthesizer).

**Not recommended**: Qwen3.5 Plus — critical bugs: tool-calling breaks after 1–2 calls, reasoning suppressed when tools present. Despite 10,200 req/5h, unreliable for agentic use.

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

| Tier | Primary Model | Fan-out Options | Session Viable? |
|------|---------------|-----------------|-----------------|
| Frontier | kimi-k2.6 | kimi-k2.6, deepseek-v4-pro, glm-5.1 | No — 880–1,150 req/5h too tight |
| Standard | deepseek-v4-pro | minimax-m2.7, deepseek-v4-pro, qwen3.6-plus, mimo-v2.5-pro | Yes — 1,290–3,450 req/5h |
| Fast | deepseek-v4-flash | deepseek-v4-flash, qwen3.5-plus, minimax-m2.5 | Yes — 6,300–31,650 req/5h |

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

- Research conducted April–May 2026 based on OpenCode Go usage patterns, API benchmarks, and pricing analysis.
- Kimi K2.6 3× promo ended — limits dropped to 1,150 req/5h. No longer viable for mainthread; reserved for Frontier sub-agents.
- **DeepSeek V4 Flash promoted to daily driver** (May 2026) — real-world experience and A/B tests showed the 1.6pp SWE-bench gap to Pro is invisible at IDE-task scale. 31,650 req/5h headroom makes it the clear default. See model-selection.md for the full session model table.
- DeepSeek V4 Pro effective context corrected to ~200K (May 2026) — independent NIAH-2 multi-needle testing shows 8-needle retrieval drops from 82% at 256K to 41% at 1M. CSA+HCA attention compression introduces multi-fact distortion at extreme range.
- MiniMax M2.5 recognized as agentic dark horse (May 2026) — 80.2% SWE-bench (matches Opus 4.6), #1 BFCL multi-turn (76.8%). Niche: agentic tool-calling when codebase fits in 197K.
- Qwen3.5 Plus flagged as not recommended for agentic use (May 2026) — critical tool-calling bugs discovered. Qwen3.6 Plus fixes these.
- MiMo-V2.5-Pro added to Standard fanout — strong agentic coding (57.2% SWE-bench Pro), 40–60% fewer tokens per trajectory, harness awareness. 1,290 req/5h limits to focused sessions.
- DeepSeek V4 Flash selected for highest request economy in Fast tier (31,650 req/5h).