---
name: run-architecture-audit
description: >
  Architecture audit: explore codebase friction, identify shallow modules and coupling,
  classify dependencies, and propose deepening candidates.
  Use when: "architecture audit", "find shallow modules", "module depth", "reduce coupling",
  "tighten interfaces", "dependency analysis", "deep modules", "architecture review",
  "refactoring candidates", "what should I deepen".
  Do NOT use during active implementation (use do-build), for code review (use run-review),
  or for planning (use do-design with architecture-depth lens).
argument-hint: "[scope: directory, module, or 'full codebase']"
---

Read-only audit — no file writes, no code changes.

Cross-reference: `references/deep-modules.md` for depth heuristics, dependency categories, Design It Twice.

## Phases

**Reference convention**: linked refs load into mainthread. Backticked paths → dispatch to subagent, do NOT Read into mainthread.

**Phase Trace**: Log row at scope, explore (or zero-dispatch for focused), analyze, synthesize. Include scope classification and candidate count.

All phases: [orchestrate-audit.md](references/orchestrate-audit.md).

| Phase | Agent | Reference |
|-------|-------|-----------|
| Scope | `@scout` | `run-explore/references/explore-scout.md` |
| Explore | `@scout` | `references/audit-scout.md` |
| Analyze | `@researcher` | `references/analyze-researcher.md` |
| Synthesize | `@synthesizer` | `references/audit-synthesis.md` |

## Candidate Format

Per candidate:
- **Module path** — repo-relative directory or file
- **Coupling indicators** — export count, caller count, pass-through functions
- **Dependency category** — in-process / local-substitutable / remote-but-owned / true-external
- **Depth assessment** — shallow/medium/deep with depth ratio estimate
- **Test impact** — current test strategy vs recommended boundary

## Output Format

Write `architecture-findings.md` to `.scratch/<session>/`:

1. **Summary** — scope audited, candidate count, top friction areas (2-3 sentences)
2. **Candidate table** — module | depth | dependency category | priority
3. **Per-candidate analysis** — coupling indicators, depth assessment, test impact, deepening approach
4. **Next step** — suggest `/do-frame` for spec creation (large scope) or `/do-design` with `architecture-depth` lens (focused scope)

## Anti-Patterns

- Proposing code changes (audit diagnoses; do-design/do-build prescribes)
- Auditing test quality in isolation (use run-review for that)
- Skipping dependency classification (every candidate needs a category)
- Conflating shallow modules with small modules (small + deep = fine)
