# Progress: Evidence fidelity (2614)

**Spec:** [spec.md](spec.md)

## Status

Reference-layer work for slices 1–3 is **done** (skills + docs). **Operator validation** (real `run-advise` / `run-review` runs) is still open.

## Checklist

- [x] Advisory: `{source_artifact_path}` wired through `run-advise` / `do-design` / refs  
- [x] Review: `review-change-evidence.md` schema, Gate A2, `inspect-*` + `scope-context`  
- [x] Shared: `use-envoy` per-phase paths + unified `[COVERAGE_GAP: envoy — …]` wording in SKILL + related refs  
- [x] Specs index: [README.md](../README.md), [AGENTS.md](../../../AGENTS.md) link  
- [ ] Run one representative advisory flow (operator)  
- [ ] Run one representative review with change-evidence file (operator)  

## Note

Envoy **CLI fallback** (`run.sh`, `fallback.sh`, `invoke-cursor.sh`, plus `docs/model-selection.md` + `env.example` fallback section) is **stashed** for follow-up: `git stash list` → look for `wip: envoy fallback chain`.
