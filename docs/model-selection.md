# Model Selection

> Which models run where, how to pick yours, and how to override the defaults.

## How Models Work in Spine

**Session model** — the model running your conversation (the mainthread). You choose this based on task complexity and budget. It also drives adaptive agents like the implementer and synthesizer.

**Subagents** — dispatched by skills for specific tasks (planning, reviewing, debugging). Each has an assigned tier that determines its model automatically. You don't configure these — a planner always uses a frontier model, a scout always uses a fast model, regardless of your session choice.

**Providers** — Claude Code, Codex, and Cursor each have their own model names. Spine maps tiers to the right model for whichever provider you use.

**Tiers** — four quality levels, from highest to lowest:

| Tier | Purpose | Claude | Codex | Cursor |
|------|---------|--------|-------|--------|
| Frontier | Complex reasoning, gate authority | opus | gpt-5.4 | composer-2 |
| Standard | Advisory, research, pattern matching | sonnet | gpt-5.4-mini | composer-2 |
| Fast | Reconnaissance, extraction | haiku | gpt-5.4-nano | auto |
| Adaptive | Tracks your session model | — | — | — |

## Session Model

**Standard is the recommended default.** It provides a good balance of quality, cost, and speed. Subagents still use specialized models (frontier for gate authority, fast for recon) regardless of your session choice — you get the quality where it matters most without paying frontier prices on the mainthread.

When to switch tiers:

- **Upgrade to Frontier** — ambiguous requirements, cascading architectural decisions, elusive root causes, multi-file changes with cross-cutting concerns
- **Standard handles** — focused implementation, code review, straightforward debugging, pattern matching, most day-to-day work
- **Downgrade to Fast** — quick lookups, simple file edits, boilerplate generation

Standard is safe because the quality gap is small: Sonnet 4.6 scores 79.6% on SWE-Bench Verified — just 1.2 points below Opus 4.6 — at 40% lower input cost. GPT-5.4 and Sonnet 4.6 have identical output pricing ($15/M), making model selection between providers a pure quality decision.

## Provider Selection

For day-to-day work, each provider has different strengths:

| | Claude Code | Codex | Cursor |
|---|------------|-------|--------|
| **Strength** | Code reasoning (SWE-Bench) | Agentic tool use (Terminal-Bench 75.1%) | IDE integration, cheapest agentic model |
| **Budget** | 5h / 7-day rolling (generous) | 5h / 7-day rolling (generous) | ~$20-30 / month (tight) |
| **Best for** | Planning, debugging, complex reasoning | Sandboxed execution, tool-heavy tasks | Focused implementation, inline edits |
| **Default model** | sonnet | gpt-5.4-mini | auto |

**Recommended primary**: Claude Code — highest code quality benchmarks, generous rolling budget, full Spine skill and subagent support. Use Standard (sonnet) as daily driver.

**Recommended secondary**: Cursor — best for IDE-integrated editing and visual multi-file changes. Composer pool is generous for daily work but watch the monthly cap. Use for focused implementation sessions.

**Envoy / cross-provider value**: Codex — GPT's Terminal-Bench strength (75.1% vs Sonnet's ~59%) catches agentic blind spots that Claude misses. Different training produces genuinely different failure modes, making cross-provider envoy dispatch more valuable than same-family second opinions.

Heavy multi-agent sessions can exhaust Claude Code Max 5x Opus hours in 2-3 days and Cursor Pro credits in a single day. Standard-tier defaults mitigate this.

### Provider budget context

| Provider | Budget model | Default | Recommendation |
|----------|-------------|---------|----------------|
| Claude Code | 5h / 7-day rolling | sonnet | Generous budget — upgrade to opus freely for complex phases |
| Codex | 5h / 7-day rolling | gpt-5.4-mini | Generous budget — upgrade to gpt-5.4 for complex phases |
| Cursor | ~$20-30 / month | auto | Tight monthly cap — stay on auto, upgrade to composer-2 selectively |

### Cost per million tokens

| Tier | Claude | Codex | Cursor |
|------|--------|-------|--------|
| Frontier | opus ($5/$25) | gpt-5.4 ($2.50/$15) | composer-2 ($0.50/$2.50) |
| Standard | sonnet ($3/$15) | gpt-5.4-mini ($0.75/$4.50) | composer-2 ($0.50/$2.50) |
| Fast | haiku ($1/$5) | gpt-5.4-nano ($0.20/$1.25) | auto ($1.25/$6) |

> Cursor models draw from the Auto+Composer pool with a monthly allowance. Per-token cost matters less than staying within your monthly budget. Composer 2 Fast ($1.50/$7.50) offers the same quality at higher speed but 3× the cost — use selectively when latency matters. For higher quality beyond the pool, override to API-pool models (e.g., gpt-5.4) at provider pricing.

## Overrides

### Envoy Tier Overrides

Env var cascade for envoy model selection:

```
SPINE_ENVOY_{TIER}_{PROVIDER} > SPINE_ENVOY_{PROVIDER} > built-in default
```

Example: `SPINE_ENVOY_FRONTIER_CLAUDE=opus:high` overrides the frontier tier for Claude envoy calls.

### Multi-Provider Dispatch

`SPINE_ENVOY_PROVIDERS` controls which providers envoy attempts and in what order. Default: all non-self.

### Effort Levels

| Provider | Support | Levels |
|----------|---------|--------|
| Claude Code | Session-level only (ignored per-agent) | — |
| Codex | Per-role in TOML | minimal, low, medium, high, xhigh |
| Cursor | None | — |

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
| Opus 4.6 | 80.8% | — | $5 / $25 |
| Sonnet 4.6 | 79.6% | ~59% | $3 / $15 |
| Haiku 4.5 | >73% | — | $1 / $5 |

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
| Composer 1.5 | 47.9% | $3.50 / $17.50 | Composer |
| Auto | — | $1.25 / $6.00 | Auto+Composer |

## Implementation Notes

Envoy CLI dispatch uses the same tier mapping except Cursor fast: `auto` instead of `fast` (works under pool pressure).

Two mapping points encode the tier tables:

- **`install.sh`** `map_model_for_provider()` — maps tiers to provider models at install time, generating agent frontmatter for Codex TOML and Cursor `.md` files.
- **`_common.sh`** `resolve_tier()` — maps tier + provider to model at runtime for envoy CLI dispatch.

### Agent Tier Assignments

| Agent | Tier |
|-------|------|
| planner, debater, inspector, verifier | Frontier |
| analyst, researcher, navigator, framer, visualizer | Standard |
| implementer, synthesizer | Adaptive |
| scout, miner, envoy | Fast |
