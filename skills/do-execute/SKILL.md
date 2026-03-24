---
name: do-execute
description: >
  Use when: "plan is approved", "go ahead", "proceed", "let's build this",
  confirmed implementation start, clear explicit tasks without planning needed.
  Do NOT use when planning incomplete or still exploring — run do-plan first.
argument-hint: "[plan reference or task]"
---

Four phases: scope → implement → quality → finalize.

## Entry Gate

No approved plan → run do-plan first. Never edit the plan file for status tracking.

**"Approved" = explicit user confirmation after `Plan is ready for execution.` — not the declaration itself. If unconfirmed, stop and ask.**

## Depth

Classify at entry. Controls fanout, not which phases run — all four always execute. Default to `standard`.

| Level | Heuristic | Behavior |
|-------|-----------|----------|
| `focused` | Single partition, 1–3 files | Inline; subagent permitted but not typical |
| `standard` | Default | Subagent dispatch per phase |
| `deep` | High-risk, large surface, 3+ lenses | Expanded fanout: up to 3 augmented per phase |

## Phases

- **Evidence**: E0 intuition · E1 doc ref · E2 code ref · E3 command+output. Blocking = E2+. Verify = E3.
- **Session**: Reuse plan's session ID; otherwise per SPINE.md. Log at every phase boundary.
- **Phase Trace**: All phases log rows; finalize verifies row count before content gates.
- **Variance**: inherit from plan when available; else select 1-2 from `do-plan/references/variance-lenses.md`.
- Dispatch at `standard`/`deep`; at `focused`, run inline. Prompts MUST be self-contained.

**Reference convention**: linked refs load into mainthread. Backticked paths → dispatch to subagent, do NOT Read into mainthread.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Scope | mainthread | — |
| Implement | `@implementer` | `references/implement.md` |
| Quality | `@analyst`, `@inspector`, `@verifier`, `@envoy` | see quality section |
| Quality synthesis | `@synthesizer` | `references/quality-synthesis.md` |
| Finalize | mainthread | [finalize.md](references/finalize.md) |

| Depth | Analysts | Inspector | Verifier | Envoy | Total (batch) | Then Synthesizer |
|-------|----------|-----------|----------|-------|---------------|------------------|
| focused | 0 | 0 | 0 | 0 | 0 (inline) | — |
| standard | 2 | 1 | 1 | 1 | 5 | +1 sequential |
| deep | 2 | 1 | 1 | 1 | 5 + 1 augmented | +1 sequential |
Invariant: batch ≤ 6.

### 1. Scope

Main thread. Read plan, classify depth, partition work. Output `scope_artifact`: `target_files`, `partitions`, `blocking_questions` (must be empty), `plan_excerpt`. Ask user when blocking questions non-empty.

### 2. Implement
`@implementer` → `references/implement.md`: one per partition. Parallel for independent; sequential for dependent. Output: `files_modified`.

### 3. Quality

Single parallel batch, then sequential synthesis.

1. **Batch**: in parallel:
   - `conventions-advisor` (`@analyst`) → `run-polish/references/advisory-conventions.md`
   - `complexity-advisor` (`@analyst`) → `run-polish/references/advisory-complexity.md`
   - `risk-reviewer` (`@inspector`) → `references/quality-risk-reviewer.md`
   - `verifier` (`@verifier`) → `references/quality-verifier.md`
   - `envoy` (`@envoy`) → `references/quality-envoy.md` (via `use-envoy`)
   - +augmented per variance lens

Analyst selection: 2 of 3 advisory lenses (conventions, complexity, efficiency) based on change type. Default: conventions + complexity. Performance-sensitive: swap conventions for efficiency.

2. **Synthesis**: `@synthesizer` → `references/quality-synthesis.md`. Gate: mainthread reads synthesis, PASS/BLOCK.

**Tests & docs**: skip when no behavior-changing code AND `docs_impact` = `none`. Otherwise: tests (E3), docs per impact. Missing = blocking.

### 4. Finalize
Main thread. Load [finalize.md](references/finalize.md) unconditionally. Sole completion authority.

## Re-entry

- **Quality BLOCK (semantic)** → implement with `quality_brief` → re-run quality (full)
- **Quality BLOCK (non-semantic)** → `@implementer` + `references/quality-fix.md` → re-run quality (inspector + verifier + envoy only, skip analysts)
Re-entry brief: blocker, what was attempted, what changed. Shared counter, cap **5**, freeze on cap.

## Completion

Cannot declare `Implementation complete.` unless:
- **Tests** for behavior-changing work — E3 required
- **Edge/failure coverage** for risk-bearing work
- **Docs** when `docs_impact` ≠ `none` — changelog when `customer-facing` or `both`

Otherwise: `Implementation NOT complete` — followed by specific gaps.

## Anti-Patterns

- Advisory analyst writing to codebase files (scratch only)
- Treating E2- findings as blocking (E2+ required for all blocking findings)
- Overlapping concurrent writes to same file
- Skipping tests-and-docs without checking `docs_impact`
- Updating spec status without user confirmation
