---
name: do-polish
description: >
  Advisory code polish with parallel lenses: conventions, complexity, efficiency.
  Use after implementation or for standalone cleanup on recently modified code.
  Do NOT use during do-execute — use its built-in polish phase instead.
argument-hint: "[files or scope]"
---

Advisory-only — produces suggestions, not rewrites. Read-only — no file writes, no test execution. Findings use `[S]`/`[F]` prefixes (no `[B]` — no gate authority).

## Workflow

1. **Scope** — changed files from git diff or dispatch context. No transitive dependency expansion.
2. **Advisory pass** — three `@analyst` instances in parallel:
   - `conventions-advisor` — naming norms, pattern deviations from project conventions
   - `complexity-advisor` — defensive bloat on trusted paths (NEVER flag auth/authz/validation), premature abstraction
   - `efficiency-advisor` — reuse opportunities, N+1, missed concurrency, hot-path bloat, resource leaks
3. **Synthesis** — deduplicate across lenses, assign E-levels. E2+ findings: action or explicit rejection with rationale. No silent drops.
4. **Apply** — workers (`@worker` type, `polish-apply` mode) apply synthesis actions. Skip when none exist.

Output: `polish_findings`, updated `files_modified`.

## Noise Filtering

- Introduced or worsened by change? Skip pre-existing unless interacting with new code.
- Fixable in same scope? Skip if separate effort required.
- Material impact on correctness or reviewability? Skip style-only preferences.

## Lens Details

### Reuse (conventions-advisor)
- Search existing utilities before flagging missing functionality
- Flag cross-module duplicates, reimplemented stdlib/framework primitives
- NOT third-party package suggestions, NOT intentional specializations

### Quality (complexity-advisor)
- Redundant state, parameter sprawl, copy-paste (3+ blocks)
- Leaky abstractions, stringly-typed values where enums/types exist
- NOT style preferences (formatting, quotes, commas)

### Efficiency (efficiency-advisor)
- Redundant computations, repeated I/O within same lifecycle
- N+1 queries, missed concurrency, hot-path bloat
- TOCTOU races, memory leaks, overly broad operations
- NOT micro-optimizations (loop unrolling, bit tricks)

## Anti-Patterns

- Applying fixes or outputting complete rewritten files (present findings with snippets, not full rewrites)
- Flagging auth/authz/validation as complexity bloat
- Raising micro-optimizations without measured evidence
- Expanding scope beyond provided file list
- Surfacing pre-existing issues unrelated to current change
