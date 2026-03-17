---
name: run-polish
description: >
  Advisory code polish with parallel lenses: conventions, complexity, efficiency.
  Use after implementation or for standalone cleanup on recently modified code.
  Do NOT use during do-execute — use its built-in polish phase instead.
argument-hint: "[files or scope]"
---

Advisory-only — produces suggestions, not rewrites. Read-only — no file writes during advisory. Findings use `[S]`/`[F]` prefixes only (no `[B]` — no gate authority).

## Phases

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Advisory | `@analyst` (x3 parallel) | advisory-*.md |
| Synthesis | `@synthesizer` | polish-synthesis.md |
| Apply | `@implementer` | polish-apply.md |

### 1. Scope

Main thread — changed files from git diff or dispatch context. No transitive dependency expansion.

### 2. Advisory

Dispatch 3 `@analyst` instances in parallel:
- `conventions-advisor` (`@analyst`) → [advisory-conventions.md](references/advisory-conventions.md)
- `complexity-advisor` (`@analyst`) → [advisory-complexity.md](references/advisory-complexity.md)
- `efficiency-advisor` (`@analyst`) → [advisory-efficiency.md](references/advisory-efficiency.md)

Each writes findings to `.scratch/<session>/polish-advisory-{lens}.md`.

### 3. Synthesis

`@synthesizer` → [polish-synthesis.md](references/polish-synthesis.md)

Merges advisory outputs, deduplicates, assigns E-levels. E2+ findings → action or explicit rejection with rationale. No silent drops.

### 4. Apply

`@implementer` (`polish-apply`) → [polish-apply.md](references/polish-apply.md)

Applies synthesis actions. Skip entirely when no actions exist.

Output: `polish_findings`, updated `files_modified`.

## Noise Filtering

- Introduced or worsened by change? Skip pre-existing unless interacting with new code.
- Fixable in same scope? Skip if separate effort required.
- Material impact on correctness or reviewability? Skip style-only preferences.

## Anti-Patterns

- Applying fixes or outputting complete rewritten files (present findings with snippets, not full rewrites)
- Flagging auth/authz/validation as complexity bloat
- Raising micro-optimizations without measured evidence
- Expanding scope beyond provided file list
- Surfacing pre-existing issues unrelated to current change
