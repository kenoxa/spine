---
name: do-plan
description: >
  Use when: planning, architecture decisions, multi-file changes, migration strategies,
  "think through", "map out", "figure out approach", open-ended tasks, 3+ files,
  multiple approaches. Do NOT use for single-file edits, simple bug fixes, approved plans.
argument-hint: "[task description]"
---

Produce a self-sufficient, executable plan: discovery → framing → planning → challenge → synthesis.

Unclear requirements or wide-open solution space → run `brainstorming` first; get sign-off before entering discovery.

## Phases

Every subagent prompt MUST be self-contained — include all prior-phase context.

| Phase | Agent type |
|-------|-----------|
| Discovery | `@researcher` |
| Planning | `@planner` |
| Challenge | `@debater` |

**Session ID**: Generate per SPINE.md convention. Reuse across phases; carry into do-execute. Append to session log at phase boundaries. Paths use `<session>` as placeholder.

## Variance Analysis

Run once at skill entry (before discovery). Match task description against [references/variance-lenses.md](references/variance-lenses.md) trigger keywords; select 1-2 lenses. Store as `variance_lenses`. Log selection (one sentence) in session log. Carry the same selection through all phases — do not re-select per phase.

When no lens trigger matches the task, `variance_lenses` is empty (no augmented agents dispatched). Augmented agents use the lens focus directive as persona. Output paths: `.scratch/<session>/plan-{phase}-augmented-{lens}.md`.

### 1. Discovery

Map codebase before planning. Dispatch **in parallel** (`@researcher` type):

| Role | Persona | Output | When |
|------|---------|--------|------|
| `file-scout` | Entry points, call graphs, config flags, change surface | `.scratch/<session>/plan-discovery-file-scout.md` | Always |
| `docs-explorer` | Intended behavior, spec bullets, ambiguities | `.scratch/<session>/plan-discovery-docs-explorer.md` | Always |
| `external-researcher` | Upstream breaking changes, API gotchas, version compat | `.scratch/<session>/plan-discovery-external-researcher.md` | When touching external deps |

Dispatch additional `@researcher` per `variance_lenses` entry. Cap: base + augmented ≤ 5 total.

**Synthesis**: Dispatch `@synthesizer` with input paths: all discovery output files. Output: `.scratch/<session>/plan-synthesis-discovery.md`. Read synthesis output for framing. If output empty or missing, fall back to reading individual outputs.

### 2. Framing

Distill `discovery_findings` into a shared `planning_brief`. Fields:

| Field | Content |
|-------|---------|
| `goal` | One-sentence task restatement, disambiguated by discovery |
| `scope` | Confirmed in/out with change surface |
| `constraints` | Hard limits (performance, security, backwards compat, API surface) |
| `key_decisions` | Numbered IDs, A/B/C options, explicit tradeoffs |
| `planner_focus_cues` | E2 pointers to entry points, patterns, tests — no narrative |
| `evidence_manifest` | Artifact paths with why-relevant; planners lazy-load from here |
| `docs_impact` | Classification: `customer-facing`, `internal`, `both`, or `none` — with skip rationale when `none` |

Classify `docs_impact` for every plan. `none` → record skip rationale. `customer-facing`/`both` → changelog in scope; load `use-writing`. No raw dumps — distilled signals only.

Two-Way Door test per `key_decision`:
- Reversible → fast path
- One-way (rewrites, migrations, vendor lock-in) → exhaustive analysis
- Evaluate on: correctness risk, operational complexity, team familiarity, migration cost, blast radius
- Limit to 2–3 options; never 4+ without narrowing first

Ask before dispatching planners if `key_decisions` materially change scope or risk. Present context + options; prompt with structured questions.

### 3. Planning

Dispatch **in parallel** (`@planner` type). Each receives `planning_brief` + `evidence_manifest`; independent plan from distinct angle:

| Role | Persona | Output |
|------|---------|--------|
| `conservative` | Requires codebase precedent; prefers no-change when risk is ambiguous | `.scratch/<session>/plan-planning-conservative.md` |
| `thorough` | Enumerates every edge case and failure mode; missing coverage = gap | `.scratch/<session>/plan-planning-thorough.md` |
| `innovative` | Proposes structural improvements; justifies each departure with concrete benefit | `.scratch/<session>/plan-planning-innovative.md` |

Dispatch additional `@planner` per `variance_lenses` entry. Cap: base + augmented ≤ 5 total.

**Synthesis**: Dispatch `@synthesizer` with input paths: all planning output files. Output: `.scratch/<session>/plan-synthesis-planning.md`. Read synthesis output for canonical_plan. If output empty or missing, fall back to reading individual outputs.

### 4. Challenge

Adversarial review of `canonical_plan`. Blocking findings MUST be E2+; E0-only are advisory. Never block without a better alternative (project-documented, industry-standard, or lower risk).

Review lenses: `assumptions` (approach correctness), `nfr` (security, perf, scalability). Use `visual-explainer` for architecture diagrams.

Unresolved after asking → dispatch debate **in parallel** (`@debater` type). Each receives `canonical_plan`, unresolved findings, `evidence_manifest`.

| Role | Persona | Output |
|------|---------|--------|
| `thesis-champion` | Steelmans plan strengths; rebuts objections with evidence | `.scratch/<session>/plan-challenge-thesis-champion.md` |
| `counterpoint-dissenter` | Attacks assumptions; surfaces risks; proposes alternatives | `.scratch/<session>/plan-challenge-counterpoint-dissenter.md` |
| `tradeoff-analyst` | Weighs positions; quantifies costs, reversibility, irreversible commitments | `.scratch/<session>/plan-challenge-tradeoff-analyst.md` |

Dispatch additional `@debater` per `variance_lenses` entry. Cap: base + augmented ≤ 5 total.

**Synthesis**: Dispatch `@synthesizer` with input paths: all challenge output files. Output: `.scratch/<session>/plan-synthesis-challenge.md`. Read synthesis output. If output empty or missing, fall back to reading individual outputs. Incorporate surviving E2+ findings; close resolved findings with rationale.

### 5. Synthesis

Main thread only. Sole readiness authority.

1. Assemble final plan per [references/plan-template.md](references/plan-template.md). Write to `.scratch/<session>/plan.md`.
2. Validate [Plan Requirements](#plan-requirements).
3. Confirm blocking findings incorporated or rejected with rationale.
4. Confirm no open ask-checkpoint decisions without user-deferred evidence.
5. Emit readiness decision.

`semantic` gaps (missing tests, unresolved findings, self-sufficiency failure) → re-run from framing. `non_semantic` gaps → fix inline.

## Evidence Levels

See AGENTS.md for E0–E3 definitions. Blocking claims MUST be E2+.

## Ask Policy

Ask when ambiguity materially affects scope, risk, or approach:
- After discovery, before framing: blocking unknowns that would misdirect planning
- After challenge, before synthesis: unresolved contentious findings

Never carry unresolved decisions into synthesis.

## Plan Requirements

Synthesis cannot declare readiness unless plan includes:

- **Self-sufficiency**: executable without chat history; repo-relative paths; defined terms; decision rationale
- **Test tasks**: concrete scenarios (given/when/then) for behavior-changing work; no abstract "add tests"
- **Edge/failure coverage**: enumeration (low risk); perspective table (medium/high)
- **Docs tasks**: explicit for user-visible/API/config changes; changelog when `customer-facing`/`both`
- **Completion criteria**: testable acceptance conditions. See [references/plan-template.md](references/plan-template.md) for scaffold.

## Readiness Declaration

- `Plan is ready for execution.` — STOP. Await user approval ("go", "approved", "proceed"). Declaration is not approval.
- `Plan is NOT ready for execution` — followed by gaps.

## Iteration Cap

5 iterations (framing → synthesis = one). On cap: freeze best snapshot, request approval.

## Anti-Patterns

- Silently carrying unresolved `key_decisions` past the ask checkpoint
- Re-selecting variance lenses mid-plan instead of carrying entry selection
