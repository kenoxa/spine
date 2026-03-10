# Tips

> Workflow tips, shortcuts, and model guidance for spine users. For setup and installation, see the [README](../README.md#quick-start).

## Slash Command Arguments

Text after a slash command is the task scope. Examples:

- `/do-discuss the auth flow feels broken on mobile`
- `/do-plan add retry strategy for API calls`
- `/do-review` — reviews current changes against the plan
- `/do-debug failing auth test in CI`
- `/use-explore auth module architecture`
- `/do-execute` — starts execution of an approved plan (or plans inline if none exists)

## Screenshot Shortcuts (macOS)

- **Screenshot → clipboard:** `Control-Shift-Command-3` (full screen) or `Control-Shift-Command-4` (selection); image goes to clipboard — paste directly into your tool's chat.
- **Thumbnail drag:** `Shift-Command-4` (selection) shows a thumbnail in the corner; drag it into the chat before it fades.
- **Ergonomic remap:** if `Control-Shift-Command` feels awkward, remap to an `Option-Command` combo in System Settings → Keyboard → Shortcuts → Screenshots.

## Workflow Tips

- **Domain skills auto-load** — `with-frontend`, `with-backend`, and `with-testing` activate automatically when the task matches. No slash command needed.
- **Refine before executing** — polish the plan via messages before running `/do-execute`. The plan drives all quality gates downstream.
- **Fresh chat for execution** — after planning is ready, consider opening a fresh chat for `/do-execute` to reduce context carryover and keep the execution window clean.
- **Use subagents for parallel work** — the `scout` agent handles fast codebase reconnaissance; the `researcher` agent performs deep discovery; the `inspector` and `analyst` agents run focused code review with different lenses.
- **Evidence levels matter** — all claims in plans, reviews, and execution are tagged E0–E3. Blocking claims require code evidence (E2+). Verification requires executed output (E3).
- **Skill-craft for meta-work** — use `/use-skill-craft` to write, review, or audit skills and AGENTS.md files. It enforces the authoring test: every skill line must address something an LLM handles worse without guidance.

## Which Model to Use

Use cost-effective defaults for orchestration, then escalate only when quality or risk requires it.

- **Default orchestration:** use your tool's auto/default model for planning and coordination.
- **Frontier reserve:** escalate to stronger models (Opus, Sonnet, Codex) for implementation-heavy work, ambiguous requirements, and debugging.
- **Planning is the lever:** structured planning (`/do-plan`) improves output quality more than model choice alone. Strong model + planning > strong model without planning > weak model + planning.
