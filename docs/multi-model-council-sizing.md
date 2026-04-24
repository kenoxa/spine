---
updated: 2026-04-24
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

### Verifier's E3 Role: Executed Tests vs Static Review

Static reviewers (inspector, envoy) identify risk areas but do not execute tests.
The verifier agent's mandate — "run commands and observe output" — is load-bearing
for catching fixture-level regressions.

Slice C instance: inspector [S3] correctly flagged "no unit tests for new helpers"
as a risk; codex and opencode envoys did not flag the regression. Verifier ran
`bats` → 45/45 → 1/45; regression ONLY surfaced via E3 probe. Fix confirmed in
iter-2 (45/45 restored).

**Implication:** dispatch a verifier agent with real test execution on any change
that touches shared helpers or test fixtures. Static coverage alone produces
false-clear verdicts on these surfaces.

[E3: `.scratch/slice-c-intra-task-loop-32e7/review-verifier.md §Probe A`;
`review-synthesis.md §B1`; `review-verifier-iter2.md` VERDICT PASS;
commit `4cea877`]

*Prior art: c-CRAB (2026) converts review feedback into executable oracles;
CodeX-Verify shows +39.7pp accuracy when agents differ by detection method
(ρ ≈ 0.05–0.25). Differentiate by method (static vs execution), not by model
provider — same-method duplicates add zero coverage.* `[ADVISORY: envoy]`

## Anti-Patterns

- **Performance-ranked selection**: picking top-3 benchmark models → corpus-correlated panel, shared sycophancy failure mode
- **Too many providers** (7+): synthesis quality degrades; reviewer cannot distinguish signal from noise in 7 disagreeing opinions

## Spine Implication

Default envoy dispatches 3 providers. Tiered routing possible: single model for simple tasks, 3-model panel for review/planning, full matrix only for high-stakes architecture decisions via `SPINE_ENVOY_PROVIDERS` override.
