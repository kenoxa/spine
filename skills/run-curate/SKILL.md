---
name: run-curate
description: >
  Curate persistent project knowledge files in docs/.
  Use when: "curate", "curate knowledge", "promote learning", "review knowledge",
  "prune knowledge", "knowledge maintenance", "update knowledge", "knowledge hygiene",
  "manage docs knowledge", or auto-triggered from build-finalize
  when knowledge_candidate items exist.
  Do NOT use for: ephemeral session notes, code comments, commit messages.
argument-hint: "[candidates from build-finalize or standalone review scope]"
---

**Session**: Generate per SPINE.md. When auto-triggered from build-finalize, inherit calling session's ID.

**Phase Trace**: per phase-audit.md table format. Log at gather, dispatch, synthesize, present, apply. Include action counts per type.

## Phases

**Subagent references** (backticked): dispatch to subagent -- do NOT Read into mainthread.

| # | Phase | Agent | Reference |
|---|-------|-------|-----------|
| 1 | Gather | -- | -- |
| 2 | Dispatch | `@curator` + `@envoy` | `references/curate-envoy.md` |
| 3 | Synthesize | `@synthesizer` | `references/curate-synthesis.md` |
| 4 | Present | -- | -- |
| 5 | Apply (user-gated) | -- | -- |

| Phase | Base | Envoy | Cap |
|-------|------|-------|-----|
| Dispatch | 1 | 1 | 2 |

Envoy always dispatches (frontier multi-provider) — knowledge correctness warrants the cost.

### 1. Gather

Read AGENTS.md `## Project Knowledge` section and each referenced knowledge file.

**Auto mode** (build-finalize passes `knowledge_candidate: yes` items): collect candidates alongside existing entries.
**Standalone mode** (user invokes `/run-curate`): full review of existing entries. Also scan `.scratch/` for session logs that contain entries with `knowledge_candidate: yes` — collect these as additional candidates using the same shape (what_was_attempted, result, assumption_corrected, knowledge_candidate). Other workflow skills may emit candidates in their finalize phases.

**Staleness detection** (incremental): for each knowledge file declaring `paths:` frontmatter, run `git log --since=<updated_date> --name-only -- <paths>`; skip files with zero changes. Build staleness matrix (knowledge_file, last_updated, changed_neighbors, stale) and pass to `@curator`.

### 2. Dispatch

Dispatch `@curator` and `@envoy` in parallel:

**@curator** — receives:
- `candidates` -- learnings with evidence anchors (auto mode) or collected from session scans (standalone)
- `existing_entries` -- parsed entries with file contents
- `staleness_matrix` -- from Gather phase

Output: `.scratch/<session>/curate-plan.md`

**@envoy** — coverage gap discovery per `references/curate-envoy.md`. Base output path: `.scratch/<session>/curate-envoy.md` (run.sh writes per-provider files `curate-envoy.<provider>.md`). Advisory only — curator retains sole promote/update/prune authority.

Await both before proceeding.

### 3. Synthesize

Dispatch `@synthesizer` via `references/curate-synthesis.md` to merge curator plan + envoy per-provider outputs. Output: `.scratch/<session>/curate-synthesis.md`.

### 4. Present

Read `.scratch/<session>/curate-synthesis.md`.

Present grouped by action type (promote / update / prune). Show token budget impact. When staleness matrix has stale entries, highlight them. Include envoy GAP/WATCH items labeled `[ADVISORY: envoy]`.

Require explicit user approval before proceeding -- never auto-apply.

### 5. Apply

Gate: user approval received. On approval, mainthread applies changes:
- **Promote**: create/update `docs/<name>.md` with telegraphic content + `updated:` frontmatter. Requires E2+ evidence anchor.
- **Update**: edit existing knowledge files in-place
- **Prune**: remove files + AGENTS.md entries
- **Index**: update AGENTS.md `## Project Knowledge` with backticked paths + glosses

Skip actions the user explicitly declines. Report final state.

## Anti-Patterns

- Promoting E0/E1-only learnings without evidence anchor
- Creating knowledge files for content derivable from code or git history
- Exceeding AGENTS.md token budget
- Promoting skill/agent operational details to docs/ knowledge files (belongs in skill/agent files)
- Treating envoy GAP/WATCH items as promotable without E2+ evidence
- Running staleness detection against all knowledge files regardless of changed neighbors (full-corpus sweep)
