---
name: use-explore
description: >
  Bounded codebase exploration and architecture mapping.
  Use when discovery is needed before implementation.
  Do NOT use for broad refactoring — use do-plan instead.
argument-hint: "[area or question to explore]"
---

Bounded, read-only codebase exploration. No file writes, no implementation proposals — return triaged, structured findings for downstream skills.

## Workflow

1. **Frame** — concrete exploration question or hypothesis before searching.
2. **Bounded discovery** — find relevant modules, symbols, entry points. MUST complete
   within 3 refinement cycles (search → read → refine). Unanswered after 3 cycles →
   return best partial results with explicit `risks_or_unknowns`.
3. **Context triage** — label findings: `core` (must include), `related` (include if space),
   `peripheral` (mention only if risk signal). Drop peripheral from handoff by default.
4. **Map flow** — trace control flow, data flow, cross-file dependencies.
5. **Extract surface** — files to modify and expected side effects.
6. **Handoff** — concise structured output (see below).
7. **Visual recap** — dispatch `@visualizer` subagent if complexity warrants it or requested: project recap — explored architecture, key findings, module map. Exploration question: <from Step 1>. Key findings: <from Step 6>. Output: `.scratch/<session>/project-recap.html`. Otherwise suggest to user. Skip only if user has declined.

Discover project-specific terminology and naming conventions in cycle 1. Use discovered
terms in subsequent searches instead of generic names.

## Output Format

- `key_findings` — confirmed observations with file paths
- `files_to_touch` — triage priority per file (core / related / peripheral)
- `risks_or_unknowns` — explicit gaps and unexplored areas
- `terminology_discovered` — non-obvious project naming (omit when not applicable)

## Anti-Patterns

- Speculating about behavior without repository evidence
- File lists without explaining each file's role in the flow
- Assuming behavior from file names alone without verifying call sites
- Proposing code edits or implementation during exploration
- Overloading output with low-value file dumps instead of triaged signal
