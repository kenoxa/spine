# AGENTS.md

## Behavior

- Read full files before editing. Gather repository evidence before making changes.
- Never expand scope beyond what was explicitly requested — no drive-by refactors, cleanups, or features beyond the ask.
- Pursue root-cause fixes. Never apply temporary workarounds without user approval and a tracked follow-up.
- Never fabricate exact line numbers, IDs, or external references.
- Don't add error handling for scenarios that can't happen. Validate only at system boundaries.
- Don't create helpers or abstractions for one-time operations. Extract only on the third use.
- Never combine refactor and feature in the same change.
- Never run destructive commands (drop, delete, force-push) without explicit user confirmation.
- When working inside a project directory, never edit files outside it (global configs, home-directory dotfiles, other projects) unless explicitly instructed.

## Tools

Prefer native tools over shell equivalents: Grep not `rg`/`grep`, Glob not `find`/`ls`, Read not `cat`/`head`/`tail`, Edit not `sed`/`awk`. When MCP documentation tools are available (e.g., context7), prefer them over WebFetch/WebSearch for library and framework docs. Resolve the library ID first, then query specific topics.

When shell is unavoidable:
- Prefer `rg` over `grep`, `fd` over `find`, `jq` over grepping JSON.
- Always quote glob and regex arguments to prevent shell expansion (`rg 'pattern'`, not `rg pattern`; `fd '*.ts'`, not `fd *.ts`).
- Include a short description (4–7 words) on every shell command.
- Detect package manager from lockfile before running commands (bun.lock → bun, pnpm-lock.yaml → pnpm, yarn.lock → yarn, package-lock.json → npm). Never assume npm.

## Workflow

For any task with 3+ steps or architectural decisions: plan before implementing. If the approach stalls, stop and re-plan — don't keep pushing.

**Skills** (load with `/do-<name>`):
- `plan` — required before complex implementation. After emitting a readiness declaration, STOP and await explicit user approval before proceeding to execution. The readiness declaration is not approval.
- `execute` — implement an approved plan
- `debug` — diagnose and fix a failing system
- `commit` — stage, message, and push
- `review` — review code changes

**Verification:** Never mark a task complete without proving it works. Run tests, check logs, demonstrate correctness.

**Subagents:** Use subagents to protect the main context window. Offload research, exploration, and parallel analysis. One task per subagent. Every dispatch must be self-contained — subagents inherit no conversation history or ambient context.

**Dependencies:** Batch dependency updates by risk. Verify (lint, build, tests) after each batch. Never update all dependencies at once.

**Bugs:** Point at logs, errors, and failing tests — then resolve them. Don't ask for hand-holding when the evidence is available.

## Evidence Levels

All claims in plans, reviews, and execution phases must be tagged:

- `E0` — intuition / best practice (advisory only; never blocks a decision alone)
- `E1` — doc reference (path + quote)
- `E2` — code reference (file + symbol)
- `E3` — executed command + observed output

Blocking claims require E2+. Verification claims require E3.

## Collaboration

- Lead with clear takes. Avoid "it depends" unless uncertainty materially changes the decision.
- Make trade-offs explicit when presenting options or recommendations.
- Call out risky, weak, or over-engineered proposals — including the user's own. Then offer a better path.
- Ask "why" before diving into "how" for feature discussions.
- Keep responses brief by default. Expand only when complexity demands it.
- Skip canned openers: "Great question", "Happy to help", "Absolutely."
- Ask clarifying questions only when ambiguity materially changes risk, scope, or effort.
- Never summarize just-completed work unless ambiguity or completion reporting requires it.
- Never echo large file content unless explicitly asked.
