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
| Standard | Advisory, research, pattern matching | sonnet:medium | gpt-5.5:medium | composer-2.5 | opencode-go/mimo-v2.5-pro | opencode/minimax-m2.5-free |
| Fast | Reconnaissance, extraction | haiku:medium | gpt-5.4-mini:medium | auto¹ | opencode-go/deepseek-v4-flash | opencode/mimo-v2-pro-free |

Session quality/cost is chosen on the mainthread.

¹ Envoy/tier dispatch only. Fast subagents use `fast` in install-time frontmatter (Cursor's own fast routing).

² Envoy dispatch effort. Frontier *subagents* run `xhigh` (Codex via TOML; Claude via Opus 4.7's default) — see [Effort Levels](#effort-levels).

## Session Model

Pick your session model by task depth and expected context size, not a fixed tier label. Sub-agents use their own fixed tiers regardless of session choice — Frontier handles gate authority, Fast handles recon — so you get quality where it matters without paying frontier prices on the mainthread.

**DeepSWE update (2026-06-04).** [DeepSWE](https://deepswe.datacurve.ai/) is now the strongest public signal for long-horizon delegated implementation: 113 original tasks, 91 repositories, behavior verifiers, and one fixed mini-swe-agent harness. Use it to route autonomous multi-file coding work. Keep Terminal-Bench for terminal-tool competence, SWE-Bench/LiveCodeBench for continuity with older claims, and context-window evidence for orchestration.

The table below covers the viable main-thread options for **OpenCode Go**. Non-OpenCode providers have simpler stacks (Claude: sonnet/opus, Codex: gpt-5.5).

### OpenCode Go Session Model

| Session Type | Model | req/5h | Effective Context | Why |
|---|---|---|---|---|
| **Daily driver** — quick lookups, simple edits, boilerplate, test gen, most routine coding | **DeepSeek V4 Flash** | 31,650 | ~150K | High-volume OpenCode default for scouting, cheap orchestration, and bounded edits. Not a long-horizon implementation pick: DeepSWE did not publish Flash, and V4 Pro reached only 8% on the same benchmark. |
| **Tool-calling niche** — autonomous agent with heavy API/tool use, codebase fits <200K | **MiniMax M2.5** | 6,300 | ~197K | BFCL multi-turn score remains useful, but SWE-Bench-only confidence is weak after MiniMax M2.7 reached 0.2% on DeepSWE. Validate on your repo before giving it autonomous coding work. |
| **Standard bounded work** — feature implementation, debugging, code review, moderate refactoring | **DeepSeek V4 Pro** | 3,450 | ~200K | Strong SWE-V/LCB/TB2 history, but DeepSWE reached only 8%. Use for bounded/local OpenCode work, not as the default long-horizon autonomous implementer. **Compact context every ~200K tokens** — 8-needle retrieval drops from 82% at 256K to 41% at 1M. |
| **Standard alternative** — if you prefer stability/balance | **MiniMax M2.7** | 3,400 | ~150K | Comparable volume and stable retrieval, but DeepSWE reached only 0.2%. Keep for non-coding advisory or known-good local experience, not delegated implementation. |
| **Frontend/visual-heavy** — UI work, 3D scenes, game dev | **Qwen3.6 Plus** | 3,300 | ~200K | Niche Design Arena leader and fastest output. DeepSWE reached 2.7%, so keep it scoped to visual/frontend work rather than general coding. |
| **Long agentic OpenCode session** — 200+ turns, long context, focused session | **MiMo-V2.5-Pro** | 1,290 | ~256K | 19% DeepSWE, the strongest current Standard-fanout OpenCode result after Kimi. Tight volume — use for focused sessions, not daily driving. |
| **Complex orchestration** — multi-session, >200K context, conflict resolution | **Kimi K2.6** | 1,150 | ~200K | Best OpenCode Go DeepSWE result (24%) and good long-context coherence. Tight volume — **sub-agent only**, not a daily session model. |
| **Rare planning escalation** — architecture, novel problems | **GLM-5.1** | 880 | ~150K | Clean code style, 18% DeepSWE, tightest volume — **sub-agent only**. |

**Key caveats:**

- **DeepSeek V4 Pro claims 1M context** but effective multi-needle reasoning drops sharply past ~200K (82% at 256K → 59% at 1M on MRCR, 41% at 1M on NIAH-8). Compact your conversation context around every 200K tokens for reliable multi-fact reasoning.
- **Qwen3.5 Plus (10,200 req/5h) is not recommended** for agentic sessions. Has critical bugs: tool-calling breaks after 1–2 calls (reverts to raw text), reasoning tokens suppressed when tools present. Qwen3.6 Plus fixes these.
- **DeepSWE is a fixed-harness benchmark.** It runs every model through mini-swe-agent, not native Codex CLI, Claude Code, Cursor, or OpenCode product scaffolding. Treat it as model-behavior evidence, then validate critical workflow choices on your own repo.
- **Effective context** measures where multi-needle reasoning quality holds, not advertised max. Single-fact retrieval tolerates larger windows, but agentic coding is multi-needle by nature.
- All volumes are per 5-hour rolling window on OpenCode Go subscription. See [OpenCode Request Volume Reference](#opencode-request-volume-reference) for the full table.

## Provider Selection

For day-to-day work, each provider has different strengths:

| | Claude Code | Codex | Cursor | OpenCode |
|---|------------|-------|--------|----------|
| **Strength** | Planning/review depth, environment awareness | Long-horizon delegated implementation (DeepSWE), terminal tool use | IDE integration, cheapest agentic model | Multi-model gateway and low marginal cost; weaker DeepSWE coding signal |
| **Budget** | 5h / 7-day rolling (generous) | 5h / 7-day rolling (generous) | ~$20-30 / month (tight) | Go subscription (free at margin) or Free tier (zero cost) |
| **Best for** | Planning, debugging, complex reasoning | Sandboxed execution, tool-heavy tasks | Focused implementation, inline edits | Analytical diversity, cost-sensitive workloads, chain terminus fallback |
| **Default model** | sonnet | gpt-5.5 | auto | opencode-go/deepseek-v4-flash (Go daily driver) / opencode/minimax-m2.5-free (Free) |

**Recommended primary for autonomous implementation**: Codex — GPT-5.5 is the DeepSWE leader, and GPT-5.5 medium is already competitive with Opus medium while cheaper and faster on that benchmark. Use `gpt-5.5:medium` for normal delegated coding, `gpt-5.5:high` or `xhigh` for high-failure-cost implementation.

**Recommended primary for planning/review**: Claude Code — Sonnet remains a good mainthread default, and Opus remains a strong escalation model for judgment-heavy phases. DeepSWE's qualitative analysis says Claude is more prone to missing parallel prompt requirements, so spell out mirrored branches and use verification gates on implementation-heavy Claude runs.

**Recommended secondary**: Cursor — best for IDE-integrated editing and visual multi-file changes. Composer pool is generous for daily work but watch the monthly cap. Use for focused implementation sessions.

**Envoy / cross-provider value**: Codex + Claude — GPT models are strongest on long-horizon implementation; Claude remains valuable for alternative reasoning and environment-sensitive review. Different training produces genuinely different failure modes, making cross-provider envoy dispatch more valuable than same-family second opinions.

Heavy multi-agent sessions can exhaust Claude Code Max 5x Opus hours in 2-3 days and Cursor Pro credits in a single day. Standard-tier defaults mitigate this.

### Provider budget context

| Provider | Budget model | Default | Upgrade | Recommendation |
|----------|-------------|---------|---------|----------------|
| Claude Code | 5h / 7-day rolling | sonnet:medium | opus:high | Generous budget — upgrade to opus for complex planning, review, and high-risk implementation |
| Codex | 5h / 7-day rolling | gpt-5.5:medium | gpt-5.5:high | Generous budget — upgrade effort freely for complex phases |
| Cursor | ~$20-30 / month | auto | composer-2.5 | Tight monthly cap — stay on auto, upgrade selectively to composer-2.5 |
| OpenCode Go | $60/mo flat ($10 sub), $12/5h · $30/wk rolling caps | deepseek-v4-flash (Daily driver) | mimo-v2.5-pro or kimi-k2.6 for hard coding | See [OpenCode Go Session Model](#opencode-go-session-model) for full decision table. Multi-model fanout within OpenCode via envoy (Frontier: kimi-k2.6 + deepseek-v4-pro + glm-5.1; Standard: mimo-v2.5-pro + kimi-k2.6 + deepseek-v4-pro + qwen3.6-plus; Fast: deepseek-v4-flash + qwen3.5-plus + minimax-m2.5). For long-horizon implementation, prefer Codex/Claude first; OpenCode Go is mainly cost/diversity, with MiMo now the Standard primary. |

### Cost per million tokens

| Tier | Claude | Codex | Cursor | OpenCode (Go) | OpenCode (Free) |
|------|--------|-------|--------|---------------|-----------------|
| Frontier | opus ($5/$25) | gpt-5.5 ($5/$30) | composer-2.5 ($0.50/$2.50) | kimi-k2.6 ($0, sub) | qwen3.6-plus-free (**free**) |
| Standard | sonnet ($3/$15) | gpt-5.5 ($5/$30) | composer-2.5 ($0.50/$2.50) | mimo-v2.5-pro ($0, sub) | minimax-m2.5-free (**free**) |
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
- Test on representative tasks before switching: DeepSWE-style long-horizon tasks for delegated coding, Terminal-Bench-style tasks for terminal execution, and your own repo tasks for native-harness behavior
- Pin versions in env vars during migration windows

## Cursor Limitations

- Legacy plans without Max Mode ignore subagent model config
- No effort support
- Nested subagent bug: L2 dispatch falls back to composer

## Benchmarks

> **DeepSWE** is the best public benchmark for long-horizon delegated coding. It uses original tasks and behavior verifiers, but all models run through mini-swe-agent rather than each provider's native product harness.
>
> SWE-Bench Verified (Anthropic) and SWE-Bench Pro (OpenAI) are **different benchmarks** — not directly comparable. Verified uses a curated subset; Pro uses harder, contamination-resistant tasks.
>
> **Terminal-Bench 2.0** remains the best public signal for terminal-tool execution.

### Cross-Provider Benchmark Leaderboard

Sorted by DeepSWE where available. Bold = best in column.

| Model | Provider | DeepSWE pass@1 | Best DeepSWE effort | Terminal-Bench 2.0 | SWE-Bench Verified / Pro | Price (in/out per M) |
|-------|----------|----------------|---------------------|--------------------|------------------------|----------------------|
| GPT-5.5 | Codex | **70.0%** | xhigh | **82.7%** | Pro 58.6% | $5 / $30 |
| Claude Opus 4.8 | Claude | 58.2% | max | — | — | $5 / $25 |
| GPT-5.4 | Codex | 55.5% | xhigh | 75.1% | Pro 57.7% | $2.50 / $15 |
| Claude Opus 4.7 | Claude | 54.2% | max | 69.4% | Verified 87.6% | $5 / $25 |
| Claude Sonnet 4.6 | Claude | 31.8% | high | ~59% | Verified 79.6% | $3 / $15 |
| GPT-5.4 mini | Codex | 24.3% | xhigh | 60.0% | Pro 54.4% | $0.75 / $4.50 |
| Kimi K2.6 | OpenCode | 23.9% | default | 66.7% | Verified 80.2% / Pro 58.6% | $0 (Go sub) |
| MiMo-V2.5-Pro | OpenCode | 19.5% | default | — | Pro 57.2% | $0 (Go sub) |
| GLM-5.1 | OpenCode | 17.5% | default | 63.5% | Pro 58.4% | $0 (Go sub) |
| Gemini 3.1 Pro | Google | 9.7% | default | 75.5% | — | — |
| DeepSeek V4 Pro | OpenCode | 7.5% | default | 67.9% | Verified 80.6% / Pro 55.4% | $0 (Go sub) |
| Qwen3.6 Plus | OpenCode | 2.7% | default | — | — | $0 (Go sub) |
| Claude Haiku 4.5 | Claude | 0.2% | default | — | Verified >73% | $1 / $5 |
| MiniMax M2.7 | OpenCode | 0.2% | default | — | — | $0 (Go sub) |
| Cursor Composer 2.5 | Cursor | — | — | 69.3% | — | $0.50 / $2.50 |
| DeepSeek V4 Flash | OpenCode | — | — | 56.9% | Pro 52.6% | $0 (Go sub) |
| GPT-5.3 Codex | Codex | — | — | 77.3% | Verified ~80% | $1.75 / $14 |

DeepSWE values are from Datacurve's live aggregate generated 2026-05-30. Pass@1 is scored rollout attempts; provider/verifier/network errors are excluded. Context-window failures and agent timeouts count as failures.

### Quick Picks: Which Model for Which Goal?

| Goal | Best Choice | Runner-up | Why |
|------|-------------|-----------|-----|
| Long-horizon delegated implementation | GPT-5.5 | Claude Opus 4.8 / GPT-5.4 | DeepSWE leader by a large margin; xhigh for high-stakes work, medium for normal work |
| Cost-efficient long-horizon coding | GPT-5.5 medium | GPT-5.4 xhigh | GPT-5.5 medium reaches 48% DeepSWE at lower cost/time than Opus medium; GPT-5.4 is the cheaper high-score route |
| Planning / review escalation | Claude Opus 4.8 | GPT-5.5 high | Opus remains useful for judgment-heavy phases; verify mirrored requirements carefully |
| Best terminal-tool use | GPT-5.5 | GPT-5.3 Codex / Gemini 3.1 Pro | Top Terminal-Bench 2.0 |
| Best OpenCode Go coding option | Kimi K2.6 | MiMo-V2.5-Pro | Best DeepSWE results in the Go roster, but still far below GPT/Opus |
| Daily driver (quality / price) | GPT-5.5 medium | Claude Sonnet 4.6 | Codex is stronger for delegated coding; Sonnet remains good for planning and review |
| Fast recon / extraction | DeepSeek V4 Flash | Claude Haiku 4.5 | Free, 91.6% LCB, high throughput |
| IDE-integrated editing | Cursor Composer 2.5 | — | Cheapest pool, solid TB2 (69.3%) |
| Long-context orchestration | Kimi K2.6 | GLM-5.1 | 400k–700k effective context |

### Per-Provider Notes

**Claude**: Opus 4.8 improved the Claude ceiling on DeepSWE (58.2% max vs Opus 4.7 at 54.2% max) but still trails GPT-5.5. Avoid making Opus max the default: DeepSWE shows a steep jump in cost, time, and output tokens from high to max. Claude's common failure mode on DeepSWE is missing one branch of multi-part requirements, so prompts and review briefs should enumerate mirrored behavior.

**GPT**: GPT-5.5 leads both DeepSWE and Terminal-Bench 2.0 and is the Spine Frontier and Standard model for Codex. DeepSWE's qualitative analysis says GPT has the lowest missed-requirement rate among tested configurations. GPT-5.4 remains a strong cost-efficient high-effort route.

**Cursor**: Composer 2.5 (released 2026-05-18) raised Terminal-Bench 2.0 to 69.3% (from Composer 2's 61.7%). Two usage pools — **Auto+Composer** (Composer 2.5, Auto) and **API** (Composer 1.5, GPT-5.4, Claude). Both reset monthly. Composer 2.5 Fast offers identical quality at 6× the per-token cost — use only when latency matters.

**OpenCode Go**: Older SWE-Bench and LiveCodeBench scores overstated its usefulness for long-horizon autonomous coding. Kimi K2.6 is the best Go-roster DeepSWE result at 23.9%; MiMo-V2.5-Pro follows at 19.5%; DeepSeek V4 Pro drops to 7.5%. Keep OpenCode Go for low marginal cost, diversity, and bounded work unless you explicitly select Kimi/MiMo for focused implementation.

### OpenCode Model Reference

| Model | Tier | Effective Context | req/5h | DeepSWE | Notes |
|-------|------|-------------------|--------|---------|-------|
| Kimi K2.6 | Frontier | ~200K | 1,150 | 23.9% | Best OpenCode Go long-horizon coding result and good long-context coherence. Full window 256K — modest enough to hold well. Auto-compression extends beyond window. |
| GLM-5.1 | Frontier | ~150K | 880 | 17.5% | Clean code style. DSA compressed attention. 200K full window — limited degradation risk. |
| DeepSeek V4 Pro | Standard | ~200K | 3,450 | 7.5% | Older benchmark strength, weak DeepSWE. Advertised 1M, but 8-needle retrieval drops: 82% at 256K → 59% at 1M. Compact every ~200K. |
| MiniMax M2.7 | Standard | ~150K | 3,400 | 0.2% | Stable retrieval, but not a delegated coding pick after DeepSWE. Keep for known-good local advisory behavior only. |
| Qwen3.6 Plus | Standard | ~200K | 3,300 | 2.7% | 1M advertised, Alibaba docs warn "lost in the middle." Always-on CoT eats into usable budget. Fastest output (158 tok/s). Use mainly for frontend/visual work. |
| MiMo-V2.5-Pro | Standard | ~256K | 1,290 | 19.5% | Best Standard-fanout Go result after Kimi. SWA+GA hybrid attention. GraphWalks scores meaningful at 1M (BFS 0.37, Parents 0.62). Tight volume. |
| DeepSeek V4 Flash | Fast | ~150K | 31,650 | — | Weaker retrieval than Pro at all lengths (58% at 1M vs Pro's 66%). Stay under 150K and use for recon/simple edits. |
| MiniMax M2.5 | Fast | ~197K | 6,300 | — | Full window 200K. BFCL tool-calling signal remains useful, but do not infer long-horizon coding strength from older SWE-Bench claims. |
| Qwen3.5 Plus | Fast | ~150K | 10,200 | — | **Not recommended for agentic use** — tool-calling breaks after 1–2 calls, reasoning suppressed when tools present. Single-turn structured tasks only. |

See the [leaderboard above](#cross-provider-benchmark-leaderboard) for benchmarks. All OpenCode Go models are zero marginal cost within the subscription allowance.

> **Context window is misleading.** Advertised max (e.g., 1M for DeepSeek V4 Pro) ≠ effective context. For every OpenCode Go model the gap between advertised and effective context is 30–60 points on multi-needle benchmarks. Choose by where reasoning quality holds, not API limits.

Tier assignments are driven by **context behavior + role fit + request volume**, not benchmark ranking alone:

- **Frontier** (coordination, synthesis, gate authority, sub-agent only): **Kimi K2.6** — best long-context coherence across OC Go models, holds well within its 256K window. **GLM-5.1** — solid fallback with highest code cleanliness. Both are tight on volume (880–1,150 req/5h) — reserved for gate authority, not session use.
- **Standard** (scoped implementation, debugging, advisory): **DeepSeek V4 Pro** remains the high-volume default for bounded OpenCode Standard work, but DeepSWE makes it a weak long-horizon coding choice. **MiMo-V2.5-Pro** is the stronger Standard candidate for focused implementation. **MiniMax M2.7** and **Qwen3.6 Plus** should not be treated as general delegated coding picks without local proof.
- **Fast** (recon, extraction, daily driving): **DeepSeek V4 Flash** — unlimited headroom (31,650 req/5h), 2.3× faster than Pro. **MiniMax M2.5** keeps a tool-calling niche. **Qwen3.5 Plus** — not recommended for agentic use (critical tool-calling bugs).

### OpenCode Context-Driven Routing

Pick by effective context and role, not "smartness" alone. These thresholds are tied to the actual effective context where each model holds multi-needle reasoning quality:

| Context | Session Model | Envoy Tier |
|---------|--------------|------------|
| >200K tokens | Kimi K2.6 (sub-agent only; or compact context and step down) | Frontier (Kimi K2.6, DeepSeek V4 Pro, GLM-5.1) |
| 100K–200K tokens | MiMo-V2.5-Pro for focused implementation; DeepSeek V4 Pro for bounded diversity | Standard fanout (primary: MiMo; diversity: Kimi/DeepSeek/Qwen) |
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

**DeepSeek V4 Flash is the recommended OpenCode daily driver for light work.** 31,650 req/5h (effectively unlimited) and 2.3× faster than Pro. Use it for scouting, summarization, simple edits, and cheap orchestration. Do not use the old 1.6pp SWE-Bench gap as evidence for long-horizon implementation quality.

**MiMo-V2.5-Pro is the OpenCode Standard worker.** Use it for focused implementation when you want OpenCode Go's cost/diversity path. Tight volume (1,290 req/5h) means it is not the all-day daily driver.

**DeepSeek V4 Pro is a bounded-depth fanout model.** It stays in Standard envoy fanout for localized debugging/code-review diversity. 3,450 req/5h is comfortable. Compact context every ~200K tokens.

**MiniMax M2.5 is a tool-calling niche.** If you're running an autonomous agent with heavy tool-calling and your codebase fits under 200K, BFCL remains a positive signal. Validate on your repo before assigning coding work.

**MiMo-V2.5-Pro for long agentic sessions.** 40–60% fewer tokens per trajectory. Tight volume (1,290 req/5h) — use for focused long sessions, not daily driving.

**Qwen3.6 Plus for frontend-heavy work.** Niche leader at 91% 3D ELO. Fixes Qwen3.5's agentic bugs. Fastest output at 158 tok/s. DeepSWE is weak, so keep it out of general coding defaults.

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
| Standard | MiMo-V2.5-Pro† + Kimi K2.6 + DeepSeek V4 Pro + Qwen3.6 Plus | 4 models, 4 labs (Xiaomi / Moonshot / DeepSeek / Alibaba); diversity/cost fanout, not DeepSWE-leading |
| Fast | DeepSeek V4 Flash† + MiniMax M2.5 + Qwen3.5 Plus | 3 models, 3 labs (DeepSeek / MiniMax / Alibaba) |

† Primary model — used for sub-agent pinning. Fanout includes all listed models for envoy diversity.

**Success semantics**: ≥1 model succeeds → provider round = success. All fail → provider round = failure.

**Override**: `SPINE_ENVOY_{TIER}_OPENCODE` env vars disable fanout. When set, the tier runs single-model (same as other providers).

**Note on MiMo-V2.5-Pro**: Standard primary for token efficiency and the strongest current Standard DeepSWE result among OpenCode Go models. Not promoted to Frontier despite competitive SWE-bench Pro scores — its reasoning depth limitation (commit-to-first-chain) makes it unreliable for gate authority roles.

**Note on Qwen3.5 Plus**: In Fast fanout for volume (10,200 req/5h) but not recommended for agentic envoy dispatch due to critical tool-calling bugs. Remove or replace via `SPINE_ENVOY_FAST_OPENCODE` if you encounter failures.

Additional models available on the Go subscription — MiMo-V2/Omni, Kimi K2.5, MiniMax M2.5/M2.7, Qwen3.5 Plus, GLM-5 — remain accessible via env override.

## Implementation Notes

Four mapping points encode the tier tables:

- **`install.sh`** `map_model_for_provider()` — maps tiers to provider models at install time, generating agent frontmatter for Codex TOML, Cursor `.md`, and OpenCode `.md` files.
- **`_common.sh`** `resolve_tier()` — maps tier + provider to model at runtime for envoy CLI dispatch via `invoke-{provider}.sh`.
- **`invoke-cursor.sh`** `to_cursor_model()` — maps canonical model + effort to cursor-agent model IDs for fallback after Claude/Codex failure. Each model owns its full cursor-agent ID (no shared prefix).
- **`_opencode-common.sh`** — shared transport helper for OpenCode. Owns CLI invocation, JSONL parsing, `step_finish` completeness gate, and OpenCode env sanitization.

All mapping points agree on tier:provider mappings. Intentional surface differences: Cursor Fast uses `fast` in install-time frontmatter (actual subagent dispatch) but `auto` in envoy CLI dispatch (tier table); Frontier and Standard are the only tiers meaningfully used in envoy for Cursor. Effort applies to Claude and Codex only — Cursor has no effort parameter. OpenCode uses full prefixed model strings (e.g., `opencode-go/mimo-v2.5-pro`) with no runtime prefix probing. OpenCode automatically detects Go subscription vs Free tier models. OpenCode envoy dispatch fans out to multiple models per tier (see Multi-Model Dispatch above); subagent pinning uses the primary model only.

### Agent Tier Assignments

| Agent | Tier |
|-------|------|
| consultant, debater, inspector, synthesizer, verifier | Frontier |
| analyst, curator, envoy, implementer, navigator, researcher, visualizer | Standard |
| miner, scout | Fast |

### Implementer (Standard)

**Pinned to Standard** so the implementer never tracks a Fast session model down to Haiku-class quality. Implementation quality should not depend on whether you temporarily downgraded the mainthread for cheap exploration.

**Gate dependency:** Frontier roles produce plans, merges, and review verdicts. Gates reduce worker-model risk, but they do not make a weak implementer free on long-horizon coding. If implementation quality is the bottleneck, route the work to Codex/GPT-5.5, use Opus for high-risk implementation, override the provider-specific worker where possible, or split the patch smaller.

### Escalation: session vs implementer

**Session upgrade (mainthread)** — when *your* conversation model should move to Frontier: ambiguous requirements, cascading architectural decisions, elusive root causes, very large accumulated context, or phase-gating complexity. See [docs/model-tier-assignments.md](model-tier-assignments.md) for the full trigger list.

**Implementer workload** — when *implementation* needs more than Standard even if the session stays put: multi-file architectural refactoring where the design artifact cannot fully specify cross-cutting concerns. Response: upgrade the session, use provider-specific overrides if your toolchain allows a higher tier for `@implementer` only, or split work into smaller partitions — not a substitute for Frontier session when the orchestrator itself is underpowered.
