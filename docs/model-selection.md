# Model Selection

> Canonical reference for model tiers, provider mappings, and agent assignments. Cited by `install.sh` (install-time) and `_common.sh` (runtime) — both encode overlapping knowledge from different entry points.

## Tier Taxonomy

| Tier | Purpose | Agents |
|------|---------|--------|
| Frontier | Complex reasoning, architectural decisions, gate authority | planner, debater, inspector, verifier |
| Standard | Pattern matching, advisory, research, visualization | analyst, researcher, navigator, framer, visualizer |
| Adaptive | Tracks session quality — code generation, aggregation | implementer, synthesizer |
| Fast | Reconnaissance, data extraction, lightweight dispatch | scout, miner, envoy |

## Provider Mapping

| Tier | Claude alias | Claude Code | Codex TOML | Cursor subagent | Cursor CLI (envoy) |
|------|-------------|-------------|------------|-----------------|-------------------|
| Frontier | `opus` | opus (native) | gpt-5.4 | gpt-5.4-high | gpt-5.4-high |
| Standard | `sonnet` | sonnet (native) | gpt-5.4-mini | composer-2 | composer-2 |
| Fast | `haiku` | haiku (native) | gpt-5.4-nano | fast | auto |
| Adaptive | `inherit` | inherit | (omit) | inherit | -- |

`install.sh` maps at install-time (`map_model_for_provider`). `_common.sh` maps at runtime (`resolve_tier`).

## Effort Asymmetry

| Provider | Effort support | Levels |
|----------|---------------|--------|
| Claude Code | Session-level only (ignored per-agent) | -- |
| Codex | Per-role in TOML | minimal, low, medium, high, xhigh |
| Cursor | None | -- |

## Agent Assignments

| Agent | Tier | Model | Effort |
|-------|------|-------|--------|
| planner | Frontier | opus | high |
| debater | Frontier | opus | high |
| inspector | Frontier | opus | high |
| verifier | Frontier | opus | high |
| analyst | Standard | sonnet | high |
| researcher | Standard | sonnet | high |
| navigator | Standard | sonnet | high |
| framer | Standard | sonnet | high |
| visualizer | Standard | sonnet | high |
| scout | Fast | haiku | medium |
| miner | Fast | haiku | medium |
| envoy | Fast | haiku | medium |
| implementer | Adaptive | inherit | high |
| synthesizer | Adaptive | inherit | high |

**Adaptive agents**: `inherit` tracks session model. Implementer respects the user's quality/cost choice. Synthesizer quality is proportional to its inputs.

## Envoy Tier Overrides

The `--tier` dispatch parameter selects `frontier`, `standard`, or `fast`. Env var cascade:

```
SPINE_ENVOY_{TIER}_{PROVIDER} > SPINE_ENVOY_{PROVIDER} > built-in default
```

Example: `SPINE_ENVOY_FRONTIER_CLAUDE=opus:high` overrides the frontier tier for Claude envoy calls. See [`env.example`](../env.example) for the full template.

**Rollback**: env var changes take effect immediately (runtime). `install.sh` changes require re-running the installer to regenerate TOML/Cursor files.

## Mainthread Model Recommendations

| Phase | Recommended | Rationale |
|-------|-------------|-----------|
| discuss | opus | Socratic depth, ambiguity resolution |
| plan | opus | Cascading architectural decisions |
| execute | opus (sonnet acceptable) | Code quality; sonnet adequate for focused partitions |
| debug | opus | Root-cause reasoning chains |
| review | sonnet | Pattern matching; structured output |

## When to Upgrade Models

- Monitor provider deprecation announcements
- Test on representative tasks (SWE-Bench, Terminal-Bench equivalents) before switching
- Pin versions in env vars during migration windows

## Cursor Limitations

- Legacy plans without Max Mode ignore subagent model config
- No effort support
- Nested subagent bug: L2 dispatch falls back to composer

## Benchmarks Reference

> SWE-Bench Verified (Anthropic) and SWE-Bench Pro (OpenAI) are **different benchmarks** — not directly comparable. Verified uses a curated subset; Pro uses harder, contamination-resistant tasks.

**Claude models** (SWE-Bench Verified):

| Model | SWE-Bench Verified | Terminal-Bench | Pricing (in/out per M) |
|-------|-------------------|----------------|----------------------|
| Claude Opus 4.6 | 80.8% | — | $5 / $25 |
| Claude Sonnet 4.6 | 79.6% | ~59% | $3 / $15 |
| Claude Haiku 4.5 | >73% | — | $1 / $5 |

**GPT models** (SWE-Bench Pro):

| Model | SWE-Bench Pro | Terminal-Bench | Toolathlon | Pricing (in/out per M) |
|-------|--------------|----------------|------------|----------------------|
| GPT-5.4 | 57.7% | 75.1% | 54.6% | $2.50 / $10 |
| GPT-5.4 mini | 54.4% | 60.0% | 42.9% | $0.75 / $3 |
| GPT-5.4 nano | 52.4% | 46.3%† | 35.5% | $0.20 / $1.25 |
| GPT-5.3 Codex | ~80%‡ | 77.3% | — | $1.75 / $7 |

† screenshot-only, not independently verified · ‡ SWE-Bench Verified (not Pro)

**Cursor models**:

> Cursor has two usage pools, each with its own monthly allowance. **Auto+Composer pool**: more included usage, covers Auto and all Composer models. **API pool**: models like GPT-5.4 and Claude, charged at the provider's API price. Both pools reset monthly.

| Model | Terminal-Bench | Pricing (in/out per M) | Notes |
|-------|----------------|----------------------|-------|
| Composer 2 | 61.7% | $0.50 / $2.50 | Composer pool; Standard tier default |
| Composer 2 Fast | 61.7% | $1.50 / $7.50 | Composer pool; same quality, higher speed |
| Composer 1.5 | 47.9% | $3.50 / $17.50 | Composer pool; legacy |
| Auto | — | $1.25 / $6.00 | Routing mode — Auto+Composer pool |
