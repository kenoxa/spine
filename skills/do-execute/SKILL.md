---
name: do-execute
description: >
  Execute an approved plan through structured phases with built-in quality gates.
  Use when an approved plan exists or the task is explicit enough to skip planning.
  Do NOT use when planning is incomplete — run do-plan first.
argument-hint: "[plan reference or task]"
---

Execute an approved plan through six phases: scope → implement → polish → review → verify → finalize.

## Entry Gate

No approved plan in context → run do-plan first. Never begin execution when planning is incomplete. Never edit the plan file for status tracking.

**"Approved" means explicit user confirmation after the readiness declaration — not the readiness declaration itself. If the user has not confirmed since the last `Plan is ready for execution.` statement, stop and ask.**

## Depth

Classify at entry. Depth controls fanout per phase, not which phases run — all six always execute.

| Level | Behavior |
|-------|----------|
| `focused` | Main thread handles all phases inline — no subagent dispatch |
| `standard` | Subagent dispatch per phase |
| `deep` | Subagent dispatch per phase with expanded fanout |

## Evidence Levels

See AGENTS.md for E0–E3 definitions. Blocking claims MUST be E2+. Verify claims MUST be E3.

## Phases

At `focused` depth, main thread handles every phase inline — no subagent dispatch. The subagent roles below apply to `standard` and `deep` only. Every subagent prompt MUST be self-contained: include scope artifact, files modified, and plan excerpt. Subagents inherit no conversation history.

### 1. Scope

Main thread only (all depths). Read the approved plan, classify depth, partition the work.

Output `scope_artifact`:

| Field | Content |
|-------|---------|
| `target_files` | Repo-relative paths for all files in scope |
| `partitions` | Independent vs dependent groupings; colocated files stay together |
| `blocking_questions` | Must be empty before dispatching implement |
| `plan_excerpt` | Compact plan extract for worker consumption |

Ask the user when blocking questions are non-empty. Never carry unresolved questions into implement.

### 2. Implement

Implementation workers: one per partition. Parallel for independent partitions; sequential for dependent. No overlapping writes to the same file.

Output: `files_modified` — repo-relative list of all changed files.

One logical change per worker dispatch. Capture unrelated issues as follow-up tasks, not inline fixes.

Worker self-review before reporting: completeness, naming clarity, YAGNI discipline, tests verify behavior not mocks.

### 3. Polish

Two sub-steps:

1. **Advisory pass** (read-only): reviewers read modified files and produce findings with E-levels. They do NOT write files. Focus on convention mismatches, defensive bloat on trusted paths (but NEVER flag auth/authz/validation), and unnecessary complexity.
2. **Apply**: workers apply synthesis actions from the advisory pass.

Main thread MUST acknowledge every E2+ finding: action or explicit rejection with rationale. Silent drops prohibited. Apply sub-step skipped when no actions exist.

Output: `polish_findings`, updated `files_modified`.

### 4. Review

Two stages, sequential:

1. **Tests & docs** (conditional): skip when no behavior-changing code AND `docs_impact` is `none`.
   Otherwise:
   - **Tests**: run test suites covering changed behavior; add missing coverage; produce test evidence (command executed + pass/fail + coverage data). Absent test evidence for behavior-changing code is a **blocking finding**.
   - **Docs**: update documentation per `docs_impact` classification. When `customer-facing` or `both`, include changelog entries using `use-writing` skill rules. Absent docs updates when `docs_impact` ≠ `none` is a **blocking finding**.
   Their output is context for stage 2.
2. **Adversarial review**: independent reviewers with distinct lenses, dispatched in parallel. Never skipped. At `focused` depth, run as a single inline pass with multiple lenses rather than dispatching separate reviewers.

Blocking findings (E2+) → produce `re_dispatch_brief` → re-enter polish.
Advisory findings → record; proceed to verify.

Output: `review_findings` with E-levels per finding.

### 5. Verify

Single verifier instance (all depths). All verifier claims MUST be E3 (executed command + observed output). E2- claims are advisory only — never block completion on them.

Output: `verification_result` — pass or fail with specifics.

### 6. Finalize

Main thread only. Sole completion authority.

1. Check content gates (see [Content Gates](#content-gates)).
2. Produce learnings as proposals only — never auto-apply. User must explicitly approve any rule, skill, or memory update.
3. Declare completion.

## Re-entry

```
Scope → Implement → Polish → Review → Verify → Finalize
                      ↑         |
                      └─────────┘  blocking review findings
                      ↑
                      └──── verify semantic failure
```

- **Blocking review findings** → re-enter polish (advisory re-runs, workers apply fixes).
- **Verify semantic failure** (behavior/spec) → re-enter polish → review → verify.
- **Verify non-semantic failure** (lint, types, build) → workers fix → re-verify only. No full loop re-entry.

Each re-entry at polish counts as one iteration. Cap: **5 iterations**. On cap: freeze best state and ask the user for approval to continue.

## Content Gates

Finalize cannot declare completion unless:

- **Tests** for behavior-changing work — with E3 evidence (executed command + pass/fail output)
- **Edge/failure coverage** for risk-bearing work
- **Docs** for user-visible, API, or config changes (`docs_impact` ≠ `none`) — including changelog entries when `docs_impact` is `customer-facing` or `both`

## Completion Declaration

Exact phrases:

- `Implementation complete.`
- `Implementation NOT complete` — followed by specific gaps listed.

## Anti-Patterns

- Skipping phases regardless of depth
- Advisory reviewer writing files during polish
- Silently dropping E2+ polish findings without action or explicit rejection
- Blocking completion on E2- verifier output
- Making inline main-thread edits when not at focused depth
- Overlapping concurrent writes to the same file
- Auto-applying learnings in finalize
- Skipping tests-and-docs stage without verifying `docs_impact` classification
- Declaring completion without test evidence (E3) for behavior-changing code
