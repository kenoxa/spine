---
name: run-polish
description: >
  Advisory code polish with parallel lenses: conventions + complexity (default),
  efficiency (performance-sensitive scope). Use after implementation or for
  standalone cleanup on recently modified code.
argument-hint: "[files or scope]"
---

Advisory-only — produces suggestions, not rewrites. Read-only — no file writes during advisory. Findings use `[S]`/`[F]` prefixes only (no `[B]` — no gate authority).

When dispatched with depth context, additional augmented `@analyst` per variance lens (cap: base 2-3 + augmented ≤ 6).

**Session**: Generate per SPINE.md; reuse across phases. When invoked from a skill with active session, inherit the calling session's ID.

**Phase Trace**: include dispatch/action count per row.

## Phases

**Reference paths** (backticked): dispatch to subagent — do NOT Read into mainthread.

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Advisory | `@analyst` (x2-3 parallel) | advisory-*.md |
| Synthesis | `@synthesizer` | polish-synthesis.md |
| Apply | `@implementer` | polish-apply.md |

### 1. Scope

Main thread — changed files from git diff or dispatch context. No transitive dependency expansion.

### 2. Advisory

**Default (2 dispatches):**
- `@analyst` → `references/advisory-conventions.md`
- `@analyst` → `references/advisory-complexity.md`

**Performance-sensitive (swap conventions for efficiency):**
- `@analyst` → `references/advisory-complexity.md`
- `@analyst` → `references/advisory-efficiency.md`

Performance-sensitive heuristic: scope includes hot-path loops, async/concurrency, N+1, or explicit perf requirements.

All 3 lenses may dispatch at `deep` depth or when change surface spans both naming-heavy and perf-sensitive code.

Each writes findings to `.scratch/<session>/polish-advisory-{lens}.md`.

### 3. Synthesis

`@synthesizer` → `references/polish-synthesis.md`

Merges advisory outputs, deduplicates, assigns E-levels. E2+ findings → action or explicit rejection with rationale. No silent drops.

### 4. Apply

`@implementer` → `references/polish-apply.md`

Applies synthesis actions. Skip entirely when no actions exist.

Output: `polish_findings`, updated `files_modified`.

## Noise Filtering

- Introduced or worsened by change? Skip pre-existing unless interacting with new code.
- Fixable in same scope? Skip if separate effort required.
- Material impact on correctness or reviewability? Skip style-only preferences.
- Consistent with project intent — deliberate tradeoffs documented in plan or spec are not defects

## Anti-Patterns

- Applying fixes or outputting complete rewritten files (present findings with snippets, not full rewrites)
- Flagging auth/authz/validation as complexity bloat
- Raising micro-optimizations without measured evidence
- Expanding scope beyond provided file list
- Surfacing pre-existing issues unrelated to current change
