# Progress: Thin Orchestrator Architecture

Spec: [spec.md](spec.md)
Session: `thin-orchestrator-ref-arch-7ff2`

## Status: spec-complete

## Migration Tracker

| Skill | Tier | Status | Notes |
|-------|------|--------|-------|
| do-plan | A | done | ~1250 token orchestrator + 12 per-role refs + 1 rename |
| do-execute | B | done | Mode-specific orchestrator refs |
| do-discuss | B | done | Phase-ref decomposition: orchestrate-discuss.md → 5 dispatch-*.md + SKILL.md absorbs orchestrator. Modes eliminated (normal/deep-interview merged). `dispatch-{phase}.md` is local naming — not repo-wide standard. |
| run-review | A | done | Hybrid: routing table + ~25L shared preload rules. 3 phase refs + 1 rename |
| run-debug | A | done | Workflow redesign: 4-phase subagent dispatch with loop management. 4 new refs |
| run-recap | A | done | Preamble + 3 format templates split. 4 new refs + 1 delete |
| run-insights | A | done | Source-expert + synthesizer split. 2 new refs + 1 delete |
| run-polish | A | done | Content creation: 5 new refs (advisory + synthesis + apply) |
| run-architecture-audit | A | done | Scope addition. Rename + routing table rewrite |

## Agent Mode Extraction

Terminal phase. Removed `## Mode Routing` / `## Thoroughness` from 9 agents; created 12 new reference files; stripped 7 description-field mode enumerations and 2 body-text mode references; fixed 16 drift phrases; updated 10+ orchestrator dispatch sites.

| Agent | Pre | Post | New Refs | Notes |
|-------|-----|------|----------|-------|
| analyst | 298 | 168 | 0 | Below 250 floor — all role behavior in refs |
| miner | 450 | 133 | 0 | Below 250 floor — all role behavior in refs |
| framer | 525 | 397 | 4 | explore-{stakeholder-advocate,systems-thinker,skeptic,augmented-framer} |
| implementer | 462 | 314 | 1 | review-fix.md |
| scout | 461 | 368 | 2 | orient-scout.md, audit-scout.md |
| navigator | 835 | 687 | 3 | navigator-{synthesis,alternatives}.md, discovery-navigator.md |
| researcher | 359 | 341 | 2 | investigate-researcher.md, analyze-researcher.md |
| debater | 287 | 269 | 0 | Refs pre-existed (challenge-*.md); description + body cleaned |
| planner | 377 | 382 | 0 | Refs pre-existed (planning-*.md); description + body cleaned |

Enforcement gate met: no agent file contains mode enumeration; every dispatch names a reference path. Synthesizer excluded (phase contexts, not behavioral modes). Behavioral validation deferred (structural gates only). Pre-existing: analyst (168) and miner (133) below 250-token floor; synthesizer `shared` in run-architecture-audit.

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
| do-discuss | 1276 | pass |
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
| analyst | 170 | flag |
| debater | 287 | pass |
| envoy | 562 | pass |
| framer | 394 | pass |
| implementer | 336 | pass |
| inspector | 474 | pass |
| miner | 149 | flag |
| navigator | 687 | pass |
| planner | 377 | pass |
| researcher | 359 | pass |
| scout | 368 | pass |
| synthesizer | 284 | pass |
| verifier | 572 | pass |
| visualizer | 217 | pass |

### Reference Files — Role Refs (250–800 tokens, flag >1000)

| File | Tokens | Status |
|------|--------|--------|
| do-discuss/dispatch-clarify | 444 | pass (phase ref — local `dispatch-{phase}.md` convention) |
| do-discuss/dispatch-explore | 459 | pass (phase ref) |
| do-discuss/dispatch-frame | 298 | pass (phase ref) |
| do-discuss/dispatch-investigate | 380 | pass (phase ref) |
| do-discuss/dispatch-orient | 659 | pass (phase ref) |
| do-discuss/frame-dialogue-tracker | 245 | pass |
| do-discuss/frame-evidence-mapper | 248 | pass |
| do-discuss/frame-synthesis | 432 | pass |
| do-discuss/spec-mode | 379 | pass |
| do-execute/finalize | 778 | pass |
| do-execute/implement | 407 | pass |
| do-execute/polish-apply | 427 | pass |
| do-execute/review-correctness-reviewer | 608 | pass |
| do-execute/review-envoy | 430 | pass |
| do-execute/review-risk-reviewer | 628 | pass |
| do-execute/review-spec-reviewer | 578 | pass |
| do-execute/review-synthesis | 613 | pass |
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
| run-polish/advisory-conventions | 372 | pass |
| run-polish/advisory-complexity | 398 | pass |
| run-polish/advisory-efficiency | 398 | pass |
| run-polish/polish-synthesis | 422 | pass |
| run-polish/polish-apply | 316 | pass |
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
| do-discuss/orchestrate-discuss | — | deleted (decomposed into 5 dispatch-*.md phase refs) |
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
