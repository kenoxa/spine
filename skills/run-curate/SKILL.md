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

**Phase Trace**: per phase-audit.md table format. Log at gather, dispatch, present, apply. Include action counts per type.

## Phases

**Subagent references** (backticked): dispatch to subagent -- do NOT Read into mainthread.

| # | Phase | Type | Agent | Reference |
|---|-------|------|-------|-----------|
| 1 | Gather | mainthread | -- | -- |
| 2 | Dispatch | C (1 agent) | `@curator` | -- |
| 3 | Present | mainthread | -- | -- |
| 4 | Apply | G -> mainthread | -- | -- |

### 1. Gather

Read AGENTS.md `## Project Knowledge` section and each referenced knowledge file.

**Auto mode** (build-finalize passes `knowledge_candidate: yes` items): collect candidates alongside existing entries.
**Standalone mode** (user invokes `/run-curate`): full review of existing entries, no candidates.

### 2. Dispatch @curator

Dispatch `@curator` with:
- `candidates` -- learnings with evidence anchors (auto mode) or empty (standalone)
- `existing_entries` -- parsed entries with file contents

Output: `.scratch/<session>/curate-plan.md`

### 3. Present

Read `.scratch/<session>/curate-plan.md` and present grouped by action type (promote / update / prune). Show token budget impact. Require explicit user approval before proceeding -- never auto-apply.

### 4. Apply

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
