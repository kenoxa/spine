# Progress: Thin Orchestrator Architecture

Spec: [spec.md](spec.md)
Session: `thin-orchestrator-ref-arch-7ff2`

## Status: spec-complete

## Migration Tracker

| Skill | Tier | Status | Notes |
|-------|------|--------|-------|
| do-plan | A | done | ~1250 token orchestrator + 12 per-role refs + 1 rename |
| do-execute | B | pending | Tests mode-specific orchestrator refs |
| do-discuss | B | pending | Most complex — tiered escalation |
| run-review | A | pending | |
| run-debug | A | pending | |
| run-recap | A | pending | |
| run-insights | A | pending | |
| run-polish | A | pending | |

## Decisions Log

| # | Decision | Door |
|---|----------|------|
| 1 | Skills → thin orchestrators | two-way |
| 2 | Per-role reference granularity | two-way |
| 3 | Agent + reference = augment | two-way |
| 4 | Synthesizer as aggregation proxy | two-way |
| 5 | Session dir as handoff medium | two-way |
| 6 | Minimal dispatch prompt (paths only) | two-way |
| 7 | Tier A (routing table) / Tier B (mode-specific refs) | two-way |
| 8 | Swarm size 3–6 | two-way |
| 9 | Lazy-load for mainthread, direct-load for subagents | two-way |
| 10 | Persist as spec (this doc) | one-way |

## Discussion Log

| Date | Skill | Status | Summary |
|------|-------|--------|---------|
| 2026-03-17 | do-plan | discussed | Frame: full per-role decomposition (14 files), envoy rename pre-req, medium-high confidence |

## Open Questions (resolved)

1. Framing phase — may stay mainthread or be dispatched; decide per-skill during planning
2. Reference size — 250–800 token soft target; >1000 tokens flagged
3. Orchestrator ref size — 1000–1500 tokens acceptable for Tier B
4. do-execute focused depth — inline instructions in orchestrator ref
5. Navigator — agent file only unless behavior diverges
6. Migration order — do-plan → do-execute → do-discuss → run-*
