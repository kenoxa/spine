---
name: run-research
description: >-
  Use when: 'deep research', 'outsource research', 'research prompt', 'research handoff'.
argument-hint: "[research goal] [--target chatgpt|claude] [--depth deep]"
---

Read-only — no code changes, no builds, no test runs.

## Phases

**Phase Trace**: log row per phase. Frame (zero-dispatch), Gather (G), Compile (zero-dispatch), Output (zero-dispatch). Include depth classification and target.

| Phase | Agent | Reference |
|-------|-------|-----------|
| Frame | mainthread | — |
| Gather | `@scout` + `gather-scout.md` OR `@researcher` + `gather-researcher.md` | gated |
| Compile | mainthread | [template-prompt.md](references/template-prompt.md) |
| Output | mainthread | — |

### Frame

Clarify research goal. Identify:
- **Research question** — what decision does this inform?
- **Scope** — boundaries, in/out, time range
- **Output format** — named format from template or user-specified
- **Target** — `--target chatgpt|claude` (default: `chatgpt`)
- **Depth** — standard (default) or `--depth deep`

### Gather

Gated dispatch:

| Condition | Dispatch |
|-----------|----------|
| Purely external (no codebase dependency) | zero-dispatch |
| Standard depth | `@scout` + `references/gather-scout.md` |
| `--depth deep` | `@researcher` + `references/gather-researcher.md` |

Output: `.scratch/<session>/research-context.md`

### Compile

1. Read [template-prompt.md](references/template-prompt.md).
2. Fill 4 required sections from goal + gathered context.
3. Apply security redaction (rules in template ref).
4. Apply UI adaptation per `--target` (table in template ref).
5. Select output format.

### Output

1. Write prompt to `.scratch/<session>/research-prompt.md`.
2. Attempt clipboard copy (`pbcopy`/`xclip`). Fail-silent on error.
3. Print: file path, character count, clipboard status, target UI.
4. Suggest: "Paste into [target] Deep Research. When you have results, start `/use-goal-prompt interrogate` (frame) or `/use-goal-prompt plan` (design) with the findings."

## Anti-Patterns

- Answering the research question instead of compiling a prompt for external AI
- Skipping security redaction before output
- Auto-dispatching the next phase after output (suggest only)
- Exceeding structural item caps in gather output (see gather refs)
