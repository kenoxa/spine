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

No approved plan → run do-plan first. Never begin with incomplete planning. Never edit the plan file for status tracking.

**"Approved" = explicit user confirmation after `Plan is ready for execution.` — not the declaration itself. If unconfirmed, stop and ask.** See do-plan Readiness Declaration.

## Depth

Classify at entry based on plan shape. Controls fanout, not which phases run — all seven always execute. When ambiguous, default to `standard`.

| Level | Heuristic | Behavior |
|-------|-----------|----------|
| `focused` | Single partition, 1–3 files, no cross-cutting concerns | inline; subagent dispatch permitted but not typical |
| `standard` | Default — scope or ambiguity exceeds focused signals | Subagent dispatch per phase |
| `deep` | High-risk, large surface, or 3+ variance lenses triggered | Subagent dispatch per phase with expanded fanout: up to 3 augmented agents per dispatch table from variance analysis |

Escalate from `focused` to `standard` when inline cost would exceed dispatch cost.

## Evidence Levels

See AGENTS.md for E0–E3 definitions. Blocking claims MUST be E2+. Verify claims MUST be E3.

## Phases

**Session ID**: Reuse plan's session ID when executing an approved do-plan; otherwise generate per SPINE.md convention. Append to session log at each phase boundary and on re-entry. All output paths use `<session>` as placeholder.

Dispatch roles below apply at `standard` and `deep` depth; at `focused` depth, run phases inline. Every subagent prompt MUST be self-contained: include scope artifact, files modified, plan excerpt.

| Phase | Agent type |
|-------|-----------|
| Implement | `@worker` |
| Validate | `@inspector` |
| Polish | `@analyst` |
| Review | `@inspector` |
| Verify | `@verifier` |

### 1. Scope

Main thread only (all depths). Read plan, classify depth, partition work.

Output `scope_artifact`:

| Field | Content |
|-------|---------|
| `target_files` | Repo-relative paths for all files in scope |
| `partitions` | Independent vs dependent groupings; colocated files stay together |
| `blocking_questions` | Must be empty before dispatching implement |
| `plan_excerpt` | Compact plan extract for worker consumption |

Ask user when blocking questions non-empty. Never carry unresolved questions into implement.

At `standard`/`deep` depth: inherit `variance_lenses` from approved plan when available. Otherwise, select from `do-plan/references/variance-lenses.md` based on `scope_artifact`: 1-2 at standard, 2-3 at deep. `focused` depth: skip.

### 2. Implement

Dispatch `@worker` type (`implement` mode): one per partition. Parallel for independent; sequential for dependent. No overlapping file writes.

Output: `files_modified` — repo-relative list of all changed files. One logical change per dispatch; unrelated issues → follow-up tasks.

### 3. Validate

Structural integrity check — do changed files parse, do imports resolve, do expected exports/functions exist per plan.

Dispatch: single `@inspector` (validate mode). Receives `files_modified`, `scope_artifact`, plan excerpt. Output: `.scratch/<session>/execute-validate.md`. At `focused` depth: typically inline pass.

Output: `validation_result` — PASS (proceed to polish) or BLOCK with specific structural findings. BLOCK → re-enter implement with `validation_brief`. After 2 consecutive BLOCKs, escalate to user.

### 4. Polish

1. **Advisory pass**: dispatch analysts **in parallel** (`@analyst` type):

   | Role | Persona | Output |
   |------|---------|--------|
   | `conventions-advisor` | Naming vs codebase norms; flags pattern deviations, not style preferences | `.scratch/<session>/execute-polish-conventions-advisor.md` |
   | `complexity-advisor` | Defensive bloat on trusted paths (NEVER flag auth/authz/validation); premature abstraction | `.scratch/<session>/execute-polish-complexity-advisor.md` |
   | `efficiency-advisor` | Reuse opportunities, N+1, missed concurrency, hot-path bloat | `.scratch/<session>/execute-polish-efficiency-advisor.md` |

   Dispatch additional `@analyst` per variance lens. Output: `.scratch/<session>/execute-polish-augmented-{lens}.md`. Standard: 1-2. Deep: 2-3. Cap: 6 total.

   **Synthesis**: Dispatch `@synthesizer` with input paths: all polish advisory output files. Output: `.scratch/<session>/execute-synthesis-polish.md`. Read synthesis output for apply step. If output empty or missing, fall back to reading individual outputs. Every E2+ finding → action or explicit rejection. Silent drops prohibited.

2. **Apply**: workers (`@worker` type, `polish-apply` mode) apply synthesis actions from the advisory pass. Apply sub-step skipped when no actions exist.

Output: `polish_findings`, updated `files_modified`.

### 5. Review

1. **Tests & docs** (conditional): skip when no behavior-changing code AND `docs_impact` is `none`.
   Otherwise:
   - **Tests**: run suites covering changed behavior; add missing coverage; produce E3 evidence. Absent test evidence for behavior-changing code = **blocking finding**.
   - **Docs**: update per `docs_impact`. `customer-facing` or `both` → changelog via `use-writing` rules. Missing docs when `docs_impact` ≠ `none` = **blocking finding**.
   Output feeds stage 2.
2. **Adversarial review**: dispatch `@inspector` type **in parallel**. Never skipped. At `focused` depth, single pass covering all three lenses (spec, correctness, risk) — typically inline.

   | Role | Persona | Output |
   |------|---------|--------|
   | `spec-reviewer` | Plan requirement ↔ implementation coverage; flags missing and extra behavior | `.scratch/<session>/execute-review-spec-reviewer.md` |
   | `correctness-reviewer` | Logic errors, edge cases, race conditions, failure paths; assumes adversarial inputs | `.scratch/<session>/execute-review-correctness-reviewer.md` |
   | `risk-reviewer` | Security boundaries, performance, scalability; depth scales by risk | `.scratch/<session>/execute-review-risk-reviewer.md` |

   Dispatch additional `@inspector` per variance lens. Output: `.scratch/<session>/execute-review-augmented-{lens}.md`. Standard: 1-2. Deep: 2-3. Cap: 6 total.

   **Synthesis**: Dispatch `@synthesizer` with input paths: all review output files. Output: `.scratch/<session>/execute-synthesis-review.md`. Read synthesis output for review_findings. If output empty or missing, fall back to reading individual outputs. Assign final E-levels and severity per `run-review` rules.

Blocking (E2+) → `re_dispatch_brief` → re-enter polish. Advisory → record, proceed to verify.

Output: `review_findings` with E-levels per finding.

### 6. Verify

Dispatch `@verifier` type. Single instance (all depths). Receives `files_modified`, `review_findings`, plan excerpt. All claims MUST be E3. E2- claims are advisory — never block on them.

Output: `verification_result` — PASS, FAIL, or PARTIAL with specifics.

### 7. Finalize

Main thread only. Sole completion authority.

1. Check content gates (see [Content Gates](#content-gates)).
2. Learnings as proposals only — never auto-apply. User must approve any rule/skill/memory update.
3. Declare completion.

## Re-entry

```
Scope → Implement → Validate → Polish → Review → Verify → Finalize
              ↑          |        ↑         |
              └──────────┘        └─────────┘  blocking review findings
                                  ↑
                                  └──── verify semantic failure
```

- **Validate BLOCK** → re-enter implement with `validation_brief`
- **Blocking review findings** → re-enter polish (advisory re-runs, `@worker` `review-fix` mode applies fixes)
- **Verify semantic failure** (behavior/spec) → polish → review → verify
- **Verify non-semantic failure** (lint, types, build) → `@worker` `review-fix` fix → re-verify only

Validate and polish re-entries share one iteration counter. Cap: **5**. On cap: freeze best state, ask user to continue.

## Content Gates

Cannot declare completion unless:

- **Tests** for behavior-changing work — E3 evidence required
- **Edge/failure coverage** for risk-bearing work
- **Docs** for user-visible/API/config changes (`docs_impact` ≠ `none`) — changelog when `customer-facing` or `both`

## Completion Declaration

Exact phrases:

- `Implementation complete.`
- `Implementation NOT complete` — followed by specific gaps listed.

## Anti-Patterns

- Advisory analyst writing to codebase files during polish (scratch only)
- Blocking completion on E2- verifier output (advisory, not gate)
- Overlapping concurrent writes to the same file
- Skipping tests-and-docs stage without verifying `docs_impact` classification
