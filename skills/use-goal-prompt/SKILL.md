---
name: use-goal-prompt
description: >-
  /goal compiler. Use when: 'goal prompt', 'plan', 'build', 'refactor', 'harden', 'migrate'.
argument-hint: "[intent: interrogate|plan|build|refactor|consolidate|harden|migrate] [topic]"
---

Read-only. Emit a `/goal` prompt; never execute it.

## Overview

Pick a template, fill bracketed slots, emit a `/goal` prompt with 9 sections:
`GOAL · CONTEXT · CONSTRAINTS · PRIORITY · PLAN · DONE WHEN · VERIFY · OUTPUT · STOP RULES`.

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

1. Read the chosen `references/template-{intent}.md`.
2. Identify load-bearing user-specific slots (bracketed `[...]` placeholders).
3. Compute slot budget = `4000 - <template body chars>` (the `/goal` validator caps prompts at 4000 chars). Surface the budget when asking slot questions; require short references, not pasted content (paths, ticket IDs, one-line summaries).
4. Ask ≤3 questions for missing load-bearing slots. Group related slots per question.
5. Stop once a non-trivial render is possible; remaining gaps become `<NEEDS: short description>` markers.
6. Render: user-specific slots → user input; everything else (CONSTRAINTS, PRIORITY, PLAN, VERIFY, STOP RULES) → verbatim from template ref.
7. Render STOP RULES verbatim — no softening, abbreviation, or paraphrase.
8. Sentinel slot values (e.g., `"recommend after inventory"` in consolidate) pass through verbatim — do not ask the user.

### Output

1. Measure char count of the rendered prompt body. If > 4000, do NOT write the file; surface the largest slot values, the over-budget delta, and ask the user to shorten — retry from Compose step 4.
2. Write filled prompt to `.scratch/<session>/goal-prompt.md`.
3. Attempt clipboard copy (`pbcopy` / `xclip`). Fail silent.
4. Print one block: file path, char count, clipboard status, unfilled-slot count (omit if 0), target `/goal` command.
5. Suggest: "Paste into /goal (Codex or Claude Code)." If mixed mode, append the follow-up next-template line.

## Completion

E3 evidence before exit:
- `.scratch/<session>/goal-prompt.md` exists, char count ≤ 4000 (E3: `wc -c < goal-prompt.md` ≤ 4000), with all 9 sections (E3: `grep -cE '^(GOAL|CONTEXT|CONSTRAINTS|PRIORITY|PLAN|DONE WHEN|VERIFY|OUTPUT|STOP RULES):$' goal-prompt.md` == 9).
- Only `[slot]` placeholders replaced — body otherwise byte-identical to the template ref's fenced block (E3: `diff <(sed -n '/^```$/,/^```$/p' references/template-{intent}.md | sed '1d;$d') goal-prompt.md` shows only slot-region diffs).
- Phase Trace logged with template choice + ask-count.

## Anti-Patterns

- Executing the goal instead of compiling its prompt — this skill only emits text.
- Inventing constraints or stop-rules not in the source template — only bracketed slots accept user input.
- Asking >3 questions in Compose — if more are needed, the wrong template was picked; re-classify.
- Modifying STOP RULES in any way.
- Composing two templates into one prompt — emit one and suggest a second session for the other.
- Auto-running `/do-frame` or `/do-design` after output — suggest only; user pastes manually.
- "I'll trim STOP RULES to save chars" — reality: every cut is a safety regression. Compress CONTEXT/PLAN instead.
- "User clearly wants the goal executed — I'll just do it" — reality: this skill emits text; the user's /goal handler executes. Stay in your lane.
- "User asks to 'watch pipeline until green' — I'll compile a build-template goal" — reality: `/goal`'s Stop hook re-fires on every polling check with no productive agent work between fires. Decline and redirect to `/loop` or `gh run watch`.
