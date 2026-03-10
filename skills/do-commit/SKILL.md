---
name: do-commit
description: >
  Safe, scoped commit workflow.
  Use when ready to commit changes. Do NOT use mid-implementation —
  finish the current task first.
disable-model-invocation: true
argument-hint: "[message]"
---

Stage only in-scope files, draft Conventional Commits message, confirm with user, commit.

## Workflow

1. **Inspect** — `git status` + `git diff --stat` to see dirty files.
2. **Scope files** — priority order:
   - User-specified files (highest)
   - Files attributable to current task/session
   - Best-guess from dirty files — include proposed list in confirmation step
3. **Draft message** — `<type>[optional scope][!]: <description>` (imperative, specific, ≤72 chars).
   For multi-file changes, add concise body (1–3 bullets) explaining why, constraints, impact.
   Do not restate the diff.
4. **Confirm** — display proposed message as fenced code block + staged file paths.
   Ask one concise question. Never commit without explicit user approval.
5. **Commit** — stage only confirmed paths. If committed paths differ from staged
   (e.g., hooks modified content), report deltas.
6. **Report** — commit hash and summary.

## Scoped Staging

Never auto-stage all dirty files (`git add -A` / `git add .`). Stage only confirmed in-scope
paths. Pre-commit hooks may modify content during commit — expected.

## Message Format

Conventional Commits. Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`, `build`.

- Subject: imperative, specific, no vague summaries (`update stuff`, `fix things`)
- Body: explains *why*, not *what* — diff shows what changed
- Breaking changes: `!` suffix on type or `BREAKING CHANGE:` footer

## Constraints

- Push only when explicitly requested.
- Amend only when explicitly requested.
- No in-scope committable files → report and stop.
- Never strip or modify commit trailers added by platform or user.

## Anti-Patterns

- Auto-staging all dirty files without scoping
- Committing without explicit user confirmation
- Vague commit messages
- Pushing or amending without being asked
