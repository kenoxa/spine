---
name: run-explore
description: >
  Bounded codebase exploration and architecture mapping.
  Use when: "explore", "how does X work", "map the flow", "survey",
  "architecture of", "what does X look like", "show me the lay of the land".
  Do NOT use for broad refactoring (do-plan) or deliberation (do-discuss).
argument-hint: "[area or question to explore]"
---

Read-only — no file writes outside `.scratch/`.

## Phases

**Reference paths** (backticked): dispatch to subagent — do NOT Read into mainthread.

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Explore | `@scout`, `@researcher`, `@navigator` | explore-*.md |
| Synthesize | `@synthesizer` | explore-synthesis.md |
| Visualize | `@visualizer` | — (optional) |

### Role Selection

| Question type | Dispatch | Reference |
|---------------|----------|-----------|
| Breadth: "where is X? what shape?" | `@scout` | `references/explore-scout.md` |
| Depth: "how does X work? call chains?" | `@researcher` | `references/explore-file-scout.md` |
| Docs: "what is X supposed to do?" | `@researcher` | `references/explore-docs.md` |
| External: "ecosystem says what about X?" | `@navigator` | `references/explore-navigator.md` |
| Alternatives: "what else could we use?" | `@navigator` | `references/explore-alternatives.md` |

### Standalone Workflow

1. **Frame** — concrete exploration question or hypothesis before searching.
2. **Dispatch** — select roles from table above based on question type. Scout always; others when depth/external/docs warrant it. Cap: ≤ 5 concurrent.
3. **Synthesize** — `@synthesizer` + `references/explore-synthesis.md` when 2+ dispatches. Pass `file_pattern` matching scratch output prefix.
4. **Visualize** — dispatch `@visualizer` if complexity warrants or user requests. Output: `.scratch/<session>/explore-recap.html`.

Session setup: generate per SPINE.md. When invoked from a skill with active session, inherit the calling session's ID.

**Phase Trace**: Log row at frame, dispatch, synthesize, visualize. Include dispatch count and question type.

## Output Format

- `key_findings` — confirmed observations with file paths
- `files_to_touch` — triage priority per file (core / related / peripheral)
- `risks_or_unknowns` — explicit gaps and unexplored areas

## Anti-Patterns

- Speculating about behavior without repository evidence
- File lists without explaining each file's role in the flow
- Proposing code edits or implementation during exploration
- Overloading output with low-value file dumps instead of triaged signal
