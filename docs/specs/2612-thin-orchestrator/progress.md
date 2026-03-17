# Progress: Thin Orchestrator Architecture

Spec: [spec.md](spec.md)
Session: `thin-orchestrator-ref-arch-7ff2`

## Status: spec-complete

## Migration Tracker

| Skill | Tier | Status | Notes |
|-------|------|--------|-------|
| do-plan | A | done | ~1250 token orchestrator + 12 per-role refs + 1 rename |
| do-execute | B | done | Mode-specific orchestrator refs |
| do-discuss | B | done | Tiered escalation, spec-creation mode |
| run-review | A | done | Hybrid: routing table + ~25L shared preload rules. 3 phase refs + 1 rename |
| run-debug | A | done | Workflow redesign: 4-phase subagent dispatch with loop management. 4 new refs |
| run-recap | A | done | Preamble + 3 format templates split. 4 new refs + 1 delete |
| run-insights | A | done | Source-expert + synthesizer split. 2 new refs + 1 delete |
| run-polish | A | done | Content creation: 5 new refs (advisory + synthesis + apply) |
| run-architecture-audit | A | done | Scope addition. Rename + routing table rewrite |

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

## Token Counts

Measured via `tokenizer -f <file> -m gpt-4.1` (o200k_base encoding). 2026-03-17.

### SKILL.md Files (<5000 tokens)

| File | Tokens | Status |
|------|--------|--------|
| catchup | 556 | pass |
| commit | 549 | pass |
| do-discuss | 955 | pass |
| do-execute | 1416 | pass |
| do-plan | 1269 | pass |
| handoff | 653 | pass |
| run-architecture-audit | — | pending |
| run-debug | — | pending |
| run-insights | — | pending |
| run-polish | — | pending |
| run-recap | — | pending |
| run-review | — | pending |
| use-envoy | 523 | pass |
| use-explore | 733 | pass |
| use-js | 714 | pass |
| use-shell | 395 | pass |
| use-skill-craft | 1169 | pass |
| use-writing | 473 | pass |
| with-backend | 132 | pass |
| with-frontend | 276 | pass |
| with-testing | 481 | pass |

### Agent Files (250–750 tokens)

| File | Tokens | Status |
|------|--------|--------|
| analyst | 298 | pass |
| debater | 287 | pass |
| envoy | 562 | pass |
| framer | 525 | pass |
| implementer | 462 | pass |
| inspector | 474 | pass |
| miner | 450 | pass |
| navigator | 835 | flag |
| planner | 377 | pass |
| researcher | 359 | pass |
| scout | 461 | pass |
| synthesizer | 284 | pass |
| verifier | 572 | pass |
| visualizer | 217 | pass |

### Reference Files — Role Refs (250–800 tokens, flag >1000)

| File | Tokens | Status |
|------|--------|--------|
| do-discuss/frame-dialogue-tracker | 245 | pass |
| do-discuss/frame-evidence-mapper | 248 | pass |
| do-discuss/frame-synthesis | 432 | pass |
| do-discuss/spec-mode | 379 | pass |
| do-execute/finalize | 778 | pass |
| do-execute/implement | 407 | pass |
| do-execute/polish-apply | 427 | pass |
| do-execute/polish-complexity-advisor | 383 | pass |
| do-execute/polish-conventions-advisor | 366 | pass |
| do-execute/polish-efficiency-advisor | 415 | pass |
| do-execute/polish-synthesis | 504 | pass |
| do-execute/review-correctness-reviewer | 608 | pass |
| do-execute/review-envoy | 430 | pass |
| do-execute/review-risk-reviewer | 628 | pass |
| do-execute/review-spec-reviewer | 578 | pass |
| do-execute/review-synthesis | 638 | pass |
| do-execute/validate | 486 | pass |
| do-execute/verify | 714 | pass |
| do-plan/challenge-counterpoint-dissenter | 320 | pass |
| do-plan/challenge-envoy | 318 | pass |
| do-plan/challenge-synthesis | 411 | pass |
| do-plan/challenge-thesis-champion | 329 | pass |
| do-plan/challenge-tradeoff-analyst | 355 | pass |
| do-plan/deep-modules | 445 | pass |
| do-plan/discovery-docs-explorer | 367 | pass |
| do-plan/discovery-file-scout | 351 | pass |
| do-plan/discovery-synthesis | 329 | pass |
| do-plan/planning-creative | 356 | pass |
| do-plan/planning-envoy | 345 | pass |
| do-plan/planning-rigorous | 339 | pass |
| do-plan/planning-synthesis | 363 | pass |
| do-plan/spec-mode | 653 | pass |
| do-plan/variance-lenses | 823 | flag |
| do-plan/vertical-slices | 241 | pass |
| run-architecture-audit/orchestrate-audit | 517 | pass |
| run-debug/observe-scout | — | pending |
| run-debug/pattern-researcher | — | pending |
| run-debug/hypothesis-implementer | — | pending |
| run-debug/harden-implementer | — | pending |
| run-insights/analyze-source-expert | — | pending |
| run-insights/synthesize-miner | — | pending |
| run-polish/advisory-conventions | — | pending |
| run-polish/advisory-complexity | — | pending |
| run-polish/advisory-efficiency | — | pending |
| run-polish/polish-synthesis | — | pending |
| run-polish/polish-apply | — | pending |
| run-recap/dispatch-preamble | — | pending |
| run-review/scope-context | — | pending |
| run-review/inspect-dispatch | — | pending |
| run-review/synthesize-resort | — | pending |
| run-review/template-review-brief | 344 | pass |
| use-skill-craft/examples | 531 | pass |
| use-writing/decision-template | 177 | pass |

### Reference Files — Orchestrator Refs (1000–1500 tokens)

| File | Tokens | Status |
|------|--------|--------|
| do-discuss/orchestrate-discuss | 2367 | flag |
| do-discuss/orchestrate-spec-creation | 1587 | flag |

### Reference Files — Templates (no hard threshold)

| File | Tokens |
|------|--------|
| do-discuss/template-brief | 1020 |
| do-discuss/template-spec | 630 |
| do-plan/template-plan | 826 |
| run-recap/template-standup | — |
| run-recap/template-timesheet | — |
| run-recap/template-recap | — |

### Reference Files — Flagged (>1000 tokens, non-orchestrator)

| File | Tokens | Notes |
|------|--------|-------|
| run-review/security-probe | 1002 | probe checklist |
| use-skill-craft/workflow-patterns | 829 | near threshold |

### Root Files

| File | Tokens | Threshold | Status |
|------|--------|-----------|--------|
| SPINE.md | 1764 | ~1800 | pass |
| CONTRIBUTING.md | 1869 | — | — |
