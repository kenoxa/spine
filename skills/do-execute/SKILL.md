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
- **Variance**: inherit from plan when available; else select 1-2 from [variance-lenses.md](../do-plan/references/variance-lenses.md).
- Dispatch at `standard`/`deep`; at `focused`, run inline. Prompts MUST be self-contained.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Implement | `@implementer` | [implement.md](references/implement.md) |
| Validate | `@inspector` | [validate.md](references/validate.md) |
| Polish | `@analyst` | [polish-*.md](references/) |
| Review | `@inspector` | [review-*.md](references/) |
| Verify | `@verifier` | [verify.md](references/verify.md) |
| Finalize | mainthread | [finalize.md](references/finalize.md) |

| Phase | Base | Envoy | Max Augmented (f/s/d) | Cap |
|-------|------|-------|-----------------------|-----|
| Polish | 3 | 0 | 0 / 2 / 3 | 6 |
| Review | 3 | 1 | 0 / 1 / 2 | 6 |
Invariant: sum every row ≤ 6.

### 1. Scope

Main thread. Read plan, classify depth, partition work. Output `scope_artifact`: `target_files`, `partitions`, `blocking_questions` (must be empty), `plan_excerpt`. Ask user when blocking questions non-empty.

### 2. Implement
`@implementer` → [implement.md](references/implement.md): one per partition. Parallel for independent; sequential for dependent. Output: `files_modified`.

### 3. Validate
`@inspector` → [validate.md](references/validate.md). PASS → polish. BLOCK → re-enter implement. 2 consecutive BLOCKs → escalate.

### 4. Polish

1. **Advisory**: `@analyst` in parallel:
   - `conventions-advisor` → [polish-conventions-advisor.md](references/polish-conventions-advisor.md)
   - `complexity-advisor` → [polish-complexity-advisor.md](references/polish-complexity-advisor.md)
   - `efficiency-advisor` → [polish-efficiency-advisor.md](references/polish-efficiency-advisor.md)
   - +augmented per variance lens
2. **Synthesis**: `@synthesizer` → [polish-synthesis.md](references/polish-synthesis.md)
3. **Apply**: `@implementer` (`polish-apply`) → [polish-apply.md](references/polish-apply.md). Skip when no actions.

### 5. Review

1. **Tests & docs**: skip when no behavior-changing code AND `docs_impact` = `none`. Otherwise: tests (E3), docs per impact. Missing = blocking.
2. **Adversarial**: `@inspector` in parallel:
   - `spec-reviewer` → [review-spec-reviewer.md](references/review-spec-reviewer.md)
   - `correctness-reviewer` → [review-correctness-reviewer.md](references/review-correctness-reviewer.md)
   - `risk-reviewer` → [review-risk-reviewer.md](references/review-risk-reviewer.md)
   - +augmented per variance lens
3. **Envoy** (standard/deep): `@envoy` → [review-envoy.md](references/review-envoy.md) concurrent with inspectors.
4. **Synthesis**: `@synthesizer` → [review-synthesis.md](references/review-synthesis.md). Blocking (E2+) → re-enter polish. Advisory → proceed.

### 6. Verify
`@verifier` → [verify.md](references/verify.md). Output: PASS, FAIL, or PARTIAL with `failure_class`.

### 7. Finalize
Main thread. Load [finalize.md](references/finalize.md) unconditionally. Sole completion authority.

## Re-entry

- **Validate BLOCK** → implement with `validation_brief`
- **Blocking review** → polish (`@implementer` `review-fix` applies fixes)
- **Verify semantic** → polish → review → verify
- **Verify non-semantic** → `@implementer` `review-fix` → re-verify only
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
