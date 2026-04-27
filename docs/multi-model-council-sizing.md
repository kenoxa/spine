---
updated: 2026-04-27
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

### Evidence Conflict Resolution

When external doc research (E1) conflicts with executable observation (E3 — CLI probe,
in-repo test, live behavioral output), E3 wins. Document the conflict; trust observation.

Concrete instance (spec 2618-opencode-multi-model-tier, slice 1, 2026-04-27):
navigator (@navigator) cited opencode.ai/docs/it/go/ claiming April 2026 Go roster
excluded Kimi K2.6, MiMo-V2.5-Pro, DeepSeek V4 Pro/Flash. envoy-codex E3 probe
(`opencode models opencode-go` on local v1.14.26) returned the full April lineup.
User screenshot of the official Go page corroborated envoy-codex. Resolution: E3 +
direct observation override E1 external docs.

**Pattern**: vendor docs lag live product state — especially true for fast-moving LLM
model rosters. Preflight: re-run the live probe at build time; lock picks against
that output, not against docs/external research.

Constraint 6 in advise-synthesis.md distills this: "Re-selection picks MUST be locked
against a live `opencode models opencode-go` probe at build time, not against external
docs." [E3: `.scratch/opencode-models-tier-frame-97c5/advise-synthesis.md` §Constraint 6
+ §CONFLICT — Go roster availability]

## Anti-Patterns

- **Performance-ranked selection**: picking top-3 benchmark models → corpus-correlated panel, shared sycophancy failure mode
- **Too many providers** (7+): synthesis quality degrades; reviewer cannot distinguish signal from noise in 7 disagreeing opinions

## Spine Implication

Default envoy dispatches 3 providers. Tiered routing possible: single model for simple tasks, 3-model panel for review/planning, full matrix only for high-stakes architecture decisions via `SPINE_ENVOY_PROVIDERS` override.

## OpenCode Intra-Provider Multi-Model

Within OpenCode envoy dispatch, each tier fans out to multiple models (Frontier: 3, Standard: 2, Fast: 1) with per-process `XDG_DATA_HOME` isolation. See [model-selection.md](model-selection.md) §OpenCode Multi-Model Dispatch for fanout composition. Concurrency verified: slice 2 of spec 2618, 4/4 criteria PASS (2026-04-27).
