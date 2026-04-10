---
name: do-build
description: >
  Use when: "build", "implement", "build and review", "just build it", "do-build",
  rapid prototyping from a consult recommendation or approved plan.
  Do NOT use when problem unclear (do-frame), exploration incomplete (do-design).
argument-hint: "[plan reference, consult recommendation, or task]"
---

Automated build-review-polish loop composing run-* phase skills: scope → run-implement → run-review ↔ run-implement (fix) → run-polish → finalize.

## Entry Gate

Requires do-design recommendation or clear task with approved direction.

## Depth

Classify at entry. Controls review fanout. Default `standard`.

| Level | Heuristic | Review behavior |
|-------|-----------|----------------|
| `focused` | Single partition, 1-3 files | Inline review (no subagent batch) |
| `standard` | Default | Full run-review dispatch |

## Phases

- **Session**: reuse input session when available; log at every phase boundary.
- **Phase Trace**: finalize verifies rows for scope, implement, review, review-gate, polish, finalize.

| Phase | Mechanism | Reference |
|-------|-----------|-----------|
| Scope | mainthread | — |
| Implement | invoke `/run-implement` | — |
| Review | invoke `/run-review` | — |
| Review gate | mainthread | [build-review-gate.md](references/build-review-gate.md) |
| Polish | invoke `/run-polish` | — |
| Finalize | mainthread | [build-finalize.md](references/build-finalize.md) |

### 1. Scope

Main thread. Read plan or consult recommendation, classify depth, partition work. Output `scope_artifact`: `target_files`, `partitions`, `input_source`, `input_excerpt`, `risk_level`, `blocking_questions` (must be empty). Ask user when blocking questions non-empty.

**Doc-awareness**: when the task changes user-visible behavior, APIs, or configuration, include affected doc files (README, CHANGELOG, docs/) in `target_files`. Keep doc files in the same partition as owning code. Compose with `use-writing` skill.

**Risk classification** (advisory — user may override):
- `low` — config changes, single-module edits, no trust boundaries
- `medium` — multi-file changes, dependency updates, API surface changes
- `high` — auth/payment/migration, trust boundary changes, shared middleware

Risk level feeds run-review's risk scaling (security probe at high, testing-depth at medium).

### 2. Implement

Invoke `/run-implement` with `scope_artifact`. Returns `implement_artifact` with `files_modified`.

### 3. Review

Invoke `/run-review` scoped to `files_modified` at `scope_artifact.risk_level`. Returns findings artifact.

**Review gate**: Load [build-review-gate.md](references/build-review-gate.md). Read run-review output. Verdict: ITERATE or ACCEPT.

- **ITERATE** → invoke `/run-implement` with `fix_context` (blocking findings) → re-invoke `/run-review` → re-gate. Cap **5** iterations; freeze on cap.
- **ACCEPT** → proceed to polish.

**Stuckness advisory** — after 2 consecutive review-loop iterations where the same error signature repeats (same file + same finding category), surface an advisory to the user. Fires once per build session; informational only — does not auto-dispatch or modify caps.

Suggest agents based on failure pattern:
- Same code approach failing repeatedly → suggest `@consultant` for approach reset
- Cross-cutting issue (same finding across multiple files) → suggest `@envoy` for cross-provider second opinion
- Missing external knowledge (API, library, framework) → suggest `@navigator` for upstream research

### 4. Polish

Invoke `/run-polish` scoped to `files_modified`. Repeat until no E2+ actions remain. Cap **3** iterations.

### 5. Finalize

Main thread. Load [build-finalize.md](references/build-finalize.md) unconditionally. Sole completion authority.

## Anti-Patterns

- Bypassing run-* skills to dispatch agents directly
- Exceeding review cap (5) or polish cap (3) — freeze and surface to user
- Skipping finalize after ACCEPT
- Skipping polish after review passes
- "I'll review after all partitions are done" — bugs compound across partitions; review each
- "This fix is obvious, skip re-review" — obvious fixes break adjacent code; re-review catches regressions
- "Polish is cosmetic, ship now" — polish catches complexity and convention drift missed by review

## Completion

- Phase Trace rows exist for scope, implement, review, review-gate, polish, finalize [E3]
- All blocking review findings resolved or user-deferred [E2]
- Token counts verified for any modified skill files [E3]
