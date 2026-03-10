---
name: do-execute
description: >
  Use when: "plan is approved", "go ahead", "proceed", "let's build this",
  confirmed implementation start, clear explicit tasks without planning needed.
  Do NOT use when planning incomplete or still exploring — run do-plan first.
argument-hint: "[plan reference or task]"
---

Six phases: scope → implement → polish → review → verify → finalize.

## Entry Gate

No approved plan → run do-plan first. Never begin with incomplete planning. Never edit the plan file for status tracking.

**"Approved" = explicit user confirmation after `Plan is ready for execution.` — not the declaration itself. If unconfirmed, stop and ask.** See do-plan Readiness Declaration.

## Depth

Classify at entry. Controls fanout, not which phases run — all six always execute.

| Level | Behavior |
|-------|----------|
| `focused` | Main thread handles all phases inline — no subagent dispatch |
| `standard` | Subagent dispatch per phase |
| `deep` | Subagent dispatch per phase with expanded fanout |

## Evidence Levels

See AGENTS.md for E0–E3 definitions. Blocking claims MUST be E2+. Verify claims MUST be E3.

## Phases

**Session ID**: Reuse plan's session ID when executing an approved do-plan; otherwise generate per SPINE.md convention. Append to session log at each phase boundary and on re-entry. All output paths use `<session>` as placeholder.

At `focused` depth, main thread handles all phases inline — no dispatch. Roles below apply to `standard` and `deep` only. Every subagent prompt MUST be self-contained: include scope artifact, files modified, plan excerpt.

| Phase | Agent type | Rationale |
|-------|-----------|-----------|
| Implement | `@worker` | Read-write; edits source per partition |
| Polish | `@analyst` | Advisory-only; `[S]`/`[F]` prefixes, no gate authority |
| Review | `@inspector` | Verdict-focused; `[B]`/`[S]`/`[F]` severity, spec compliance |
| Verify | `@verifier` | Adversarial; runs commands, read-only for source |

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

### 2. Implement

Dispatch `@worker` type (`implement` mode): one per partition. Parallel for independent; sequential for dependent. No overlapping file writes.

Output: `files_modified` — repo-relative list of all changed files.

One logical change per dispatch. Unrelated issues → follow-up tasks, not inline fixes.

Worker self-review: completeness, naming clarity, YAGNI, tests verify behavior not mocks.

### 3. Polish

Two sub-steps:

1. **Advisory pass**: dispatch analysts **in parallel** (`@analyst` type):

   | Role | Persona | Output |
   |------|---------|--------|
   | `conventions-advisor` | Naming vs codebase norms; flags pattern deviations, not style preferences | `.scratch/<session>/execute-polish-conventions-advisor.md` |
   | `complexity-advisor` | Defensive bloat on trusted paths (NEVER flag auth/authz/validation); premature abstraction | `.scratch/<session>/execute-polish-complexity-advisor.md` |
   | `efficiency-advisor` | Reuse opportunities, N+1, missed concurrency, hot-path bloat | `.scratch/<session>/execute-polish-efficiency-advisor.md` |

   **Synthesis**: deduplicate findings, assign E-levels. Every E2+ finding → action or explicit rejection. Silent drops prohibited.

2. **Apply**: workers (`@worker` type, `polish-apply` mode) apply synthesis actions from the advisory pass. Apply sub-step skipped when no actions exist.

Output: `polish_findings`, updated `files_modified`.

### 4. Review

Two stages, sequential:

1. **Tests & docs** (conditional): skip when no behavior-changing code AND `docs_impact` is `none`.
   Otherwise:
   - **Tests**: run suites covering changed behavior; add missing coverage; produce E3 evidence. Absent test evidence for behavior-changing code = **blocking finding**.
   - **Docs**: update per `docs_impact`. `customer-facing` or `both` → changelog via `use-writing` rules. Missing docs when `docs_impact` ≠ `none` = **blocking finding**.
   Output feeds stage 2.
2. **Adversarial review**: dispatch `@inspector` type **in parallel**. Never skipped. At `focused` depth, single inline pass with all three lenses.

   | Role | Persona | Output |
   |------|---------|--------|
   | `spec-reviewer` | Plan requirement ↔ implementation coverage; flags missing and extra behavior | `.scratch/<session>/execute-review-spec-reviewer.md` |
   | `correctness-reviewer` | Logic errors, edge cases, race conditions, failure paths; assumes adversarial inputs | `.scratch/<session>/execute-review-correctness-reviewer.md` |
   | `risk-reviewer` | Security boundaries, performance, scalability; depth scales by risk | `.scratch/<session>/execute-review-risk-reviewer.md` |

   **Synthesis**: deduplicate findings across reviewers. Assign final E-levels and severity per `do-review` rules.

Blocking (E2+) → `re_dispatch_brief` → re-enter polish. Advisory → record, proceed to verify.

Output: `review_findings` with E-levels per finding.

### 5. Verify

Dispatch `@verifier` type. Single instance (all depths). Receives `files_modified`, `review_findings`, plan excerpt. All claims MUST be E3. E2- claims are advisory — never block on them.

Output: `verification_result` — PASS, FAIL, or PARTIAL with specifics.

### 6. Finalize

Main thread only. Sole completion authority.

1. Check content gates (see [Content Gates](#content-gates)).
2. Learnings as proposals only — never auto-apply. User must approve any rule/skill/memory update.
3. Declare completion.

## Re-entry

```
Scope → Implement → Polish → Review → Verify → Finalize
                      ↑         |
                      └─────────┘  blocking review findings
                      ↑
                      └──── verify semantic failure
```

- **Blocking review findings** → re-enter polish (advisory re-runs, `@worker` `review-fix` mode applies fixes)
- **Verify semantic failure** (behavior/spec) → polish → review → verify
- **Verify non-semantic failure** (lint, types, build) → `@worker` `review-fix` fix → re-verify only

Each polish re-entry = one iteration. Cap: **5**. On cap: freeze best state, ask user to continue.

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

- Skipping phases regardless of depth
- Advisory analyst writing to codebase files during polish (scratch writes are expected)
- Silently dropping E2+ polish findings without action or explicit rejection
- Blocking completion on E2- verifier output
- Making inline main-thread edits when not at focused depth
- Overlapping concurrent writes to the same file
- Auto-applying learnings in finalize
- Skipping tests-and-docs stage without verifying `docs_impact` classification
- Declaring completion without test evidence (E3) for behavior-changing code
