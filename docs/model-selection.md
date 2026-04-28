# Model Selection

> Which models run where, how to pick yours, and how to override the defaults.

## How Models Work in Spine

**Session model** — the model running your conversation (the mainthread). You choose this based on task complexity and budget. It does not override fixed subagent tiers: the implementer is Standard, the synthesizer is Frontier, and so on (see [Agent Tier Assignments](#agent-tier-assignments)).

**Subagents** — dispatched by skills for specific tasks (planning, reviewing, debugging). Each has an assigned tier that determines its model automatically. You don't configure these — a planner always uses a frontier model, a scout always uses a fast model, regardless of your session choice.

**Providers** — Claude Code, Codex, Cursor, and OpenCode each have their own model names. Spine maps tiers to the right model for whichever provider you use.

**Tiers** — three quality levels, from highest to lowest:

| Tier | Purpose | Claude | Codex | Cursor | OpenCode (Go) | OpenCode (Free) |
|------|---------|--------|-------|--------|---------------|-----------------|
| Frontier | Complex reasoning, gate authority | opus:high | gpt-5.4:high | composer-2 | opencode-go/kimi-k2.6 | opencode/qwen3.6-plus-free |
| Standard | Advisory, research, pattern matching | sonnet:medium | gpt-5.4:medium | composer-2 | opencode-go/minimax-m2.7 | opencode/minimax-m2.5-free |
| Fast | Reconnaissance, extraction | haiku:medium | gpt-5.4-mini:medium | auto¹ | opencode-go/deepseek-v4-flash | opencode/mimo-v2-pro-free |

Session quality/cost is chosen on the mainthread.

¹ Envoy/tier dispatch only. Fast subagents use `fast` in install-time frontmatter (Cursor's own fast routing).

## Session Model

**Standard is the recommended default.** It provides a good balance of quality, cost, and speed. Subagents still use specialized models (frontier for gate authority, fast for recon) regardless of your session choice — you get the quality where it matters most without paying frontier prices on the mainthread.

When to switch tiers:

- **Upgrade to Frontier** — ambiguous requirements, cascading architectural decisions, elusive root causes, multi-file changes with cross-cutting concerns
- **Standard handles** — focused implementation, code review, straightforward debugging, pattern matching, most day-to-day work
- **Downgrade to Fast** — quick lookups, simple file edits, boilerplate generation

Standard is safe because the gate stack holds: Frontier subagents (consultant, inspector, verifier, synthesizer) handle gate decisions regardless of your session model — strong gates, efficient workers. Opus drains the rolling window ~1.67× faster than Sonnet; keeping the mainthread at Standard preserves budget for the subagent calls that matter. GPT-5.4 and Sonnet 4.6 have identical output pricing ($15/M), making model selection between providers a pure quality decision.

## Provider Selection

For day-to-day work, each provider has different strengths:

| | Claude Code | Codex | Cursor | OpenCode |
|---|------------|-------|--------|----------|
| **Strength** | Code reasoning (SWE-Bench) | Agentic tool use (Terminal-Bench 75.1%) | IDE integration, cheapest agentic model | Multi-model gateway (MiMo, MiniMax, GLM); Go subscription + Free tier |
| **Budget** | 5h / 7-day rolling (generous) | 5h / 7-day rolling (generous) | ~$20-30 / month (tight) | Go subscription (free at margin) or Free tier (zero cost) |
| **Best for** | Planning, debugging, complex reasoning | Sandboxed execution, tool-heavy tasks | Focused implementation, inline edits | Analytical diversity, cost-sensitive workloads, chain terminus fallback |
| **Default model** | sonnet | gpt-5.4 | auto | opencode-go/minimax-m2.7 (Go) / opencode/minimax-m2.5-free (Free) |

**Recommended primary**: Claude Code — highest code quality benchmarks, generous rolling budget, full Spine skill and subagent support. Use Standard (sonnet) as daily driver.

**Recommended secondary**: Cursor — best for IDE-integrated editing and visual multi-file changes. Composer pool is generous for daily work but watch the monthly cap. Use for focused implementation sessions.

**Envoy / cross-provider value**: Codex — GPT's Terminal-Bench strength (75.1% vs Sonnet's ~59%) catches agentic blind spots that Claude misses. Different training produces genuinely different failure modes, making cross-provider envoy dispatch more valuable than same-family second opinions.

Heavy multi-agent sessions can exhaust Claude Code Max 5x Opus hours in 2-3 days and Cursor Pro credits in a single day. Standard-tier defaults mitigate this.

### Provider budget context

| Provider | Budget model | Default | Upgrade | Recommendation |
|----------|-------------|---------|---------|----------------|
| Claude Code | 5h / 7-day rolling | sonnet:medium | opus:high | Generous budget — upgrade to opus freely for complex phases |
| Codex | 5h / 7-day rolling | gpt-5.4:medium | gpt-5.4:high | Generous budget — upgrade effort freely for complex phases |
| Cursor | ~$20-30 / month | auto | composer-2 | Tight monthly cap — stay on auto, upgrade selectively to composer-2 |
| OpenCode Go | $60/mo flat ($10 sub), $12/5h · $30/wk rolling caps | minimax-m2.7 (Standard) | kimi-k2.6 (Frontier) | Pick by effective context per role — Fast for recon/extraction, Standard for scoped implementation, Frontier for synthesis and gate authority. Multi-model fanout within OpenCode via envoy (Frontier: kimi-k2.6 + glm-5.1; Standard: minimax-m2.7 + deepseek-v4-pro + qwen3.6-plus; Fast: deepseek-v4-flash + qwen3.5-plus + minimax-m2.5). Caps rarely bind in practice; fall back to free models if hit. |

### Cost per million tokens

| Tier | Claude | Codex | Cursor | OpenCode (Go) | OpenCode (Free) |
|------|--------|-------|--------|---------------|-----------------|
| Frontier | opus ($5/$25) | gpt-5.4 ($2.50/$15) | composer-2 ($0.50/$2.50) | kimi-k2.6 ($0, sub) | qwen3.6-plus-free (**free**) |
| Standard | sonnet ($3/$15) | gpt-5.4 ($2.50/$15) | auto ($1.25/$6.00) | minimax-m2.7 ($0, sub) | minimax-m2.5-free (**free**) |
| Fast | haiku ($1/$5) | gpt-5.4-mini¹ ($0.75/$4.50) | composer-2 ($0.50/$2.50) | deepseek-v4-flash ($0, sub) | mimo-v2-pro-free (**free**) |

> Cursor models draw from the Auto+Composer pool with a monthly allowance. Per-token cost matters less than staying within your monthly budget. Composer 2 Fast ($1.50/$7.50) offers the same quality at higher speed but 3× the cost — use selectively when latency matters. For higher quality beyond the pool, override to API-pool models (e.g., gpt-5.4) at provider pricing.

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
- Claude fails → cursor-agent runs the same Claude model (e.g., `opus` → `claude-opus-4-7-high-thinking`)
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
| `opus` | `claude-opus-4-7-high-thinking` |
| `sonnet` | `claude-4.6-sonnet-medium-thinking` |
| `haiku` | `auto` (Cursor's cheapest routing) |
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
| Claude Code | Session-level only (ignored per-agent) | — |
| Codex | Per-role in TOML | minimal, low, medium, high |
| Cursor | None | — |
| OpenCode | Yes, via `--variant` | high, minimal, max |

Agent frontmatter `effort:` is not consumed by Claude Code directly. However, `invoke-claude.sh` reads the tier's effort value from `resolve_tier()` and sets `CLAUDE_CODE_EFFORT_LEVEL` at runtime for envoy dispatch. This means effort values in agent files ARE effective for Claude envoy calls — the runtime script bridges the gap.

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

### Claude (SWE-Bench Verified)

| Model | SWE-Bench Verified | Terminal-Bench | Pricing (in/out per M) |
|-------|-------------------|----------------|----------------------|
| Opus 4.7 | 87.6% | 69.4% | $5 / $25 |
| Sonnet 4.6 | 79.6% | ~59% | $3 / $15 |
| Haiku 4.5 | >73% | — | $1 / $5 |

### Claude — Superseded

| Model | SWE-Bench Verified | Pricing (in/out per M) | Superseded |
|-------|-------------------|----------------------|------------|
| Opus 4.6 | 80.8% | $5 / $25 | 2026-04-16 |

### GPT (SWE-Bench Pro)

| Model | SWE-Bench Pro | Terminal-Bench | Toolathlon | Pricing (in/out per M) |
|-------|--------------|----------------|------------|----------------------|
| GPT-5.4 | 57.7% | 75.1% | 54.6% | $2.50 / $15 |
| GPT-5.4 mini | 54.4% | 60.0% | 42.9% | $0.75 / $4.50 |
| GPT-5.4 nano | 52.4% | 46.3%† | 35.5% | $0.20 / $1.25 |
| GPT-5.3 Codex | ~80%‡ | 77.3% | — | $1.75 / $14 |

† not independently verified · ‡ SWE-Bench Verified (not Pro)

### Cursor

> Two usage pools: **Auto+Composer** (more included, covers Auto and Composer models) and **API** (provider-priced, covers GPT-5.4, Claude, etc.). Both reset monthly.

| Model | Terminal-Bench | Pricing (in/out per M) | Pool |
|-------|----------------|----------------------|------|
| Composer 2 | 61.7% | $0.50 / $2.50 | Composer |
| Composer 2 Fast | 61.7% | $1.50 / $7.50 | Composer |
| Composer 1.5 | 47.9% | $3.50 / $17.50 | API |
| Auto | — | $1.25 / $6.00 | Auto+Composer |

### OpenCode-Available Models

| Model | Role | Effective Context | Coding Bench | Pricing |
|-------|------|-------------------|--------------|---------|
| Kimi K2.6 | Frontier | ~400k–700k | SWE-P 58.6†, SWE-V 80.2†, TB2 66.7† | $0 (Go sub) |
| GLM-5.1 | Frontier | ~250k–400k | — | $0 (Go sub) |
| MiniMax M2.7 | Standard | ~100k–250k | — | $0 (Go sub) |
| DeepSeek V4 Pro | Standard | ~80k–150k | SWE-V 80.6† (#1), LCB 93.5† (#1), Codeforces #1† | $0 (Go sub) |
| Qwen3.6 Plus | Standard | ~80k–150k | — | $0 (Go sub) |
| DeepSeek V4 Flash | Fast | ~50k–90k | ~7–10pp below V4-Pro on agentic† | $0 (Go sub) |
| Qwen3.5 Plus | Fast | ~60k–100k | — | $0 (Go sub) |
| MiniMax M2.5 | Fast | ~60k–100k | — | $0 (Go sub) |

† vendor-self-reported benchmark score

> **Context window is misleading.** Advertised max (e.g., 1M for DeepSeek V4 Pro) ≠ effective context. Model choice depends on the range where reasoning stays stable, not API limits.

Tier assignments are driven by **context behavior + role fit**, not benchmark ranking alone:

- **Frontier** (coordination, synthesis, gate authority): **Kimi K2.6** — best long-context coherence; maintains stability across large, evolving contexts. **GLM-5.1** — solid fallback, cheaper frontier. DeepSeek V4 Pro is intentionally **not** Frontier: its effective context (~80k–150k) and degradation under accumulation make it a deep worker for scoped reasoning, not a system coordinator for long-horizon synthesis.
- **Standard** (scoped implementation, debugging, advisory): **MiniMax M2.7** — best default balance. **DeepSeek V4 Pro** — excels at deep, focused reasoning within bounded scope (debugging, implementation); degrades under long context accumulation despite 1M advertised context. **Qwen3.6 Plus** — stable fallback.
- **Fast** (recon, extraction, parallel exploration): **DeepSeek V4 Flash** — massive throughput, latency-optimized. **Qwen3.5 Plus** — safer cheap option. **MiniMax M2.5** — balanced cheap option.

### OpenCode Context-Driven Routing

Pick by effective context and role, not "smartness" alone:

| Context | Tier | Models |
|---------|------|--------|
| >200k tokens | Frontier | Kimi K2.6, GLM-5.1 |
| 100k–200k tokens | Standard | MiniMax M2.7, DeepSeek V4 Pro, Qwen3.6 Plus |
| <100k tokens | Fast | DeepSeek V4 Flash, Qwen3.5 Plus, MiniMax M2.5 |

Routing rules:
- If task coordinates multiple sessions, merges reports, or resolves conflicts → **Frontier**
- If task is scoped implementation or debugging → **Standard**
- If task is small, parallel, or exploratory → **Fast**
- If worker hits ambiguity or conflict → escalate to **Frontier**

Mental model:
- **Frontier** = decision authority
- **Standard** = problem solver
- **Fast** = search + exploration layer

### OpenCode Session Model

**Standard (`opencode-go/minimax-m2.7`) is the recommended default** for day-to-day work.

Within Standard, route by task depth:
- **MiniMax M2.7** — default for focused implementation, straightforward debugging, pattern matching
- **DeepSeek V4 Pro** — scoped debugging or hard implementation where deep reasoning matters more than context size (effective ~80k–150k)

When to upgrade tier:
- **Frontier (`opencode-go/kimi-k2.6`)** — ambiguous requirements, multi-session coordination, merging reports, resolving conflicts, or accumulated context >200k tokens
- **Fast (`opencode-go/deepseek-v4-flash`)** — quick lookups, simple file edits, parallel exploration

### OpenCode Multi-Model Dispatch

Envoy dispatch within OpenCode uses multi-model fanout per tier. Each model runs in an isolated `XDG_DATA_HOME` process and produces a separate output file under `<base>.opencode.<slug>.md`.

| Tier | Models | Fanout |
|------|--------|--------|
| Frontier | Kimi K2.6 + GLM-5.1 | 2 models, 2 labs (Moonshot / Z.AI-Tsinghua) |
| Standard | MiniMax M2.7 + DeepSeek V4 Pro + Qwen3.6 Plus | 3 models, 3 labs (MiniMax / DeepSeek / Alibaba) |
| Fast | DeepSeek V4 Flash + Qwen3.5 Plus + MiniMax M2.5 | 3 models, 3 labs (DeepSeek / Alibaba / MiniMax) |

**Success semantics**: ≥1 model succeeds → provider round = success. All fail → provider round = failure.

**Override**: `SPINE_ENVOY_{TIER}_OPENCODE` env vars disable fanout. When set, the tier runs single-model (same as other providers).

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
