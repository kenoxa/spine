---
name: use-explore
description: >
  Bounded codebase exploration and architecture mapping.
  Use when discovery is needed before implementation, or when asked to explore, map, or survey a codebase area.
  Outputs to .scratch/ for downstream skill consumption.
  Do NOT use for broad refactoring — use do-plan instead.
argument-hint: "[area or question to explore]"
---

Bounded, read-only codebase exploration. No file writes, no implementation proposals — return triaged, structured findings for downstream skills.

## Workflow

**Session setup** (standalone invocation only — skip when loaded as agent preload):
Generate session ID: `{slug}-{hash}` where slug is 5-7 words from the exploration question, hash from `openssl rand -hex 2`. When invoked from a skill with an active session, inherit the calling session's ID. All scratch output paths use `.scratch/<session>/`.

1. **Frame** — concrete exploration question or hypothesis before searching.
2. **Bounded discovery** — find relevant modules, symbols, entry points. MUST complete
   within 3 refinement cycles (search → read → refine). Unanswered after 3 cycles →
   return best partial results with explicit `risks_or_unknowns`. The 3-cycle cap applies to the main exploration thread; scratch output captures findings from within the 3-cycle budget.
3. **Context triage** — label findings: `core` (must include), `related` (include if space),
   `peripheral` (mention only if risk signal). Drop peripheral from handoff by default.
4. **Map flow** — trace control flow, data flow, cross-file dependencies.
5. **Extract surface** — files to modify and expected side effects.
6. **Handoff** — present output in chat (primary user-facing deliverable). Also write structured output to `.scratch/<session>/explore-output.md` (standalone mode only). Output format includes all existing fields plus:
   - `session_id`: so downstream skills can construct the correct scratch path
   - `evidence_manifest`: file paths with why-relevant — direct input to do-plan evidence_manifest field

   Scratch write is non-blocking. If write fails: log "Scratch write failed — output available in chat only." Do not terminate. If exploration completed with partial results: write with `status: partial` and populated `risks_or_unknowns` field.
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
