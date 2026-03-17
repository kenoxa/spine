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

## Spec Mode (conditional)

When a spec is detected via `@`-reference, see [references/spec-mode.md](references/spec-mode.md). Standalone mode proceeds unchanged below.

### 1. Discovery

Map codebase before planning. Dispatch **in parallel** (`@researcher` and `@navigator` types):

| Role | Persona | Output | When |
|------|---------|--------|------|
| `file-scout` | Entry points, call graphs, config flags, change surface | `.scratch/<session>/plan-discovery-file-scout.md` | Always |
| `docs-explorer` | Intended behavior, spec bullets, ambiguities | `.scratch/<session>/plan-discovery-docs-explorer.md` | Always |
| `navigator` | Upstream breaking changes, API gotchas, version compat, ecosystem alternatives | `.scratch/<session>/plan-discovery-navigator.md` | Always |

Dispatch additional `@researcher` per `variance_lenses` entry. Cap: base + augmented ≤ 5 total.

`@researcher`: local-depth first. Upstream only for concrete, plan-local questions with a
small named source set. `@navigator`: broad, ambiguous, comparative, current, or conflicting
external work.

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
| `evidence_manifest` | Artifact paths with provenance (`local-code`, `local-doc`, `researcher-upstream`, `navigator-external`), why-relevant, and conflict status; planners lazy-load from here |
| `technical_context` | Environmental constraints from brief: runtime versions, deployment targets, infrastructure facts |
| `docs_impact` | Classification: `customer-facing`, `internal`, `both`, or `none` — with skip rationale when `none` |

Classify `docs_impact` for every plan. `none` → record skip rationale. `customer-facing`/`both` → changelog in scope; load `use-writing`. No raw dumps — distilled signals only.

Two-Way Door test per `key_decision`:
- Reversible → fast path
- One-way (rewrites, migrations, vendor lock-in) → exhaustive analysis
- Evaluate on: correctness risk, operational complexity, team familiarity, migration cost, blast radius
- Limit to 2–3 options; never 4+ without narrowing first

Ask before dispatching planners when `key_decisions` change scope/risk, upstream evidence is
missing, or external conflicts remain unresolved. Present context + options.

### 3. Planning

Dispatch **in parallel** (`@planner` type). Each receives `planning_brief` + `evidence_manifest`.
Independent plan from distinct angle. Planners read manifest entries touching cited key
decisions. Preserve provenance. Surface unresolved external conflicts; never flatten them:

| Role | Persona | Output |
|------|---------|--------|
| `rigorous` | Requires codebase precedent; enumerates edge cases and failure modes; prefers no-change when risk is ambiguous; missing coverage = gap | `.scratch/<session>/plan-planning-rigorous.md` |
| `creative` | Proposes structural improvements; justifies each departure with concrete benefit | `.scratch/<session>/plan-planning-creative.md` |

#### Envoy

Load `use-envoy`. Dispatch `@envoy` concurrently with base planners with:
- Prompt content: full `planning_brief` + inlined discovery synthesis + referenced evidence (all self-contained — no local path references or agent format assumptions)
- Output format: inline the 5-section structure (angle summary, key decisions, implementation steps, risks, synthesis weights) directly in the prompt
- Output path: `.scratch/<session>/plan-planning-envoy.md`
- Variant: `standard`

Cap: base (2) + envoy (1) + augmented ≤ 6.

Dispatch additional `@planner` per `variance_lenses` entry within remaining cap.

**Synthesis**: Dispatch `@synthesizer` with input paths: all planning output files. Include `.scratch/<session>/plan-planning-envoy.md` if it exists. Output: `.scratch/<session>/plan-synthesis-planning.md`. Read synthesis output for canonical_plan. If output empty or missing, fall back to reading individual outputs. Synthesizer: use-envoy `standard` variant. No additional tail.

### 4. Challenge

Adversarial review of `canonical_plan`. Blocking findings MUST be E2+; E0-only are advisory. Never block without a better alternative (project-documented, industry-standard, or lower risk).

Review lenses: `assumptions` (approach correctness), `nfr` (security, perf, scalability).

After challenge synthesis, dispatch `@visualizer`: architecture diagram — system topology, modules, data flows, dependencies from canonical plan. Read: `.scratch/<session>/plan-synthesis-planning.md`, `.scratch/<session>/plan-synthesis-challenge.md`. Output: `.scratch/<session>/plan-challenge-diagram.html`.

Unresolved after asking → dispatch debate **in parallel** (`@debater` type). Each receives `canonical_plan`, unresolved findings, `evidence_manifest`.

| Role | Persona | Output |
|------|---------|--------|
| `thesis-champion` | Steelmans plan strengths; rebuts objections with evidence | `.scratch/<session>/plan-challenge-thesis-champion.md` |
| `counterpoint-dissenter` | Attacks assumptions; surfaces risks; proposes alternatives | `.scratch/<session>/plan-challenge-counterpoint-dissenter.md` |
| `tradeoff-analyst` | Weighs positions; quantifies costs, reversibility, irreversible commitments | `.scratch/<session>/plan-challenge-tradeoff-analyst.md` |

#### Envoy

Load `use-envoy`. Dispatch `@envoy` concurrently with base debaters:
- Prompt content: `canonical_plan` + unresolved blocking findings + inlined `evidence_manifest` (all self-contained — no local path references)
- Output format: 4-section debater-adapted structure (opening position, challenges, irreducible objections, resolution paths)
- Output path: `.scratch/<session>/plan-challenge-envoy.md`
- Variant: `debater`

Cap: base (3) + envoy (1) + augmented ≤ 6.

Dispatch additional `@debater` per `variance_lenses` entry within remaining cap.

**Synthesis**: Dispatch `@synthesizer` with input paths: all challenge output files. Include `.scratch/<session>/plan-challenge-envoy.md` if it exists and is not a skip advisory. Output: `.scratch/<session>/plan-synthesis-challenge.md`. Read synthesis output. If output empty or missing, fall back to reading individual outputs. Synthesizer: use-envoy `debater` variant. Tail: "Incorporate surviving E2+ findings; close resolved findings with rationale."

### 5. Synthesis

Main thread only. Sole readiness authority.

1. Assemble final plan per [references/plan-template.md](references/plan-template.md). Write to `.scratch/<session>/plan.md`.

**Visual plan review**: dispatch `@visualizer` if complexity warrants it or requested — plan review for `.scratch/<session>/plan.md`. Output: `.scratch/<session>/plan-review.html`. Otherwise suggest to user. Skip only if user has declined.
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

- `Plan is ready for execution.` followed by clickable relative link to `.scratch/<session>/plan.md` — STOP. Await user approval ("go", "approved", "proceed"). Declaration is not approval.
- `Plan is NOT ready for execution` — followed by gaps.

## Iteration Cap

5 iterations (framing → synthesis = one). On cap: freeze best snapshot, request approval.

## Anti-Patterns

- Silently carrying unresolved `key_decisions` past the ask checkpoint
- Re-selecting variance lenses mid-plan instead of carrying entry selection
- Same output filename for both `@visualizer` dispatches — use `plan-challenge-diagram.html` and `plan-review.html`
- Running spec detection on files not explicitly `@`-referenced by the user
