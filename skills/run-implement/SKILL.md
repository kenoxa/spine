---
name: run-implement
description: >
  Scoped code implementation with partition-parallel dispatch.
  Use when: "implement this", "make these changes", "code this up",
  "run-implement", standalone implementation tasks.
  Do NOT use when: full build-review loop needed (do-build).
argument-hint: "[task, direction, or scope to implement]"
---

Standalone (user task) or embedded (`scope_artifact` from caller).

**Session**: per SPINE.md; inherit when embedded. **Phase Trace**: per phase-audit.md table format; log at scope, dispatch, report.

## Phases

Backticked refs: dispatch to subagent — do NOT Read into mainthread.

| # | Phase | Type | Agent | Reference |
|---|-------|------|-------|-----------|
| 1 | Scope | mainthread | — | — |
| 2 | Implement | R (1-N per partition) | `@implementer` | `references/implement-dispatch.md` |
| — | Fix | G → C (1 per fix_context) | `@implementer` | `references/implement-fix.md` |
| 3 | Report | mainthread | — | — |

### 1. Scope

Accept task or `scope_artifact`. Create partitions (no overlapping writes). Standalone: clarify ambiguous scope. Embedded: use provided scope directly. Exit: partitions defined with non-overlapping file sets.

### 2. Implement

`@implementer` per partition via `references/implement-dispatch.md`. Parallel when independent, sequential when dependent. Accumulate `files_modified` across dispatches.

### 3. Report

Aggregate `files_modified`. Exit: `implement_artifact` emitted with `files_modified`, `summary`, `session_id`.

### Fix Mode

**Gate**: invoked with `fix_context` from caller. Dispatch via `references/implement-fix.md`. Scope unchanged; replaces implement phase.

## Anti-Patterns

- Running tests or builds (implementation only)
- Expanding scope beyond partition_scope
- Fix mode without fix_context
- "I'll also fix this adjacent issue while I'm here" — scope expansion is the top cause of review churn
- "This partition depends on the other, I'll do both" — overlapping writes break parallel dispatch; sequence instead
