---
name: do-execute
description: >
  Use when: "plan is approved", "go ahead", "proceed", "let's build this",
  confirmed implementation start, clear explicit tasks without planning needed.
  Do NOT use when planning incomplete or still exploring — run do-plan first.
argument-hint: "[plan reference or task]"
---

Seven phases: scope → implement → validate → polish → review → verify → finalize.

## Entry Gate

No approved plan → run do-plan first. Never edit the plan file for status tracking.

**"Approved" = explicit user confirmation after `Plan is ready for execution.` — not the declaration itself. If unconfirmed, stop and ask.**

## Depth

Classify at entry. Controls fanout, not which phases run — all seven always execute. Default to `standard`.

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
| Implement | `@implementer` | `references/implement.md` |
| Validate | `@inspector` | `references/validate.md` |
| Polish | `@analyst` | `run-polish/references/advisory-*.md`, `references/polish-apply.md` |
| Review | `@inspector`, `@envoy` | `references/review-*.md` |
| Verify | `@verifier` | `references/verify.md` |
| Finalize | mainthread | [finalize.md](references/finalize.md) |

| Phase | Base | Envoy | Max Augmented (f/s/d) | Cap |
|-------|------|-------|-----------------------|-----|
| Polish | 3 | 0 | 0 / 2 / 3 | 6 |
| Review | 3 | 1 | 0 / 1 / 2 | 6 |
Invariant: sum every row ≤ 6.

### 1. Scope

Main thread. Read plan, classify depth, partition work. Output `scope_artifact`: `target_files`, `partitions`, `blocking_questions` (must be empty), `plan_excerpt`. Ask user when blocking questions non-empty.

### 2. Implement
`@implementer` → `references/implement.md`: one per partition. Parallel for independent; sequential for dependent. Output: `files_modified`.

### 3. Validate
`@inspector` → `references/validate.md`. PASS → polish. BLOCK → re-enter implement. 2 consecutive BLOCKs → escalate.

### 4. Polish

1. **Advisory**: `@analyst` in parallel:
   - `conventions-advisor` → `run-polish/references/advisory-conventions.md`
   - `complexity-advisor` → `run-polish/references/advisory-complexity.md`
   - `efficiency-advisor` → `run-polish/references/advisory-efficiency.md`
   - +augmented per variance lens
2. **Synthesis**: `@synthesizer` → `run-polish/references/polish-synthesis.md`
3. **Apply**: `@implementer` → `references/polish-apply.md`. Skip when no actions.

### 5. Review

1. **Tests & docs**: skip when no behavior-changing code AND `docs_impact` = `none`. Otherwise: tests (E3), docs per impact. Missing = blocking.
2. **Adversarial**: `@inspector` in parallel:
   - `spec-reviewer` → `references/review-spec-reviewer.md`
   - `correctness-reviewer` → `references/review-correctness-reviewer.md`
   - `risk-reviewer` → `references/review-risk-reviewer.md`
   - `envoy` (`@envoy`) → `references/review-envoy.md` (via `use-envoy`, tier: frontier, mode: multi)
   - +augmented per variance lens
3. **Synthesis**: `@synthesizer` → `references/review-synthesis.md`. Blocking (E2+) → re-enter polish. Advisory → proceed.

### 6. Verify
`@verifier` → `references/verify.md`. Output: PASS, FAIL, or PARTIAL with `failure_class`.

### 7. Finalize
Main thread. Load [finalize.md](references/finalize.md) unconditionally. Sole completion authority.

## Re-entry

- **Validate BLOCK** → implement with `validation_brief`
- **Blocking review** → polish (`@implementer` → `references/review-fix.md` applies fixes)
- **Verify semantic** → polish → review → verify
- **Verify non-semantic** → `@implementer` → `references/review-fix.md` → re-verify only
Re-entry brief: blocker, what was attempted, what changed. Shared counter, cap **5**, freeze on cap.

## Completion

Cannot declare `Implementation complete.` unless:
- **Tests** for behavior-changing work — E3 required
- **Edge/failure coverage** for risk-bearing work
- **Docs** when `docs_impact` ≠ `none` — changelog when `customer-facing` or `both`

Otherwise: `Implementation NOT complete` — followed by specific gaps.

## Anti-Patterns

- Advisory analyst writing to codebase files (scratch only)
- Blocking on E2- verifier output (advisory, not gate)
- Overlapping concurrent writes to same file
- Skipping tests-and-docs without checking `docs_impact`
- Updating spec status without user confirmation
