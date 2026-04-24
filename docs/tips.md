# Tips

> Workflow tips, shortcuts, and model guidance for spine users. For setup and installation, see the [README](../README.md#quick-start).

## Slash Command Arguments

Text after a slash command is the task scope. Examples:

- `/do the auth flow feels broken on mobile`
- `/do-frame add retry strategy for API calls`
- `/do-design` — gather multi-model advisory on approach
- `/do-build` — prototype, review, and polish
- `/run-review` — reviews current changes
- `/run-debug failing auth test in CI`
- `/run-explore auth module architecture`

## Screenshot Shortcuts (macOS)

- **Screenshot → clipboard:** `Control-Shift-Command-3` (full screen) or `Control-Shift-Command-4` (selection); image goes to clipboard — paste directly into your tool's chat.
- **Thumbnail drag:** `Shift-Command-4` (selection) shows a thumbnail in the corner; drag it into the chat before it fades.
- **Ergonomic remap:** if `Control-Shift-Command` feels awkward, remap to an `Option-Command` combo in System Settings → Keyboard → Shortcuts → Screenshots.

## Workflow Tips

- **Domain skills auto-load** — `with-frontend`, `with-backend`, `with-testing` (test boundary decisions, mock strategy), and `with-terminology` activate automatically when the task matches. No slash command needed.
- **Refine before building** — polish the advisory recommendation via messages before running `/do-build`. The recommendation drives all quality gates downstream.
- **Context rotation** — at ~60% context, run `/handoff` then `/clear` then `/catchup`. Prefer over `/compact` — compaction loses rationale and rejected approaches.
- **Use subagents for parallel work** — `scout` handles breadth, `researcher` handles deep discovery plus bounded plan-local upstream checks, `navigator` handles broad/current external research, and `inspector` / `analyst` handle review lenses.
- **Write-skeleton-early for limit resilience** — when dispatching subagents on long tasks, add the instruction: *"write the output-file structure (headers + empty sections) immediately after reading inputs, before analysis."* Agents that hit API usage limits error out atomically — zero output. An early skeleton write converts a total loss into a recoverable partial: re-dispatch completes against the stub. *Adjacent prior art: Skeleton-of-Thought (structure-first for latency, not resilience); Claude Code checkpointing (rewinds after errors, not zero-output cutoffs). This tip targets the narrower "rate-limit kills run before any artifact exists" mode.* `[ADVISORY: envoy]`
- **Evidence levels matter** — all claims in plans, reviews, and execution are tagged E0–E3. Blocking claims require code evidence (E2+). Verification requires executed output (E3).
- **Skill-craft for meta-work** — use `/use-skill-craft` to write, review, or audit skills, agent files, reference files, and AGENTS.md. It enforces the authoring test: every skill line must address something an LLM handles worse without guidance.

## Agent Mode

Spine skills dispatch subagents that read, write, and run commands autonomously. Plan/ask modes interrupt this workflow with constant approval prompts.

| Provider | Recommended mode | Avoid |
|----------|-----------------|-------|
| Cursor | Agent mode | Ask, Plan, Debug modes |
| Claude Code | Auto accept edits | Plan mode |
| Codex | Full auto mode | — |

Skills technically work in other modes, but the experience degrades to manual approval on every file edit and command execution.

## Which Model to Use

Spine assigns subagents to three tiers (Frontier/Standard/Fast) with provider-mapped models. The mainthread model is your session choice.

- **Subagent tiers are automatic:** agent frontmatter pins each subagent to a tier. The installer and runtime map tiers to provider-specific models. See [docs/model-selection.md](model-selection.md) for the full mapping.
- **Mainthread guidance:** Standard (sonnet:medium / gpt-5.4:medium / auto) for all phases. Upgrade to Frontier when requirements are ambiguous, architectural decisions are cascading, or context exceeds ~50K tokens. See [docs/model-selection.md](model-selection.md) for escalation triggers.
- **Consultation is the lever:** structured advisory (`/do-design`) improves output quality more than model choice alone. Strong model + consultation > strong model without consultation > weak model + consultation.
- **Override envoy models:** set `SPINE_ENVOY_{TIER}_{PROVIDER}` in `~/.config/spine/.env` for per-tier envoy overrides.
