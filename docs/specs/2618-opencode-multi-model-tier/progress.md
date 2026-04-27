---
spec: 2618-opencode-multi-model-tier
session_id: opencode-models-tier-frame-97c5
updated: 2026-04-27
---

# Progress — OpenCode Multi-Model Tier Re-selection

## Slice status

| Slice | Status | Notes |
|-------|--------|-------|
| 1 — Re-selection (single-model upgrades) | **complete** | committed 2026-04-27; curate applied |
| 2 — Verifier spike (concurrency check) | **complete** | PASS 4/4; ratio 1.06; default-on posture confirmed |
| 3 — Multi-model dispatch architecture | **complete** | 10 files modified; Fanout: Frontier triple (DeepSeek+MiMo+Qwen), Standard pair (Kimi+GLM), Fast N=1 |

## Updates

### 2026-04-27 — Slice 1 complete

Frontier `mimo-v2-pro`→`mimo-v2.5-pro`, Standard `minimax-m2.7`→`qwen3.6-plus`, Fast `minimax-m2.5`→`deepseek-v4-flash`. Updated: `_common.sh`, `install.sh`, `docs/model-selection.md`, `env.example`, `README.md`, memory entry. Curate U1 (evidence-conflict-resolution section → `multi-model-council-sizing.md`) and R1 (memo-drift audit → `run-curate/SKILL.md` §Gather) applied.

Handoff for slices 2+3: `.scratch/opencode-models-tier-frame-97c5/handoff-slices-2-3.md`

### 2026-04-27 — Slice 2 complete (PASS)

XDG concurrency verifier: 3 parallel `opencode run` workers with isolated `XDG_DATA_HOME`. All 4 criteria passed:
- (a) All 3 workers produced non-empty stdout (PONG)
- (b) Wall-clock ratio 1.06 (≤1.3× threshold)
- (c) No SQLITE_BUSY in any worker output
- (d) No cross-contamination (unique session IDs per worker db)

Verdict: **PASS** → Slice 3 ships parallel dispatch **DEFAULT-ON**.

Verifier script: `.scratch/opencode-models-tier-frame-97c5/verify-opencode-concurrency.sh`
Results: `.scratch/opencode-models-tier-frame-97c5/verify-concurrency-results.{md,json}`

### 2026-04-27 — Slice 3 complete

Multi-model dispatch architecture shipped with default-on posture (slice 2 PASS). Changes:

- `_common.sh` resolve_tier() → returns `{_tier_model, _tier_primary, _tier_fanout, _tier_effort}`. OpenCode Go tiers get explicit fanout; all other providers default to single-model.
- `invoke-opencode-one.sh` — new single-worker with per-process `XDG_DATA_HOME` isolation. Extracted from original `invoke-opencode.sh`.
- `invoke-opencode.sh` — rewired as orchestrator: fanout resolution, parallel dispatch, staggered startup (250ms), stderr aggregation, partial-failure handling (≥1 succeeds → round pass).
- `run.sh` — OpenCode output glob changed to `${_base}.opencode.*.md`; success semantics relaxed to ≥1 output file for OpenCode.
- `install.sh` — `map_model_for_provider()` primaries: Frontier → deepseek-v4-pro, Standard → kimi-k2.6.
- Docs: `model-selection.md` (multi-model section + tier table), `multi-model-council-sizing.md` (cross-link), `env.example` (override syntax), `README.md` (example).

Tier configuration:
- Frontier: primary=deepseek-v4-pro, fanout=[deepseek-v4-pro, mimo-v2.5-pro, qwen3.6-plus]
- Standard: primary=kimi-k2.6, fanout=[kimi-k2.6, glm-5.1]
- Fast: primary=deepseek-v4-flash, fanout=[deepseek-v4-flash] (N=1)

Spec 2618 complete.
