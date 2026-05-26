---
name: use-goal-prompt
description: >-
  Use when: 'goal prompt', 'frame this', 'scope this', 'design', 'plan the approach', 'implement and review', 'just ship it', 'fix this', 'add this'.
argument-hint: "[--intent=interrogate|plan|build|refactor|consolidate|harden|migrate] [--enrich] [topic]"
---

Read-only. Emit a `/goal` prompt; never execute it.

## Overview

Pick the closest template, adapt it to the user's actual task, emit a `/goal` prompt with 9 sections:
`GOAL · CONTEXT · CONSTRAINTS · PRIORITY · PLAN · DONE WHEN · VERIFY · OUTPUT · STOP RULES`.

Templates are starting points, not fill-in-the-blank forms. Reformulate, rephrase, drop irrelevant lines, add task-specific ones. Keep all 9 section headers — they are the `/goal` output-format contract.
Rendered prompts must explicitly name `/use-session` for continuity. When the task mentions a branch, worktree, or isolated implementation, also name `/use-worktree`. Do not rely on automatic skill triggering.

## Phases

**Phase Trace**: Classify, Compose, Output all zero-dispatch. Log template + ask-count.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Classify | mainthread | catalog table below |
| Compose | mainthread | `references/template-{intent}.md` |
| Output | mainthread | — |

### Classify

If `--intent=<name>` flag present, use it. Else match user phrasing:

| Template | Phase | Trigger phrases | Discipline reference |
|----------|-------|----------------|---------------------|
| interrogate | frame | "vague idea", "fuzzy", "intake interview", "scope this", "what do I actually want", "build-ready brief" | `references/phase-discipline-frame.md` |
| plan | design | "planning docs", "roadmap", "decisions doc", "spec", "design doc", "ADR", "milestones" | `references/phase-discipline-design.md` |
| refactor | design | "refactor", "restructure", "preserve behavior", "surgical diff", "clean up", "no behavior change" | `references/phase-discipline-design.md` |
| consolidate | design | "parallel implementations", "canonical version", "collapse parallel", "single source of truth" | `references/phase-discipline-design.md` |
| build | build | "implement the plan", "build the system", "ship it end-to-end", "execute roadmap", "full system" | `references/phase-discipline-build.md` |
| harden | build | "test coverage", "CI pinning", "supply chain", "security posture", "guardrails", "pin dependencies" | `references/phase-discipline-build.md` |
| migrate | build | "schema migration", "data migration", "platform migration", "dual-write", "rollback path" | `references/phase-discipline-build.md` |

Boundary: multiple parallel implementations → consolidate. One implementation needs restructuring → refactor.

**Decline branch — watch / poll / observe-external-event:** If intent reduces to "watch X until terminal state", do NOT compile a `/goal` prompt. Suggest `/loop <interval> <command>` or `gh run watch` / `glab ci status --wait`. Return without writing.

- Sequential pipeline: `interrogate → plan → build` for greenfield. Standalone: refactor / consolidate / harden / migrate.
- Mixed intent: pick the dominant template; append `Mixed mode — also draft <other> as a separate /goal session` to Output.
- Ambiguous: ask one ranked-proposal question. Never invent an 8th template.

### Compose

1. Read `references/template-{intent}.md`. Adapt the fenced block; do not copy verbatim.
2. Look up the template's phase → load the corresponding discipline reference.
3. Inject discipline stubs at PLAN + STOP RULES seams:
   - PLAN seam: `Phase discipline: See <discipline-ref-path>. MANDATORY: load before proceeding. In autonomous (/goal) flows, user-STOP gates become emit-artifact-and-halt signals.`
   - STOP RULES seam: `Phase discipline stops: See <discipline-ref-path>.`
4. Identify must-ask inputs (bracketed `[...]` placeholders). For each candidate question, first attempt to resolve via the source artifact, Read/Grep of repo paths, or a `@scout` dispatch — surface to the user only what genuinely requires their judgment or domain knowledge. Ask ≤3 questions; group related. Require short references — paths, ticket IDs — never pasted content.
5. Stop asking once a non-trivial render is possible; remaining gaps → `<NEEDS: short description>`.
6. Compose each section to fit the task. Keep all 9 section headers.
7. Add `SESSION:` under `CONTEXT`: `Use /use-session; maintain session.json + events.jsonl + session-log.md. If worktree needed, use /use-worktree attach, not fork.`
8. Keep the rendered prompt under 4000 chars. Size depth to the task.

### Enrich (optional)

When `--enrich` flag is set, dispatch `@scout` for codebase context BEFORE composing. Auto-enable when the render would exceed the 4000-char cap without a `goal-brief.md` sidecar.

### Output

1. Measure char count. If > 4000, do NOT write; surface the over-budget delta and re-compose tighter. Never raise the cap.
2. Brief emission: if render ≤4000 AND no overflow context (large constraint tables, reference lists), skip `goal-brief.md`. If overflow context exists, emit `.scratch/<session>/goal-brief.md` per `references/goal-brief-schema.md` and reference it by path in CONTEXT.
3. Write filled prompt to `.scratch/<session>/goal-prompt.md`.
4. Attempt clipboard copy (`pbcopy` / `xclip`). Fail silent.
5. Print: file path, char count, clipboard status, unresolved `<NEEDS:>` count (omit if 0), target `/goal` command.
6. Suggest: "Paste into /goal (Codex or Claude Code)." If mixed mode, append the follow-up next-template line.

## Completion

E3 evidence before exit:
- `.scratch/<session>/goal-prompt.md` exists, char count ≤ 4000 (E3: `wc -c < goal-prompt.md` ≤ 4000).
- All 9 section headers present (E3: `grep -cE '^(GOAL|CONTEXT|CONSTRAINTS|PRIORITY|PLAN|DONE WHEN|VERIFY|OUTPUT|STOP RULES):$' goal-prompt.md` == 9).
- Multi-turn prompts include `/use-session`; worktree prompts include `/use-worktree`. [E2/E3]
- Phase Trace logged with template choice + ask-count.

## Anti-Patterns

- Executing the goal instead of compiling its prompt — this skill only emits text.
- Asking >3 questions in Compose — wrong template; re-classify.
- Composing two templates into one prompt — emit one, suggest second session.
- Skipping discipline stub injection — every prompt MUST reference the phase-discipline file.
- Raising the 4000-char cap — never valid; tighten content.
- Inlining phase-discipline content — reference by path only; never copy inline.
- Auto-resolving divergence — surface it; never resolve it.
- "User wants it executed" — this skill emits text only. Stay in your lane.
- "Watch pipeline until green" — `/goal` Stop hook re-fires on polling; decline and redirect to `/loop` or `gh run watch`.
