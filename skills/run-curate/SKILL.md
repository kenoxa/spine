---
name: run-curate
description: >-
  Curate project knowledge files.
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

**Memo-drift audit** (standalone mode only): for each `.claude/.../memory/project_*.md` file whose `description` references mutable state (model picks, tier mappings, dependency versions, infrastructure defaults), run `git log --since=<memo_updated> --oneline -- <referenced_code_paths>` to check whether code moved on. Surface drifted memos as follow_up items in the curate plan — do NOT auto-update memory files; the user owns memory content.

**Glossary discovery** (optional): check for `UBIQUITOUS_LANGUAGE.md` at project root. If present, extract a lightweight term list (term + aliases if available). If absent, record `[GLOSSARY_SKIP: not found]` in session trace and continue — do not suggest creating one.

**Structural lint** (standalone mode only): run the no-run-cycles lint at `references/lint-no-run-cycles.sh` (contract documented in `references/lint-no-run-cycles.md`). Surface any violations as `blocking` findings in the curate plan — do NOT promote knowledge or proceed to Dispatch until violations are resolved. Zero violations = continue.

### 2. Dispatch

Dispatch `@curator` and `@envoy` in parallel:

**@curator** — receives:
- `candidates` -- learnings with evidence anchors (auto mode) or collected from session scans (standalone)
- `existing_entries` -- parsed entries with file contents
- `staleness_matrix` -- from Gather phase
- `glossary_terms` -- lightweight term extract from Gather (omit when glossary absent)

Output: `.scratch/<session>/curate-plan.md`

**@envoy** — coverage gap discovery per `references/curate-envoy.md`. Base output path: `.scratch/<session>/curate-envoy.md` (run.sh writes per-provider files `curate-envoy.<provider>.md`). Advisory only — curator retains sole promote/update/prune authority.

Await both before proceeding.

### 3. Synthesize

Dispatch `@synthesizer` via `references/curate-synthesis.md` to merge curator plan + envoy per-provider outputs. Output: `.scratch/<session>/curate-synthesis.md`.

### 4. Present

Read `.scratch/<session>/curate-synthesis.md`.

Present grouped by action type (promote / update / prune). Show token budget impact. When staleness matrix has stale entries, highlight them. Include envoy GAP/WATCH items labeled `[ADVISORY: envoy]`. Include glossary findings labeled `[ADVISORY: glossary]` — these carry E1 ceiling and cannot gate promotion.

Require explicit user approval before proceeding -- never auto-apply.

### 5. Apply

Gate: user approval received. On approval, mainthread applies changes:
- **Promote**: create/update `docs/<name>.md` with telegraphic content + `updated:` frontmatter. Requires E2+ evidence anchor.
- **Update**: edit existing knowledge files in-place
- **Prune**: remove files + AGENTS.md entries
- **Index**: update AGENTS.md `## Project Knowledge` with backticked paths + glosses

Skip actions the user explicitly declines. Report final state.

## Terminal Mode (`--terminal`)

When invoked as `/run-curate --terminal --session=<id>` by the build phase
discipline (see `skills/use-goal-prompt/references/phase-discipline-build.md`,
"Phase-Boundary Emission" step), this skill runs in **read-only terminal-gate
mode**. It does NOT execute the standard Gather → Dispatch → Synthesize →
Present → Apply pipeline.

Terminal-mode contract:

1. Invoke `sh scripts/terminal-gate.sh .scratch/<session>` — the driver writes
   a structured `curate-report.md` skeleton (source-artifact inventory,
   decisions extracted from Phase Trace rows, knowledge-candidate markers).
2. If mainthread has budget (≤60s per spec §5.3), append an AI-synthesized
   "Learnings" section to the report below the synthesis slot.
3. Reference the report in `build-status.json` under `learnings.curate_report`
   (path) and `learnings.curate_status` (`"complete"`, `"skeleton-only"`, or
   `"failed"` with `curate_error`).

Terminal mode NEVER promotes, updates, or prunes knowledge files — that
remains user-initiated via standalone `/run-curate`. The skeleton is
guaranteed-present so `build-status.json` always has something to reference.

## Anti-Patterns

- Promoting E0/E1-only learnings without evidence anchor
- Creating knowledge files for content derivable from code or git history
- Exceeding AGENTS.md token budget
- Promoting skill/agent operational details to docs/ knowledge files (belongs in skill/agent files)
- Treating envoy GAP/WATCH items as promotable without E2+ evidence
- Running staleness detection against all knowledge files regardless of changed neighbors (full-corpus sweep)
- Gating promotion on glossary alignment — glossary findings are advisory, not blockers
- Suggesting glossary creation when none exists — with-terminology owns that advisory
