---
name: do-polish
description: >
  Advisory code polish with parallel analysis lenses for conventions, complexity, and efficiency.
  Use after implementation to surface improvement suggestions before formal review.
  Also use for standalone cleanup passes on recently modified code.
  Do NOT use during do-execute — use its built-in polish phase instead.
argument-hint: "[files or scope]"
---

Advisory-only code analysis producing improvement suggestions. Polish is read-only — no file
writes, no test execution. Findings use `[S]`/`[F]` prefixes (no `[B]` — polish has no gate
authority).

## Workflow

1. **Scope** — identify changed files from git diff or dispatch context. Do not expand to transitive dependencies.
2. **Advisory pass** — dispatch three `@analyst` instances in parallel:
   - `conventions-advisor` — naming against codebase norms, pattern deviations from established project conventions
   - `complexity-advisor` — defensive bloat on trusted paths (NEVER flag auth/authz/validation), premature abstraction
   - `efficiency-advisor` — reuse opportunities, N+1 patterns, missed concurrency, hot-path bloat, resource leaks
3. **Synthesis** — deduplicate findings across lenses, assign E-levels. Every E2+ finding: action or explicit rejection with rationale. Silent drops prohibited.
4. **Apply** — workers (`@worker` type, `polish-apply` mode) apply synthesis actions. Skip when no actions exist.

Output: `polish_findings`, updated `files_modified`.

## Noise Filtering

Before surfacing a finding:
- Introduced or worsened by the change? Skip pre-existing issues unless they interact with new code.
- Would the author fix this in the same scope? Skip if fix requires separate effort.
- Materiality: skip style preferences without correctness or reviewability impact.

## Lens Details

### Reuse (conventions-advisor)

- Search for existing project utilities before flagging missing functionality
- Flag duplicate functionality across modules
- Check for reimplemented standard library or framework primitives
- Do NOT suggest third-party packages as replacements
- Do NOT flag intentional specializations (optimized paths, domain-specific variants)

### Quality (complexity-advisor)

- Redundant state (derived values stored separately from source of truth)
- Parameter sprawl (growing parameter lists without grouping)
- Copy-paste code (3+ similar blocks that should be unified)
- Leaky abstractions (implementation details exposed through interface)
- Stringly-typed values where enums/constants/types exist in the codebase
- Do NOT flag style preferences (formatting, quote style, trailing commas)

### Efficiency (efficiency-advisor)

- Redundant computations (same expensive operation called multiple times with same inputs)
- Repeated I/O (file reads, network calls for same resource within same lifecycle)
- N+1 query patterns (loop issuing individual queries instead of batch)
- Missed concurrency (independent async operations awaited sequentially)
- Hot-path bloat (debug logging, excessive validation on high-frequency paths)
- TOCTOU race conditions (check-then-act without atomicity)
- Memory leaks (event listeners not cleaned up, growing caches without eviction)
- Overly broad operations (SELECT * when 2 columns needed, full object fetch for ID check)
- Do NOT flag micro-optimizations (loop unrolling, bit manipulation vs arithmetic)

## Anti-Patterns

- Applying fixes directly (polish is advisory only)
- Flagging auth/authz/validation as complexity bloat
- Raising micro-optimizations without measured evidence
- Expanding scope beyond provided file list
- Surfacing pre-existing issues unrelated to current change
