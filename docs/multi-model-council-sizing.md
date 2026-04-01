---
updated: 2026-04-01
---

# Multi-Model Council Sizing

## Default Size: 3

Six independent systems converged on 3 as the default council/review panel size: Mozilla Star Chamber, SWARM council, oh-my-openagent, Swarms framework, QwenLM/qwen-code, Zylos MoA.

**Diminishing returns**: 3rd diverse model adds ~22% unique findings; 4th adds <5% (Mozilla Star Chamber, 2026-03-05). Formal log-N scaling law (arxiv 2512.23340, Dec 2025) — saturation at 4-6 models for most tasks.

**Boundaries**: below 3 = insufficient error independence. Above 5 = synthesis quality degrades from noise (Zylos MoA, 2026-02-06).

## Selection Criterion: Diversity > Performance

Maximize information independence, not benchmark rank (arxiv 2602.08003, Feb 2026). A 3-model diverse ensemble outperforms a 5-model homogeneous high-performer panel (LLM-TOPLA, arxiv 2410.03953).

**Role specialization** beats ensemble size: 3-4 models with distinct roles (reviewer, proposer, critic) outperform larger undifferentiated sets (Heterogeneous Swarms, arxiv 2502.04510v2).

**Adversarial diversity** > cooperative diversity for coherent output — agents should have genuinely different priors (training corpora, RLHF objectives), not just different random seeds (Team of Rivals, arxiv 2601.14351v1).

## Anti-Patterns

- **Performance-ranked selection**: picking top-3 benchmark models → corpus-correlated panel, shared sycophancy failure mode
- **Too many providers** (7+): synthesis quality degrades; reviewer cannot distinguish signal from noise in 7 disagreeing opinions

## Spine Implication

Default envoy dispatches 3 providers. Tiered routing possible: single model for simple tasks, 3-model panel for review/planning, full matrix only for high-stakes architecture decisions via `SPINE_ENVOY_PROVIDERS` override.
