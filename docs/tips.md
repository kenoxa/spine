# Tips

> Workflow tips, shortcuts, and model guidance for spine users. For setup and installation, see the [README](../README.md#quick-start).

## Slash Command Arguments

Text after a slash command is the task scope. Examples:

- `/do-discuss the auth flow feels broken on mobile`
- `/do-plan add retry strategy for API calls`
- `/run-review` — reviews current changes against the plan
- `/run-debug failing auth test in CI`
- `/use-explore auth module architecture`
- `/do-execute` — starts execution of an approved plan (or plans inline if none exists)

## Screenshot Shortcuts (macOS)

- **Screenshot → clipboard:** `Control-Shift-Command-3` (full screen) or `Control-Shift-Command-4` (selection); image goes to clipboard — paste directly into your tool's chat.
- **Thumbnail drag:** `Shift-Command-4` (selection) shows a thumbnail in the corner; drag it into the chat before it fades.
- **Ergonomic remap:** if `Control-Shift-Command` feels awkward, remap to an `Option-Command` combo in System Settings → Keyboard → Shortcuts → Screenshots.

## Workflow Tips

- **Domain skills auto-load** — `with-frontend`, `with-backend`, and `with-testing` activate automatically when the task matches. No slash command needed.
- **Refine before executing** — polish the plan via messages before running `/do-execute`. The plan drives all quality gates downstream.
- **Context rotation** — at ~60% context, run `/handoff` then `/clear` then `/catchup`. Prefer over `/compact` — compaction loses rationale and rejected approaches.
- **Use subagents for parallel work** — `scout` handles breadth, `researcher` handles deep discovery plus bounded plan-local upstream checks, `navigator` handles broad/current external research, and `inspector` / `analyst` handle review lenses.
- **Evidence levels matter** — all claims in plans, reviews, and execution are tagged E0–E3. Blocking claims require code evidence (E2+). Verification requires executed output (E3).
- **Skill-craft for meta-work** — use `/use-skill-craft` to write, review, or audit skills and AGENTS.md files. It enforces the authoring test: every skill line must address something an LLM handles worse without guidance.

## Agent Mode

Spine skills dispatch subagents that read, write, and run commands autonomously. Plan/ask modes interrupt this workflow with constant approval prompts.

| Provider | Recommended mode | Avoid |
|----------|-----------------|-------|
| Cursor | Agent mode | Ask, Plan, Debug modes |
| Claude Code | Auto accept edits | Plan mode |
| Codex | Full auto mode | — |

Skills technically work in other modes, but the experience degrades to manual approval on every file edit and command execution.

## Which Model to Use

Use cost-effective defaults for orchestration, then escalate only when quality or risk requires it.

- **Default orchestration:** use your tool's auto/default model for planning and coordination.
- **Frontier reserve:** escalate to stronger models (Opus, Sonnet, Codex) for implementation-heavy work, ambiguous requirements, and debugging.
- **Planning is the lever:** structured planning (`/do-plan`) improves output quality more than model choice alone. Strong model + planning > strong model without planning > weak model + planning.
