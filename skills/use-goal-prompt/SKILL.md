---
name: use-goal-prompt
description: >-
  Use when: 'goal prompt'.
argument-hint: "[intent: interrogate|plan|build|refactor|consolidate|harden|migrate] [topic]"
---

Read-only. Emit a `/goal` prompt; never execute it.

## Overview

Pick the closest template, adapt it to the user's actual task, emit a `/goal` prompt with 9 sections:
`GOAL · CONTEXT · CONSTRAINTS · PRIORITY · PLAN · DONE WHEN · VERIFY · OUTPUT · STOP RULES`.

Templates are starting points, not fill-in-the-blank forms. Reformulate, rephrase, drop
irrelevant lines, add task-specific ones so the prompt fits the job. Keep all 9 section
headers — they are the `/goal` output-format contract; compose the content within freely.

## Phases

**Phase Trace**: Classify, Compose, Output all zero-dispatch. Log template + ask-count.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Classify | mainthread | catalog table below |
| Compose | mainthread | `references/template-{intent}.md` |
| Output | mainthread | — |

### Classify

If `--intent=<name>` flag present, use it. Else match user phrasing to one template:

| Template | Trigger phrases | Reference (lazy-load) |
|----------|----------------|----------------------|
| interrogate | "vague idea", "fuzzy", "intake interview", "scope this", "what do I actually want", "build-ready brief" | `references/template-interrogate.md` |
| plan | "planning docs", "roadmap", "decisions doc", "spec", "design doc", "ADR", "milestones" | `references/template-plan.md` |
| build | "implement the plan", "build the system", "ship it end-to-end", "execute roadmap", "full system" | `references/template-build.md` |
| refactor | "refactor", "restructure", "preserve behavior", "surgical diff", "clean up", "no behavior change" | `references/template-refactor.md` |
| consolidate | "parallel implementations", "canonical version", "collapse parallel", "single source of truth", "merge implementations" | `references/template-consolidate.md` |
| harden | "test coverage", "CI pinning", "supply chain", "security posture", "guardrails", "regression coverage", "pin dependencies" | `references/template-harden.md` |
| migrate | "schema migration", "data migration", "platform migration", "dual-write", "rollback path" | `references/template-migrate.md` |

Boundary: multiple parallel implementations → consolidate. One implementation needs restructuring → refactor.

**Decline branch — watch / poll / observe-external-event:** If the user's intent reduces to "watch X until terminal state" (CI pipeline, deploy, long job), do NOT compile a `/goal` prompt. The `/goal` Stop hook re-fires on every check with no productive work between fires. Suggest `/loop <interval> <command>` (e.g. `/loop 2m gh run watch <id>`) or a blocking `gh run watch` / `glab ci status --wait` instead. Return without writing a goal-prompt file.

- Sequential pipeline: `interrogate → plan → build` for greenfield. Standalone: refactor / consolidate / harden / migrate.
- Mixed intent: pick the dominant template; append `Mixed mode — also draft <other> as a separate /goal session` to Output.
- Ambiguous: ask one ranked-proposal question. Never invent an 8th template.

### Compose

1. Read the chosen `references/template-{intent}.md`. Treat its fenced block as a scaffold to adapt, not a script to copy.
2. Identify what only the user can supply — paths, IDs, the concrete task, scope. Bracketed `[...]` placeholders mark the obvious ones; the task may need more.
3. Ask ≤3 questions for missing must-ask inputs. Group related ones per question. Require short references — paths, ticket IDs, one-line summaries — never pasted content.
4. Stop asking once a non-trivial render is possible; remaining gaps become `<NEEDS: short description>` markers.
5. Compose each section to fit the task: keep template lines that apply, rephrase ones that nearly apply, drop ones that don't, add lines the task needs. Keep all 9 section headers.
6. Keep the rendered prompt under 4000 chars (the `/goal` cap). Size depth to the task.

### Output

1. Measure char count of the rendered prompt body. If > 4000, do NOT write the file; surface the longest sections and the over-budget delta, then re-compose tighter (Compose step 5).
2. Write filled prompt to `.scratch/<session>/goal-prompt.md`.
3. Attempt clipboard copy (`pbcopy` / `xclip`). Fail silent.
4. Print one block: file path, char count, clipboard status, unresolved `<NEEDS:>` marker count (omit if 0), target `/goal` command.
5. Suggest: "Paste into /goal (Codex or Claude Code)." If mixed mode, append the follow-up next-template line.

## Completion

E3 evidence before exit:
- `.scratch/<session>/goal-prompt.md` exists, char count ≤ 4000 (E3: `wc -c < goal-prompt.md` ≤ 4000).
- All 9 section headers present (E3: `grep -cE '^(GOAL|CONTEXT|CONSTRAINTS|PRIORITY|PLAN|DONE WHEN|VERIFY|OUTPUT|STOP RULES):$' goal-prompt.md` == 9).
- Phase Trace logged with template choice + ask-count.

## Anti-Patterns

- Executing the goal instead of compiling its prompt — this skill only emits text.
- Asking >3 questions in Compose — if more are needed, the wrong template was picked; re-classify.
- Composing two templates into one prompt — emit one and suggest a second session for the other.
- Auto-running `/do-frame` or `/do-design` after output — suggest only; user pastes manually.
- Copying a template verbatim when half its lines don't fit the task — an unedited scaffold means no thought went in; adapt it or re-classify.
- "User clearly wants the goal executed — I'll just do it" — reality: this skill emits text; the user's /goal handler executes. Stay in your lane.
- "User asks to 'watch pipeline until green' — I'll compile a build-template goal" — reality: `/goal`'s Stop hook re-fires on every polling check with no productive agent work between fires. Decline and redirect to `/loop` or `gh run watch`.
