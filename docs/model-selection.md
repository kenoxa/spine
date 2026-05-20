# Model Selection

> Which models run where, how to pick yours, and how to override the defaults.

## How Models Work in Spine

**Session model** — the model running your conversation (the mainthread). You choose this based on task complexity and budget. It does not override fixed subagent tiers: the implementer is Standard, the synthesizer is Frontier, and so on (see [Agent Tier Assignments](#agent-tier-assignments)).

**Subagents** — dispatched by skills for specific tasks (planning, reviewing, debugging). Each has an assigned tier that determines its model automatically. You don't configure these — a planner always uses a frontier model, a scout always uses a fast model, regardless of your session choice.

**Providers** — Claude Code, Codex, Cursor, and OpenCode each have their own model names. Spine maps tiers to the right model for whichever provider you use.

**Tiers** — three quality levels, from highest to lowest:

| Tier | Purpose | Claude | Codex | Cursor | OpenCode (Go) | OpenCode (Free) |
|------|---------|--------|-------|--------|---------------|-----------------|
| Frontier | Complex reasoning, gate authority | opus:high² | gpt-5.5:high² | composer-2.5 | opencode-go/kimi-k2.6 | opencode/qwen3.6-plus-free |
| Standard | Advisory, research, pattern matching | sonnet:medium | gpt-5.5:medium | composer-2.5 | opencode-go/deepseek-v4-pro | opencode/minimax-m2.5-free |
| Fast | Reconnaissance, extraction | haiku:medium | gpt-5.4-mini:medium | auto¹ | opencode-go/deepseek-v4-flash | opencode/mimo-v2-pro-free |

Session quality/cost is chosen on the mainthread.

¹ Envoy/tier dispatch only. Fast subagents use `fast` in install-time frontmatter (Cursor's own fast routing).

² Envoy dispatch effort. Frontier *subagents* run `xhigh` (Codex via TOML; Claude via Opus 4.7's default) — see [Effort Levels](#effort-levels).

## Session Model

Pick your session model by task depth and expected context size, not a fixed tier label. Sub-agents use their own fixed tiers regardless of session choice — Frontier handles gate authority, Fast handles recon — so you get quality where it matters without paying frontier prices on the mainthread.

The table below covers the viable main-thread options for **OpenCode Go**. Non-OpenCode providers have simpler stacks (Claude: sonnet/opus, Codex: gpt-5.5).

### OpenCode Go Session Model

| Session Type | Model | req/5h | Effective Context | Why |
|---|---|---|---|---|
| **Daily driver** — quick lookups, simple edits, boilerplate, test gen, most routine coding | **DeepSeek V4 Flash** | 31,650 | ~150K | Unlimited headroom, 2.3× faster than Pro, 1.6pp gap to Pro is invisible at IDE-task scale. Default to this for 70–80% of sessions. |
| **Agentic tool-calling** — autonomous agent with heavy tool use, codebase fits <200K | **MiniMax M2.5** | 6,300 | ~197K | 80.2% SWE-bench (matches Opus 4.6), #1 BFCL multi-turn (76.8%, beats Opus by 13.5pt). Best agentic workhorse when context allows. |
| **Standard day-to-day** — feature implementation, debugging, code review, moderate refactoring | **DeepSeek V4 Pro** | 3,450 | ~200K | Highest coding benchmarks in Standard tier (80.6% SWE-V, 93.5% LCB, 67.9% TB2). Reach for this when Flash isn't enough. **Compact context every ~200K tokens** — 8-needle retrieval drops from 82% at 256K to 41% at 1M. |
| **Standard alternative** — if you prefer stability/balance | **MiniMax M2.7** | 3,400 | ~150K | Comparable volume, retrieval holds across full 200K window. Less benchmark depth than V4 Pro but solid daily alternative. |
| **Frontend/visual-heavy** — UI work, 3D scenes, game dev | **Qwen3.6 Plus** | 3,300 | ~200K | Niche leader: 91% 3D ELO, 88% Game Dev in Design Arena. Fixes Qwen3.5's agentic bugs. Fastest output (158 tok/s). |
| **Long agentic session** — 200+ turns, long context, focused session | **MiMo-V2.5-Pro** | 1,290 | ~256K | 40–60% fewer tokens per trajectory vs frontier rivals. Harness awareness for self-managed context. Tight volume — use for focused sessions, not daily driving. |
| **Complex orchestration** — multi-session, >200K context, conflict resolution | **Kimi K2.6** | 1,150 | ~200K | Best long-context coherence among OC Go models. Tight volume — **sub-agent only**, not a daily session model. |
| **Rare planning escalation** — architecture, novel problems | **GLM-5.1** | 880 | ~150K | Highest code cleanliness scores. Tightest volume — **sub-agent only**. |

**Key caveats:**

- **DeepSeek V4 Pro claims 1M context** but effective multi-needle reasoning drops sharply past ~200K (82% at 256K → 59% at 1M on MRCR, 41% at 1M on NIAH-8). Compact your conversation context around every 200K tokens for reliable multi-fact reasoning.
- **Qwen3.5 Plus (10,200 req/5h) is not recommended** for agentic sessions. Has critical bugs: tool-calling breaks after 1–2 calls (reverts to raw text), reasoning tokens suppressed when tools present. Qwen3.6 Plus fixes these.
- **Effective context** measures where multi-needle reasoning quality holds, not advertised max. Single-fact retrieval tolerates larger windows, but agentic coding is multi-needle by nature.
- All volumes are per 5-hour rolling window on OpenCode Go subscription. See [OpenCode Request Volume Reference](#opencode-request-volume-reference) for the full table.

## Provider Selection

For day-to-day work, each provider has different strengths:

| | Claude Code | Codex | Cursor | OpenCode |
|---|------------|-------|--------|----------|
| **Strength** | Code reasoning (SWE-Bench) | Agentic tool use (Terminal-Bench 75.1%) | IDE integration, cheapest agentic model | Multi-model gateway (MiMo, MiniMax, GLM); Go subscription + Free tier |
| **Budget** | 5h / 7-day rolling (generous) | 5h / 7-day rolling (generous) | ~$20-30 / month (tight) | Go subscription (free at margin) or Free tier (zero cost) |
| **Best for** | Planning, debugging, complex reasoning | Sandboxed execution, tool-heavy tasks | Focused implementation, inline edits | Analytical diversity, cost-sensitive workloads, chain terminus fallback |
| **Default model** | sonnet | gpt-5.5 | auto | opencode-go/deepseek-v4-flash (Go daily driver) / opencode/minimax-m2.5-free (Free) |

**Recommended primary**: Claude Code — highest code quality benchmarks, generous rolling budget, full Spine skill and subagent support. Use Standard (sonnet) as daily driver.

**Recommended secondary**: Cursor — best for IDE-integrated editing and visual multi-file changes. Composer pool is generous for daily work but watch the monthly cap. Use for focused implementation sessions.

**Envoy / cross-provider value**: Codex — GPT-5.5's Terminal-Bench 2.0 lead (82.7% vs Sonnet's ~59%) catches agentic blind spots that Claude misses. Different training produces genuinely different failure modes, making cross-provider envoy dispatch more valuable than same-family second opinions.

Heavy multi-agent sessions can exhaust Claude Code Max 5x Opus hours in 2-3 days and Cursor Pro credits in a single day. Standard-tier defaults mitigate this.

### Provider budget context

| Provider | Budget model | Default | Upgrade | Recommendation |
|----------|-------------|---------|---------|----------------|
| Claude Code | 5h / 7-day rolling | sonnet:medium | opus:high | Generous budget — upgrade to opus freely for complex phases |
| Codex | 5h / 7-day rolling | gpt-5.5:medium | gpt-5.5:high | Generous budget — upgrade effort freely for complex phases |
| Cursor | ~$20-30 / month | auto | composer-2.5 | Tight monthly cap — stay on auto, upgrade selectively to composer-2.5 |
| OpenCode Go | $60/mo flat ($10 sub), $12/5h · $30/wk rolling caps | deepseek-v4-flash (Daily driver) | deepseek-v4-pro (Depth) | See [OpenCode Go Session Model](#opencode-go-session-model) for full decision table. Multi-model fanout within OpenCode via envoy (Frontier: kimi-k2.6 + deepseek-v4-pro + glm-5.1; Standard: minimax-m2.7 + deepseek-v4-pro + qwen3.6-plus + mimo-v2.5-pro; Fast: deepseek-v4-flash + qwen3.5-plus + minimax-m2.5). Kimi K2.6 (1,150 req/5h) is Frontier sub-agents only — Flash (31,650 req/5h) for daily driving, V4 Pro (3,450 req/5h) for depth. |

### Cost per million tokens

| Tier | Claude | Codex | Cursor | OpenCode (Go) | OpenCode (Free) |
|------|--------|-------|--------|---------------|-----------------|
| Frontier | opus ($5/$25) | gpt-5.5 ($5/$30) | composer-2.5 ($0.50/$2.50) | kimi-k2.6 ($0, sub) | qwen3.6-plus-free (**free**) |
| Standard | sonnet ($3/$15) | gpt-5.5 ($5/$30) | composer-2.5 ($0.50/$2.50) | deepseek-v4-pro ($0, sub) | minimax-m2.5-free (**free**) |
| Fast | haiku ($1/$5) | gpt-5.4-mini¹ ($0.75/$4.50) | auto ($1.25/$6.00) | deepseek-v4-flash ($0, sub) | mimo-v2-pro-free (**free**) |

> Cursor models draw from the Auto+Composer pool with a monthly allowance. Per-token cost matters less than staying within your monthly budget. Composer 2.5 Fast ($3.00/$15.00) offers the same quality at higher speed but 6× the cost — use selectively when latency matters. For higher quality beyond the pool, override to API-pool models (e.g., gpt-5.4) at provider pricing.

> OpenCode Go models are billed against a $60/month usage allowance included in the $10/month subscription. Per-token rates apply only on the Zen (pay-as-you-go) tier. Request counts are estimates based on observed average token patterns (last verified: April 2026).

## Overrides

### Envoy Tier Overrides

Env var cascade for envoy model selection:

```
SPINE_ENVOY_{TIER}_{PROVIDER} > SPINE_ENVOY_{PROVIDER} > built-in default
```

Example: `SPINE_ENVOY_FRONTIER_CLAUDE=opus:high` overrides the frontier tier for Claude envoy calls.

### Automatic Fallback

When Claude or Codex hits a rate limit, runs out of credits, or has an auth error, Spine automatically retries the same request through **cursor-agent** using the **same model**. If cursor-agent is also unavailable, the request fails — there are no further retry hops.

**How it works:**
- Claude fails → cursor-agent runs the same Claude model (e.g., `opus` → `claude-opus-4-7-thinking-high`)
- Codex fails → cursor-agent runs the same GPT model (e.g., `gpt-5.4` → `gpt-5.4-high`)
- Cursor fails → no fallback (cursor-agent models aren't available elsewhere)
- OpenCode fails → no fallback (OpenCode Go/Free models aren't available on cursor-agent)

**What you'll see:** A stderr message like `claude failed (exit 1), attempting cursor-agent fallback`, and the output header will note the fallback: `Claude Code -> Cursor-Agent Fallback`.

**What triggers fallback:** Rate limits, quota exhaustion, auth errors, and stale model IDs. Normal errors (timeouts, connection failures) do **not** trigger fallback — they propagate immediately.

**What you can control:**
- **Tier overrides** affect fallback: if you set `SPINE_ENVOY_FRONTIER_CLAUDE=sonnet:high`, the fallback mirrors your override (`claude-4.6-sonnet-medium-thinking`), not the default.
- **Debug mode**: `SPINE_ENVOY_DEBUG=1` shows the fallback decision path on stderr.
- **Cursor availability**: fallback requires `cursor-agent` on PATH. If you don't have the Cursor CLI installed, fallback is silently skipped.

**What you can't control:** The model mapping from provider models to cursor-agent IDs is automatic. There are no env vars for fallback-specific model overrides — the principle is "same model, different provider."

#### Fallback Model Mapping

| Your model | cursor-agent runs |
|---|---|
| `opus` | `claude-opus-4-7-thinking-high` |
| `sonnet` | `claude-4.6-sonnet-medium-thinking` |
| `haiku` | `auto` (Cursor's cheapest routing) |
| `gpt-5.5` | `gpt-5.5-{effort}` (`xhigh` → `gpt-5.5-extra-high`) |
| `gpt-5.4` | `gpt-5.4-{effort}` |
| `gpt-5.4-mini` | `gpt-5.4-mini-{effort}` |
| Other `gpt-*` | passed through as `{model}-{effort}` |

Claude models always use the `-thinking` variant on cursor-agent (same price, better quality). Sonnet is fixed to `medium` effort (the only variant cursor-agent offers).

### Multi-Provider Dispatch

`SPINE_ENVOY_PROVIDERS` controls which providers envoy attempts and in what order.

**Default: `claude`, `codex`, `cursor` (excluding self) + availability-gated `opencode`.** OpenCode automatically detects Go subscription vs Free models. The 3 core providers are always dispatched; OpenCode is added when the `opencode` CLI is available on `PATH`.

## Privacy

The default envoy provider ordering is **privacy-first**: providers with stronger data handling guarantees are preferred over those with weaker or undocumented policies.

| Provider | Data Training | Data Residency | IP Indemnity | Source |
|----------|--------------|----------------|--------------|--------|
| Claude | No (Enterprise); opt-out available | US | Yes (Enterprise) | anthropic.com |
| Codex | No (Enterprise); opt-out available | US | Yes (Enterprise) | openai.com |
| Cursor | Not documented per-request | US | No | cursor.com |
| OpenCode | Zero retention, no training (Go); varies by model (Free) | US/EU/Singapore | No | opencode.ai/go |

### Effort Levels

| Provider | Support | Levels |
|----------|---------|--------|
| Claude Code | Session-level only (ignored per-agent) | low, medium, high, xhigh, max |
| Codex | Per-role in TOML | minimal, low, medium, high, xhigh |
| Cursor | None | — |
| OpenCode | Yes, via `--variant` | high, minimal, max |

Agent frontmatter `effort:` is consumed only by Codex (TOML `model_reasoning_effort`). Cursor and OpenCode ignore it; Claude Code does not read it per-agent either. For Claude envoy calls, `invoke-claude.sh` reads the tier effort from `resolve_tier()` and sets `CLAUDE_CODE_EFFORT_LEVEL` at runtime — so tier effort reaches Claude envoy dispatch even though per-agent frontmatter does not.

**Frontier effort split.** Frontier *subagents* run `xhigh`: Codex via TOML `model_reasoning_effort = "xhigh"`, Claude via Opus 4.7's shipped default (`xhigh` since Claude Code v2.1.117). Frontier *envoy* dispatch stays `high` — `run.sh` runs under the 600 s Bash-tool cap (`agents/envoy.md` step 3), and `xhigh` roughly doubles reasoning wall-clock, risking a timeout the trap escalates to the whole parallel batch.

See [`env.example`](../env.example) for the full override template.

Env var changes take effect immediately (runtime). Model mapping changes require re-running `install.sh`.

## When to Upgrade Models

- Monitor provider deprecation announcements
- Test on representative tasks (SWE-Bench, Terminal-Bench equivalents) before switching
- Pin versions in env vars during migration windows

## Cursor Limitations

- Legacy plans without Max Mode ignore subagent model config
- No effort support
- Nested subagent bug: L2 dispatch falls back to composer

## Benchmarks

> SWE-Bench Verified (Anthropic) and SWE-Bench Pro (OpenAI) are **different benchmarks** — not directly comparable. Verified uses a curated subset; Pro uses harder, contamination-resistant tasks.
>
> **Terminal-Bench 2.0** is the most directly comparable benchmark across all providers — it measures agentic terminal tool use.

### Cross-Provider Benchmark Leaderboard

Sorted by Terminal-Bench 2.0. Bold = best in column.

| Model | Provider | Terminal-Bench 2.0 | SWE-Bench Verified | SWE-Bench Pro | LiveCodeBench | Price (in/out per M) |
|-------|----------|-------------------|-------------------|--------------|---------------|----------------------|
| GPT-5.5 | Codex | **82.7%** | — | 58.6% | — | $5 / $30 |
| GPT-5.3 Codex | Codex | **77.3%** | ~80%‡ | — | — | $1.75 / $14 |
| Gemini 3.1 Pro | Google | **75.5%** | — | — | — | — |
| GPT-5.4 | Codex | 75.1% | — | **57.7%** | — | $2.50 / $15 |
| Claude Opus 4.7 | Claude | 69.4% | **87.6%** | — | — | $5 / $25 |
| Cursor Composer 2.5 | Cursor | 69.3% | — | — | — | $0.50 / $2.50 |
| DeepSeek V4 Pro | OpenCode | 67.9% | **80.6%** | 55.4% | **93.5%** | $0 (Go sub) |
| Kimi K2.6 | OpenCode | 66.7% | 80.2% | 58.6% | 89.6% | $0 (Go sub) |
| GLM-5.1 | OpenCode | 63.5% | — | 58.4% | — | $0 (Go sub) |
| GPT-5.4 mini | Codex | 60.0% | — | 54.4% | — | $0.75 / $4.50 |
| Claude Sonnet 4.6 | Claude | ~59% | 79.6% | — | — | $3 / $15 |
| DeepSeek V4 Flash | OpenCode | 56.9% | — | 52.6% | 91.6% | $0 (Go sub) |
| GPT-5.4 nano | Codex | 46.3%† | — | 52.4% | — | $0.20 / $1.25 |
| Claude Haiku 4.5 | Claude | — | >73% | — | — | $1 / $5 |

† not independently verified · ‡ SWE-Bench Verified (not Pro)

### Quick Picks: Which Model for Which Goal?

| Goal | Best Choice | Runner-up | Why |
|------|-------------|-----------|-----|
| Maximum code quality (unlimited budget) | Claude Opus 4.7 | GPT-5.3 Codex | Highest SWE-V (87.6%), strong TB2 |
| Best agentic tool use | GPT-5.5 | GPT-5.3 Codex / Gemini 3.1 Pro | Top TB2 (82.7%) |
| Best free option | DeepSeek V4 Pro (OpenCode Go) | Kimi K2.6 | SWE-V #1, LCB #1, zero cost |
| Daily driver (quality / price) | Claude Sonnet 4.6 | GPT-5.4 | Strong at mid-tier price |
| Fast recon / extraction | DeepSeek V4 Flash | Claude Haiku 4.5 | Free, 91.6% LCB, high throughput |
| IDE-integrated editing | Cursor Composer 2.5 | — | Cheapest pool, solid TB2 (69.3%) |
| Long-context orchestration | Kimi K2.6 | GLM-5.1 | 400k–700k effective context |

### Per-Provider Notes

**Claude**: Opus 4.6 (SWE-V 80.8%) was superseded by Opus 4.7 on 2026-04-16.

**GPT**: GPT-5.5 (released 2026-04-23) leads Terminal-Bench 2.0 at 82.7% and is the Spine Frontier and Standard model for Codex. GPT-5.3 Codex reports ~80% on SWE-Bench **Verified** (not Pro), making it comparable to Claude Opus tier rather than GPT-5.4's Pro score. GPT-5.4 leads Toolathlon at 54.6%.

**Cursor**: Composer 2.5 (released 2026-05-18) raised Terminal-Bench 2.0 to 69.3% (from Composer 2's 61.7%). Two usage pools — **Auto+Composer** (Composer 2.5, Auto) and **API** (Composer 1.5, GPT-5.4, Claude). Both reset monthly. Composer 2.5 Fast offers identical quality at 6× the per-token cost — use only when latency matters.

### OpenCode Model Reference

| Model | Tier | Effective Context | req/5h | Notes |
|-------|------|-------------------|--------|-------|
| Kimi K2.6 | Frontier | ~200K | 1,150 | Best long-context coherence among OC Go. Full window 256K — modest enough to hold well. Auto-compression extends beyond window. |
| GLM-5.1 | Frontier | ~150K | 880 | Highest code cleanliness. DSA compressed attention. 200K full window — limited degradation risk. |
| DeepSeek V4 Pro | Standard | ~200K | 3,450 | Advertised 1M, but 8-needle retrieval drops: 82% at 256K → 59% at 1M. Compact every ~200K. |
| MiniMax M2.7 | Standard | ~150K | 3,400 | Retrieval holds across full 200K window. "I haven't hit the severe NIH degradation that plagues cheaper models" — independent review. |
| Qwen3.6 Plus | Standard | ~200K | 3,300 | 1M advertised, Alibaba docs warn "lost in the middle." Always-on CoT eats into usable budget. Fastest output (158 tok/s). No independent long-context evals. |
| MiMo-V2.5-Pro | Standard | ~256K | 1,290 | SWA+GA hybrid attention. GraphWalks scores meaningful at 1M (BFS 0.37, Parents 0.62). Third-party evals pending (Apr 22 release). |
| DeepSeek V4 Flash | Fast | ~150K | 31,650 | Weaker retrieval than Pro at all lengths (58% at 1M vs Pro's 66%). Stay under 150K. |
| MiniMax M2.5 | Fast | ~197K | 6,300 | Full window 200K. 80.2% SWE-bench (matches Opus 4.6). Best agentic workhorse for fitting codebases. |
| Qwen3.5 Plus | Fast | ~150K | 10,200 | **Not recommended for agentic use** — tool-calling breaks after 1–2 calls, reasoning suppressed when tools present. Single-turn structured tasks only. |

See the [leaderboard above](#cross-provider-benchmark-leaderboard) for benchmarks. All OpenCode Go models are zero marginal cost within the subscription allowance.

> **Context window is misleading.** Advertised max (e.g., 1M for DeepSeek V4 Pro) ≠ effective context. For every OpenCode Go model the gap between advertised and effective context is 30–60 points on multi-needle benchmarks. Choose by where reasoning quality holds, not API limits.

Tier assignments are driven by **context behavior + role fit + request volume**, not benchmark ranking alone:

- **Frontier** (coordination, synthesis, gate authority, sub-agent only): **Kimi K2.6** — best long-context coherence across OC Go models, holds well within its 256K window. **GLM-5.1** — solid fallback with highest code cleanliness. Both are tight on volume (880–1,150 req/5h) — reserved for gate authority, not session use.
- **Standard** (scoped implementation, debugging, advisory): **DeepSeek V4 Pro** — best coding benchmarks in tier (80.6% SWE-V, 93.5% LCB), comfortable 3,450 req/5h. Effective context ~200K — compact around this. **MiniMax M2.7** — comparable volume (3,400 req/5h), stable retrieval. **Qwen3.6 Plus** — niche leader for frontend/visual work. **MiMo-V2.5-Pro** — token-efficient for long agentic sessions but tight volume (1,290 req/5h).
- **Fast** (recon, extraction, daily driving): **DeepSeek V4 Flash** — unlimited headroom (31,650 req/5h), 2.3× faster than Pro. **MiniMax M2.5** — dark horse: 80.2% SWE-bench, #1 BFCL multi-turn tool calling. **Qwen3.5 Plus** — not recommended for agentic use (critical tool-calling bugs).

### OpenCode Context-Driven Routing

Pick by effective context and role, not "smartness" alone. These thresholds are tied to the actual effective context where each model holds multi-needle reasoning quality:

| Context | Session Model | Envoy Tier |
|---------|--------------|------------|
| >200K tokens | Kimi K2.6 (sub-agent only; or compact context and step down) | Frontier (Kimi K2.6, DeepSeek V4 Pro, GLM-5.1) |
| 100K–200K tokens | DeepSeek V4 Pro, MiniMax M2.7, Qwen3.6 Plus, MiMo-V2.5-Pro | Standard fanout (primary: DeepSeek V4 Pro) |
| <100K tokens | DeepSeek V4 Flash, MiniMax M2.5 | Fast fanout |

Routing rules:
- If task coordinates multiple sessions, merges reports, or resolves conflicts → **Frontier** envoy
- If task is scoped implementation or debugging → **Standard** session model
- If task is small, parallel, or exploratory → **Fast** session model
- If accumulated context exceeds ~200K on a Standard session → **compact your context** or escalate to Frontier

Mental model:
- **Frontier** = decision authority (sub-agent only)
- **Standard** = problem solver
- **Fast** = daily driver + exploration layer

### OpenCode Session Model

Pick your session model from the [OpenCode Go Session Model](#opencode-go-session-model) table above. The short version:

**DeepSeek V4 Flash is the recommended daily driver.** 31,650 req/5h (effectively unlimited), 2.3× faster than Pro, and the 1.6pp SWE-bench gap to Pro is functionally invisible at IDE-task scale. Use it for 70–80% of your sessions.

**DeepSeek V4 Pro is your depth option.** When Flash isn't enough (complex debugging, architectural decisions, multi-file changes), switch to V4 Pro. 3,450 req/5h is comfortable. Compact context every ~200K tokens.

**MiniMax M2.5 is the agentic dark horse.** If you're running an autonomous agent with heavy tool-calling and your codebase fits under 200K, M2.5 matches Opus 4.6 on SWE-bench (80.2%) and dominates multi-turn tool calling (76.8% BFCL).

**MiMo-V2.5-Pro for long agentic sessions.** 40–60% fewer tokens per trajectory. Tight volume (1,290 req/5h) — use for focused long sessions, not daily driving.

**Qwen3.6 Plus for frontend-heavy work.** Niche leader at 91% 3D ELO. Fixes Qwen3.5's agentic bugs. Fastest output at 158 tok/s.

**Kimi K2.6 and GLM-5.1 are sub-agent only.** Their tight volumes (880–1,150 req/5h) make them unsuitable as session models. Reserved for Frontier gate authority roles (consultant, inspector, verifier, synthesizer).

### OpenCode Request Volume Reference

Estimated request counts based on typical Go subscription usage patterns:

| Model | req/5h | req/week | req/month |
|---|---|---|---|
| DeepSeek V4 Flash | 31,650 | 79,050 | 158,150 |
| Qwen3.5 Plus | 10,200 | 25,200 | 50,500 |
| MiniMax M2.5 | 6,300 | 15,900 | 31,800 |
| DeepSeek V4 Pro | 3,450 | 8,550 | 17,150 |
| MiniMax M2.7 | 3,400 | 8,500 | 17,000 |
| Qwen3.6 Plus | 3,300 | 8,200 | 16,300 |
| MiMo-V2-Omni | 2,150 | 5,450 | 10,900 |
| MiMo-V2.5 (≤256K) | 2,150 | 5,450 | 10,900 |
| MiMo-V2-Pro | 1,290 | 3,225 | 6,450 |
| MiMo-V2.5-Pro | 1,290 | 3,225 | 6,450 |
| Kimi K2.5 | 1,850 | 4,630 | 9,250 |
| Kimi K2.6 | 1,150 | 2,880 | 5,750 |
| GLM-5 | 1,150 | 2,880 | 5,750 |
| GLM-5.1 | 880 | 2,150 | 4,300 |

Estimates based on observed average request patterns:
- DeepSeek V4 Flash — 790 input, 68,000 cached, 280 output tokens/req
- DeepSeek V4 Pro — 750 input, 82,000 cached, 290 output tokens/req
- Qwen3.5 Plus — 410 input, 47,000 cached, 140 output tokens/req
- Qwen3.6 Plus — 500 input, 57,000 cached, 190 output tokens/req
- MiniMax M2.7/M2.5 — 300 input, 55,000 cached, 125 output tokens/req
- Kimi K2.5/K2.6 — 870 input, 55,000 cached, 200 output tokens/req
- MiMo-V2-Pro — 350 input, 41,000 cached, 250 output tokens/req
- MiMo-V2-Omni — 1,000 input, 60,000 cached, 140 output tokens/req
- MiMo-V2.5-Pro — 350 input, 41,000 cached, 250 output tokens/req
- MiMo-V2.5 — 1,000 input, 60,000 cached, 140 output tokens/req
- GLM-5/5.1 — 700 input, 52,000 cached, 150 output tokens/req

Volume determines session model viability:
- **>10,000 req/5h**: Effectively unlimited — Flash, Qwen3.5 Plus (but buggy)
- **3,000–10,000 req/5h**: Comfortable for daily driving — V4 Pro, MiniMax M2.5/M2.7, Qwen3.6 Plus
- **1,000–3,000 req/5h**: Tight — works for focused sessions, not all-day use — MiMo variants
- **<1,000 req/5h**: Sub-agent only — Kimi K2.6, GLM-5.1

### OpenCode Multi-Model Dispatch

Envoy dispatch within OpenCode uses multi-model fanout per tier. Each model runs in an isolated `XDG_DATA_HOME` process and produces a separate output file under `<base>.opencode.<slug>.md`.

| Tier | Models | Fanout |
|------|--------|--------|
| Frontier | Kimi K2.6 + DeepSeek V4 Pro + GLM-5.1 | 3 models, 3 labs (Moonshot / DeepSeek / Z.AI-Tsinghua) |
| Standard | DeepSeek V4 Pro† + MiniMax M2.7 + Qwen3.6 Plus + MiMo-V2.5-Pro | 4 models, 4 labs (DeepSeek / MiniMax / Alibaba / Xiaomi) |
| Fast | DeepSeek V4 Flash† + MiniMax M2.5 + Qwen3.5 Plus | 3 models, 3 labs (DeepSeek / MiniMax / Alibaba) |

† Primary model — used for sub-agent pinning. Fanout includes all listed models for envoy diversity.

**Success semantics**: ≥1 model succeeds → provider round = success. All fail → provider round = failure.

**Override**: `SPINE_ENVOY_{TIER}_OPENCODE` env vars disable fanout. When set, the tier runs single-model (same as other providers).

**Note on MiMo-V2.5-Pro**: Included in Standard fanout for its token efficiency in agentic tasks (40–60% fewer tokens per trajectory). Not promoted to Frontier despite competitive SWE-bench Pro scores — its reasoning depth limitation (commit-to-first-chain) makes it unreliable for gate authority roles. Use `SPINE_ENVOY_STANDARD_OPENCODE` to override.

**Note on Qwen3.5 Plus**: In Fast fanout for volume (10,200 req/5h) but not recommended for agentic envoy dispatch due to critical tool-calling bugs. Remove or replace via `SPINE_ENVOY_FAST_OPENCODE` if you encounter failures.

Additional models available on the Go subscription — MiMo-V2/Omni, Kimi K2.5, MiniMax M2.5/M2.7, Qwen3.5 Plus, GLM-5 — remain accessible via env override.

## Implementation Notes

Four mapping points encode the tier tables:

- **`install.sh`** `map_model_for_provider()` — maps tiers to provider models at install time, generating agent frontmatter for Codex TOML, Cursor `.md`, and OpenCode `.md` files.
- **`_common.sh`** `resolve_tier()` — maps tier + provider to model at runtime for envoy CLI dispatch via `invoke-{provider}.sh`.
- **`invoke-cursor.sh`** `to_cursor_model()` — maps canonical model + effort to cursor-agent model IDs for fallback after Claude/Codex failure. Each model owns its full cursor-agent ID (no shared prefix).
- **`_opencode-common.sh`** — shared transport helper for OpenCode. Owns CLI invocation, JSONL parsing, `step_finish` completeness gate, and OpenCode env sanitization.

All mapping points agree on tier:provider mappings. Intentional surface differences: Cursor Fast uses `fast` in install-time frontmatter (actual subagent dispatch) but `auto` in envoy CLI dispatch (tier table); Frontier and Standard are the only tiers meaningfully used in envoy for Cursor. Effort applies to Claude and Codex only — Cursor has no effort parameter. OpenCode uses full prefixed model strings (e.g., `opencode-go/deepseek-v4-pro`) with no runtime prefix probing. OpenCode automatically detects Go subscription vs Free tier models. OpenCode envoy dispatch fans out to multiple models per tier (see Multi-Model Dispatch above); subagent pinning uses the primary model only.

### Agent Tier Assignments

| Agent | Tier |
|-------|------|
| consultant, debater, inspector, synthesizer, verifier | Frontier |
| analyst, curator, envoy, implementer, navigator, researcher, visualizer | Standard |
| miner, scout | Fast |

### Implementer (Standard)

**Pinned to Standard** so the implementer never tracks a Fast session model down to Haiku-class quality. Implementation quality should not depend on whether you temporarily downgraded the mainthread for cheap exploration.

**Gate dependency:** Frontier roles produce plans, merges, and review verdicts; Frontier gates absorb any benchmark gap by design — the implementer executes partitioned writes behind those gates (see benchmarks above). Treating the implementer as a Standard worker behind Frontier gates matches the "strong gates, efficient workers" pattern described in [model-tier-assignments.md](model-tier-assignments.md).

### Escalation: session vs implementer

**Session upgrade (mainthread)** — when *your* conversation model should move to Frontier: ambiguous requirements, cascading architectural decisions, elusive root causes, very large accumulated context, or phase-gating complexity. See [docs/model-tier-assignments.md](model-tier-assignments.md) for the full trigger list.

**Implementer workload** — when *implementation* needs more than Standard even if the session stays put: multi-file architectural refactoring where the design artifact cannot fully specify cross-cutting concerns. Response: upgrade the session, use provider-specific overrides if your toolchain allows a higher tier for `@implementer` only, or split work into smaller partitions — not a substitute for Frontier session when the orchestrator itself is underpowered.
