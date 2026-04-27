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
| 2 — Verifier spike (concurrency check) | not started | — |
| 3 — Multi-model dispatch architecture | not started | gates on slice 2 verifier pass |

## Updates

### 2026-04-27 — Slice 1 complete

Frontier `mimo-v2-pro`→`mimo-v2.5-pro`, Standard `minimax-m2.7`→`qwen3.6-plus`, Fast `minimax-m2.5`→`deepseek-v4-flash`. Updated: `_common.sh`, `install.sh`, `docs/model-selection.md`, `env.example`, `README.md`, memory entry. Curate U1 (evidence-conflict-resolution section → `multi-model-council-sizing.md`) and R1 (memo-drift audit → `run-curate/SKILL.md` §Gather) applied.

Handoff for slices 2+3: `.scratch/opencode-models-tier-frame-97c5/handoff-slices-2-3.md`
