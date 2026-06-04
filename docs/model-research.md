---
updated: 2026-06-04
---

# Model Research Reference

Durable reference for model selection decisions. Supersedes in-session research artifacts.

## Executive Summary

**Three-tier stack recommendation:**

| Layer | Claude Code | OpenCode Go | OpenCode Free |
|-------|-------------|-------------|---------------|
| Frontier / Orchestrator | opus | kimi-k2.6 (sub-agent only) | qwen3.6-plus-free |
| Standard / Worker | sonnet | mimo-v2.5-pro | minimax-m2.5-free |
| Fast / Daily Driver | haiku | deepseek-v4-flash | mimo-v2-pro-free |

**Key principle**: Pick your session model by task depth and expected context size, not a fixed tier label. DeepSeek V4 Flash handles 70–80% of light OpenCode sessions; V4 Pro provides bounded depth when Flash isn't enough. For long-horizon delegated implementation, DeepSWE points to Codex/GPT-5.5 first, with Claude Opus as judgment-heavy escalation. Frontier OpenCode models are sub-agent only due to tight request volumes.

## DeepSWE Addendum (June 2026)

[DeepSWE](https://deepswe.datacurve.ai/) is now the strongest public benchmark for long-horizon coding agents: original tasks, 91 repositories, 5 languages, behavior verifiers, and one fixed mini-swe-agent harness. Treat it as model-behavior evidence, then validate critical workflow choices against native provider harnesses.

Key implications from the 2026-05-30 live aggregate:

- **Codex/GPT-5.5 becomes the long-horizon implementation quality default.** GPT-5.5 xhigh reaches 70.0% pass@1; GPT-5.5 medium still reaches 48.0% with much lower cost/time.
- **Claude remains strong but no longer owns "maximum coding quality."** Opus 4.8 max reaches 58.2%; Opus 4.7 max reaches 54.2%; Sonnet 4.6 high reaches 31.8%. Use Opus for planning, review, and high-risk implementation, with explicit mirrored-requirement checks.
- **OpenCode Go coding claims need narrower wording.** Kimi K2.6 is the best Go-roster result at 23.9%; MiMo-V2.5-Pro reaches 19.5%; GLM-5.1 reaches 17.5%; DeepSeek V4 Pro reaches 7.5%; Qwen3.6 Plus reaches 2.7%; MiniMax M2.7 reaches 0.2%. Keep Go models for cost, diversity, and bounded work unless local native-harness evidence says otherwise.
- **Older SWE-Bench/BFCL/LCB wins are upper bounds for agentic implementation.** They still inform role fit, context, and tool-use niches, but they should not be the load-bearing evidence for autonomous multi-file coding.

## Research Findings

### OpenCode Go

**Daily driver (session model)**: DeepSeek V4 Flash — 31,650 req/5h (effectively unlimited), 2.3× faster than Pro. Use for scouting, simple edits, summarization, and cheap orchestration. The old 1.6pp SWE-Bench gap should not be used as evidence for long-horizon implementation quality.

**Depth model (session)**: DeepSeek V4 Pro — strong older coding benchmarks in Standard tier (80.6% SWE-bench Verified, 67.9% Terminal-Bench 2.0, 93.5% LiveCodeBench), 3,450 req/5h. DeepSWE 7.5% narrows this to bounded/local work. Effective context ~200K — compact around this despite 1M claim.

**Agentic tool-calling (session)**: MiniMax M2.5 — #1 BFCL multi-turn tool calling (76.8%, beats Opus by 13.5pt). Only 197K context — use when codebase fits and the task is tool-call-heavy. MiniMax M2.7's 0.2% DeepSWE result makes SWE-Bench-only confidence weak for delegated implementation.

**Frontend/visual (session)**: Qwen3.6 Plus — niche leader: 91% 3D ELO, 88% Game Dev in Design Arena. Fixes Qwen3.5's agentic bugs. 3,300 req/5h.

**Long agentic sessions (session)**: MiMo-V2.5-Pro — 40–60% fewer tokens per trajectory, harness awareness for self-managed context, 19.5% DeepSWE. 1,290 req/5h — use for focused long sessions.

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
3. **Hard implementation**: use strong long-horizon implementation model (GPT-5.5 / Opus; OpenCode Kimi or MiMo only when cost/diversity matters)
4. **Planning escalation**: use frontier model only when needed (Opus / GLM-5.1)

## Detailed Provider Mappings

### OpenCode Go (resolve_tier from skills/use-envoy/scripts/_common.sh)

| Tier | Primary Model | Fan-out Options | Session Viable? |
|------|---------------|-----------------|-----------------|
| Frontier | kimi-k2.6 | kimi-k2.6, deepseek-v4-pro, glm-5.1 | No — 880–1,150 req/5h too tight |
| Standard | mimo-v2.5-pro | mimo-v2.5-pro, kimi-k2.6, deepseek-v4-pro, qwen3.6-plus | Yes — 1,150–3,450 req/5h |
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
- **Frontier gates reduce benchmark gaps**: Gate authority lives in agent architecture, but weak implementation workers still create rework. See `docs/model-tier-assignments.md`.

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
- **DeepSeek V4 Flash promoted to light-work daily driver** (May 2026) — real-world experience and A/B tests showed enough quality for scouting, simple edits, and orchestration. DeepSWE later narrowed this recommendation away from long-horizon implementation. 31,650 req/5h headroom makes it the clear OpenCode light-work default. See model-selection.md for the full session model table.
- DeepSeek V4 Pro effective context corrected to ~200K (May 2026) — independent NIAH-2 multi-needle testing shows 8-needle retrieval drops from 82% at 256K to 41% at 1M. CSA+HCA attention compression introduces multi-fact distortion at extreme range.
- MiniMax M2.5 recognized as agentic dark horse (May 2026) — 80.2% SWE-bench (matches Opus 4.6), #1 BFCL multi-turn (76.8%). Niche: agentic tool-calling when codebase fits in 197K.
- Qwen3.5 Plus flagged as not recommended for agentic use (May 2026) — critical tool-calling bugs discovered. Qwen3.6 Plus fixes these.
- MiMo-V2.5-Pro promoted to OpenCode Go Standard primary — strongest Standard DeepSWE result in the Go roster, token-efficient agentic coding, and 1,290 req/5h limits it to focused work rather than all-day driving.
- DeepSeek V4 Flash selected for highest request economy in Fast tier (31,650 req/5h).
- DeepSWE incorporated (June 2026) — promoted Codex/GPT-5.5 to long-horizon implementation quality default; narrowed OpenCode Go recommendations to cost/diversity/bounded-work unless local native-harness evidence says otherwise.
