---
updated: 2026-06-15
---

# Model Research Reference

Durable reference for model selection decisions. Supersedes in-session research artifacts.

## Executive Summary

**Three-tier stack recommendation:**

| Layer | Claude Code | OpenCode Go | OpenCode Free |
|-------|-------------|-------------|---------------|
| Frontier / Orchestrator | opus | kimi-k2.7-code (sub-agent only) | qwen3.6-plus-free |
| Standard / Worker | sonnet | mimo-v2.5-pro | minimax-m2.5-free |
| Fast / Daily Driver | haiku | deepseek-v4-flash | mimo-v2-pro-free |

**Key principle**: Pick your session model by task depth and expected context size, not a fixed tier label. DeepSeek V4 Flash handles 70–80% of light OpenCode sessions; V4 Pro provides bounded depth when Flash isn't enough. For long-horizon delegated implementation, DeepSWE points to Codex/GPT-5.5 first, with Claude Opus as judgment-heavy escalation. Frontier OpenCode models are sub-agent only due to tight request volumes.

## DeepSWE Addendum (June 2026)

[DeepSWE](https://deepswe.datacurve.ai/) is now the strongest public benchmark for long-horizon coding agents: original tasks, 91 repositories, 5 languages, behavior verifiers, and one fixed mini-swe-agent harness. Treat it as model-behavior evidence, then validate critical workflow choices against native provider harnesses.

Key implications from the 2026-05-30 live aggregate:

- **Codex/GPT-5.5 becomes the long-horizon implementation quality default.** GPT-5.5 xhigh reaches 70.0% pass@1; GPT-5.5 medium still reaches 48.0% with much lower cost/time.
- **Claude remains strong but no longer owns "maximum coding quality."** Opus 4.8 max reaches 58.2%; Opus 4.7 max reaches 54.2%; Sonnet 4.6 high reaches 31.8%. Use Opus for planning, review, and high-risk implementation, with explicit mirrored-requirement checks.
- **OpenCode Go coding claims need narrower wording.** Kimi K2.6 is the best *DeepSWE-measured* Go-roster result at 23.9%; MiniMax M3 reaches 20.0%; MiMo-V2.5-Pro reaches 19.5%; GLM-5.1 reaches 17.5%; DeepSeek V4 Pro reaches 7.5%; Qwen3.6 Plus reaches 2.7%; MiniMax M2.7 reaches 0.2%. Keep Go models for cost, diversity, and bounded work unless local native-harness evidence says otherwise. **Kimi K2.7 Code (June 2026) is the operational Frontier pick** — coding-specialized post-train of the same K2 MoE base, vendor coding-benchmark gains over K2.6, more request headroom (1,350 vs 1,150 req/5h), same price — but Moonshot published no DeepSWE/SWE-Bench/Terminal-Bench submission, so it inherits K2.6's evidence by family lineage and needs local validation.
- **Older SWE-Bench/BFCL/LCB wins are upper bounds for agentic implementation.** They still inform role fit, context, and tool-use niches, but they should not be the load-bearing evidence for autonomous multi-file coding.

## Research Findings

### OpenCode Go

**Daily driver (session model)**: DeepSeek V4 Flash — 31,650 req/5h (effectively unlimited), 2.3× faster than Pro. Use for scouting, simple edits, summarization, and cheap orchestration. The old 1.6pp SWE-Bench gap should not be used as evidence for long-horizon implementation quality.

**Depth model (override-only)**: DeepSeek V4 Pro — strong older coding benchmarks (80.6% SWE-bench Verified, 67.9% Terminal-Bench 2.0, 93.5% LiveCodeBench), 3,450 req/5h. DeepSWE 7.5–8% is below the coding floor of every tier, so it was removed from all default fanouts (2026-06-15) — available via env override for bounded/local diversity only. Effective context ~200K — compact around this despite 1M claim.

**Agentic tool-calling**: MiniMax M2.5 was #1 BFCL multi-turn (76.8%, beat Opus by 13.5pt) but **was dropped from the Go roster (June 2026)**. MiniMax M2.7 is the remaining MiniMax model and the Fast-fanout MiniMax voice — its BFCL is not separately published here and its DeepSWE is 0.2%, so validate tool-calling on your repo before relying on it for delegated work.

**Frontend/visual (session)**: Qwen3.6 Plus — niche leader: 91% 3D ELO, 88% Game Dev in Design Arena. Fixes Qwen3.5's agentic bugs. 3,300 req/5h.

**Long agentic sessions (session)**: MiMo-V2.5-Pro — 40–60% fewer tokens per trajectory, harness awareness for self-managed context, 19.5% DeepSWE. 3,250 req/5h (up from 1,290) — now daily-driver viable, not just focused sessions.

**Standard diversity candidate**: MiniMax M3 — 20.0% DeepSWE with higher volume than MiMo (3,200 req/5h). Useful as a second Standard fanout voice when you want stronger coding signal than DeepSeek V4 Pro without promoting it to the primary worker.

**Frontier sub-agents (not session)**: Kimi K2.7 Code (1,350 req/5h) and GLM-5.1 (880 req/5h) — tight volumes make them sub-agent only. Reserved for gate authority roles (consultant, inspector, verifier, synthesizer). Kimi K2.7 Code replaced K2.6 as the Frontier primary (June 2026).

**Not recommended**: Qwen3.7 Plus should be routed as a controlled fast-fanout member first, then validated per workflow before assigning primary agentic work.

**Frontier fanout member (sub-agent only)**: Qwen3.7 Max (released 2026-05-20, text-only, closed-weight) — DeepSWE 18%, SWE-Bench Pro 60.6%, Terminal-Bench 2.0 69.7%, SWE-Verified 80.4%, 1M context, slug `opencode-go/qwen3.7-max`. Strong benchmarks and the most efficient model in the Go roster (fastest run, fewest tokens), though pricey on Zen ($2.50/$7.50 per M). Distinct from Qwen3.7 Plus (multimodal, 4,300 req/5h, cheaper, Fast fanout). Added to the Frontier fanout 2026-06-15, replacing DeepSeek V4 Pro — tight volume (950 req/5h) is fine for the rarely-fired Frontier gate council.

**Not on OpenCode Go**: GLM-5.2 (released 2026-06-13, 1M context, two reasoning modes) ships only via Z.ai's own Coding Plan — OpenCode Go still lists `glm-5.1`/`glm-5`. No benchmarks published at launch. Do not add to the OpenCode Go roster until a `opencode-go/glm-5.2` slug exists.

### Claude Code

**Main thread**: Sonnet — best balance of quality, speed, and Max-plan usage.

**Heavy planning / architecture checkpoint**: Opus — use for hard decisions, not as default.

**Final synthesis / critical review**: Opus — best as "judge" or escalation.

**Cheap explore / summarization**: Haiku — good for quick, bounded tasks.

**Implementation**: Sonnet strong enough; escalate to Opus only if stuck or risk is high.

### Model Selection Rules

1. **Long-lived orchestrator**: use quality-balanced model (Kimi K2.7 Code / Sonnet)
2. **High-volume subagents**: use cheap models (DeepSeek V4 Flash / Haiku)
3. **Hard implementation**: use strong long-horizon implementation model (GPT-5.5 / Opus; OpenCode Kimi or MiMo only when cost/diversity matters)
4. **Planning escalation**: use frontier model only when needed (Opus / GLM-5.1)

## Detailed Provider Mappings

### OpenCode Go (resolve_tier from skills/use-envoy/scripts/_common.sh)

| Tier | Primary Model | Fan-out Options | Session Viable? |
|------|---------------|-----------------|-----------------|
| Frontier | kimi-k2.7-code | kimi-k2.7-code, qwen3.7-max, glm-5.1 | No — 880–1,350 req/5h too tight |
| Standard | mimo-v2.5-pro | mimo-v2.5-pro, minimax-m3, kimi-k2.7-code | Yes — 1,350–3,250 req/5h |
| Fast | deepseek-v4-flash | deepseek-v4-flash, qwen3.7-plus, minimax-m2.7 | Yes — 3,400–31,650 req/5h |

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
- MiniMax M2.5 recognized as agentic dark horse (May 2026) — 80.2% SWE-bench (matches Opus 4.6), #1 BFCL multi-turn (76.8%). Niche: agentic tool-calling when codebase fits in 197K. **Removed from the Go roster (June 2026)**; MiniMax M2.7 is the remaining MiniMax option (Fast fanout).
- Qwen3.5 Plus was previously flagged for agentic instability in earlier tests; the current Go roster uses Qwen3.7 Plus in fast fanout.
- MiMo-V2.5-Pro remains the OpenCode Go Standard primary — strongest token-efficiency tradeoff among the better DeepSWE Standard candidates, even though MiniMax M3 scores slightly higher.
- MiniMax M3 added to Standard fanout (June 2026) — 20.0% DeepSWE makes it a better coding-signal diversity member than DeepSeek V4 Pro or Qwen3.6 Plus.
- DeepSeek V4 Flash selected for highest request economy in Fast tier (31,650 req/5h).
- DeepSWE incorporated (June 2026) — promoted Codex/GPT-5.5 to long-horizon implementation quality default; narrowed OpenCode Go recommendations to cost/diversity/bounded-work unless local native-harness evidence says otherwise.
- Kimi K2.7 Code promoted to OpenCode Frontier primary (2026-06-15), replacing K2.6 — coding-specialized post-train of the same K2 MoE base (1T/32B active, 256K context), vendor coding-benchmark gains over K2.6, 1,350 req/5h (vs K2.6's 1,150), same $0.95/$4.00 pricing. No DeepSWE/SWE-Bench/Terminal-Bench submission from Moonshot; promotion rests on family lineage + coding specialization + the "mostly coding" workload, with local validation expected. K2.6 retained in the leaderboard as the DeepSWE-anchored reference (23.9%) and available via env override.
- MiMo-V2.5-Pro request allowance raised to 3,250 req/5h (from 1,290) and MiMo-V2.5 to 30,100 req/5h after Xiaomi's 2026-05-27 price cut — MiMo-V2.5-Pro is now daily-driver viable, not focused-session only.
- MiniMax M3 effective-context note corrected (2026-06-15): the prior "~200K" figure belonged to M2.7. M3 advertises 1M with no published multi-needle degradation figure.
- OpenCode fanout restructured by DeepSWE × volume (2026-06-15). The strong-but-low-volume coders (880–1,350 req/5h) are sub-agent-only by volume → Frontier gate council: **kimi-k2.7-code + qwen3.7-max (18%) + glm-5.1 (18%)** (Moonshot/Alibaba/Z.AI). Strong mid-volume coders → Standard workhorse: **mimo-v2.5-pro (19%) + minimax-m3 (20%) + kimi-k2.7-code** (Xiaomi/MiniMax/Moonshot, trimmed to 3, GLM-5.1 dropped to Frontier-only). Fast unchanged (recon/speed, not DeepSWE-graded). DeepSeek V4 Pro (8%) removed from all default fanouts. Standard primary stays MiMo-V2.5-Pro over the 1pp-higher M3 on token efficiency (28m/49k vs 57m/98k per DeepSWE run) — the always-on workhorse rewards efficiency over a marginal score gap.
