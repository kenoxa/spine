# Changelog

All notable changes are documented here, focused on user impact.

## 2026-03-11

### Changed

- **Skills and agents compressed to telegraphic prose** — 19 files rewritten: full sentences → imperative fragments, motivational clauses deleted, redundant encoding deduplicated. Net reduction: ~218 lines. Verified via 32 Sonnet evaluation runs (188 assertions, 1 regression found and fixed).
- **Frontmatter standardized** — all skill descriptions now use `Use when:` / `Do NOT use` with trigger phrases for more accurate skill activation.
- **Subagent dispatch centralized** — SPINE.md now contains the canonical subagent constraint string, removing 5 duplicate definitions from individual skills.
- **do-polish advisory constraint strengthened** — intro now explicitly says "produces suggestions, not rewrites" and anti-pattern prohibits outputting complete rewritten files. Sonnet evaluation showed the compressed version produced full code rewrites without this framing.
- **Skill-crafter gains compression safety rule** — "Compress grammar, not behavioral qualifiers" added to prevent future compression from dropping output-constraining phrases.

## 2026-03-10

### Added

- **Unified session handling in SPINE.md** — session ID format (`{YYWW}-{slug}-{hash}`), `.scratch/<session>/` directory, carry-forward chain (discuss → plan → execute), append-only session log at phase boundaries, and todo tool advisory. Defined once for all workflow skills.
- **Agent mode guidance** — README Quick Start callout directing users to their tool's autonomous mode, and `docs/tips.md` provider mode table (Cursor agent, Claude Code auto-accept, Codex full auto).
- **`do-handoff` skill** — distill session context into a structured handoff prompt for a fresh session. Captures goal-directed context, file inventory, and current state as a self-contained artifact. Invoke with `/do-handoff [direction]`.
- **`worker` subagent** — read-write implementation agent for do-execute implement, polish-apply, and review-fix phases. Replaces `general-purpose` dispatch with a spine-owned agent that enforces partition-scoped edits and mode-routed self-review.

### Changed

- **Session ID format simplified** — changed from `{YYWW}-{slug}-{hash}` to `{slug}-{hash}`, dropping the year-week prefix. The ISO week number was frequently incorrect, making the intended chronological sorting unreliable. Filesystem timestamps serve the same purpose.
- **Session ID references consolidated** — do-plan, do-execute, do-discuss, and do-history-insights now reference SPINE.md Sessions convention instead of inline session ID format definitions (~12 lines of duplication removed).
- **do-handoff reads session log** — Gather phase checks for `.scratch/<session>/session-log.md` as primary input for the Current State section when available, with graceful fallback.
- **README restructured** — 4-step workflow (discuss, plan, execute, commit) is now the dominant visual; "Typical Flow" renamed to "Workflow" with simplified LR mermaid diagram. Detailed skill descriptions and tips extracted to `docs/`. Subagents and convention tables collapsed. Claude Code Plugin demoted to details. `global-skills.md` moved to `docs/`.
- **Scout upgraded** — added thoroughness calibration (orient/trace/audit heuristics) and handoff contract for self-contained output.
- **do-execute dispatches `@worker`** — implement, polish-apply, and review-fix phases now specify `@worker` agent type with explicit mode names instead of `general-purpose`.
- **Central install directory** — Spine now installs guardrails and agents to `~/.config/spine/` as the single source of truth. Provider root files (`CLAUDE.md`, `AGENTS.md`) reference it via `@~/.config/spine/SPINE.md` instead of containing a full copy. Users can add their own instructions below the `@` line — re-running the installer preserves them.
- **Agent symlinks** — agents in each provider's config directory are now symlinks to `~/.config/spine/agents/`, matching how skills already work. Re-running the installer updates the central copy; symlinks ensure all providers see the change immediately.
- **Renamed `AGENTS.global.md` → `SPINE.md`** — the source guardrails file is now named `SPINE.md` in the repo and in `~/.config/spine/`. Provider root files reference it by this name.
- **Migration is automatic** — re-running `install.sh` detects the old layout (full file copies, regular agent files) and migrates to the new layout. Backup `.bak` files are created for all replaced files.

## 2026-03-09

### Added

- **`do-history-insights` skill** — periodic cross-tool session analysis that mines Claude Code, Codex, and Cursor history to produce actionable workflow and setup improvement recommendations. Identifies candidates for skills, hooks, MCP servers, plugins, agents, and CLAUDE.md rules. Requires Python 3.9+ (Claude Code only).
- **`do-history-recap` skill** — summarize work done across AI agent sessions for standups, timesheets, and activity reports. Three formats: standup (grouped bullets), timesheet (billable hour blocks, 9-17 window), and recap (narrative with metrics). Dispatches `@miner` subagent for task description synthesis and duration estimation. Shares session parsing infrastructure with `do-history-insights`.
- **`miner` subagent** — session data analysis and cross-session pattern extraction. Supports source-expert, synthesizer, prior-session, and recap modes. Used by do-history-insights for analytics analysis, do-history-recap for work summarization, and do-plan prior-session mining.
- **`do-polish` skill** — standalone advisory code polish with three parallel lenses (conventions, complexity, efficiency). Also powers do-execute phase 3. Invoke with `/do-polish` or let do-execute use it automatically.
- **`verifier` subagent** — adversarial verification for do-execute phase 5. Probes implementations using five categories (boundary, concurrency, idempotency, resource-lifecycle, error-propagation) and produces PASS/FAIL/PARTIAL verdicts.
- **Security probe false-positive filtering** — 17 exclusion rules and 12 precedent patterns for high-risk security review. Suppresses common false positives (React auto-escaping, bcrypt, env vars, parameterized queries) so reviews surface real vulnerabilities.

### Changed

- **Analyst now supports efficiency-advisor** — third advisory lens alongside conventions and complexity. Flags reuse gaps, N+1 patterns, missed concurrency, and hot-path bloat.
- **Inspector applies scope discipline** — delegates to do-review noise filtering and adds "would the author fix this?" heuristic to reduce low-value findings.
- **do-review gains noise filtering** — four-rule filter ensures findings are introduced by the change, discrete, actionable, and codebase-consistent. High-risk security findings use the new exclusion rules.
- **do-execute dispatches verifier** — phase 5 now uses the `@verifier` agent type. Phase 3 dispatches three polish advisors instead of two.
- **Agent teams updated** — exec-polish team includes efficiency-advisor as third teammate.
- **Verifier accepts E2 fallback** — when execution is infeasible (no build system, hypothetical code), E2 code-trace reasoning is accepted with a PARTIAL verdict ceiling.
- **Scratch directory renamed** — `.agents/scratch/` → `.scratch/`. Eliminates namespace collision with `npx skills` (which uses `.agents/skills/`). Add `.scratch` to your project's `.gitignore`.

## 2026-03-08

### Added

- **`do-discuss` skill** — structured problem framing before planning through tiered Socratic dialogue; escalates from conversational to codebase-assisted to multi-perspective exploration as complexity demands
- **`framer` subagent** — perspective-committed problem exploration with three roles (stakeholder-advocate, systems-thinker, skeptic); advisory, peer-reactive
- **Agent teams coverage for do-discuss** — `use-agent-teams` skill now covers do-discuss explore phase alongside existing do-plan and do-execute phases

### Changed

- **Agent roster expanded** — 6 subagents (scout, researcher, planner, debater, inspector, analyst) replace the previous 2 (explorer, reviewer). Each agent has a distinctive cognitive profile: orient → investigate → commit → argue → judge → advise.
- **Agents renamed** — `explorer` → `scout` (avoids collision with builtin Explore type), `reviewer` → `inspector` (clarifies gate-authority role vs advisory analyst).
- **Claude Code plugin** — hooks and `use-agent-teams` skill are now distributed as a Claude Code plugin at `claude/`. Install via `claude plugin marketplace add kenoxa/spine` and `claude plugin install spine@kenoxa`.
- **Installer updated** — `install.sh` attempts plugin installation for Claude Code; falls back to manual hook copy when the CLI doesn't support plugins. References to deleted root `hooks/` directory removed.
- **Session IDs redesigned** — format changed from `{skill}-{YYYYMMDD}-{hash}` to `{YYWW}-{slug}-{hash}` (e.g., `2610-rename-session-ids-a3f2`). Scratch directories are now self-documenting via prompt-derived slugs. Plan and execute share a single session directory instead of creating separate ones. `plan-final.md` renamed to `plan.md`.
- **Documentation aligned** — README, plugin READMEs, and CONTRIBUTING updated to reflect plugin-based distribution.

## 2026-03-07

### Changed

- **Explicit parallel subagent dispatch** — upgraded `do-plan` and `do-execute` with named roles, personas, dedicated output paths (`.agents/scratch/`), and synthesis steps for all subagent phases
- **Skill prefix convention** — non-workflow skills now use `with-*` (domain standards) and `use-*` (active tools) prefixes for better slash-autocomplete grouping. Domain: `with-frontend`, `with-backend`, `with-testing`. Tools: `use-explore`, `use-writing`, `use-skill-craft`. External skills keep their upstream names.

## 2026-03-06

### Initial Release

- **11 skills** — 5 workflow (`do-plan`, `do-execute`, `do-review`, `do-debug`, `do-commit`) + 3 domain (`with-frontend`, `with-backend`, `with-testing`) + 3 tools (`use-explore`, `use-writing`, `use-skill-craft`)
- **2 subagents** — `explorer` (haiku, readonly) for fast codebase navigation and `reviewer` (inherit model) for severity-bucketed code review
- **Cross-platform installer** — auto-detects Cursor, Claude Code, and Codex; installs guardrails, skills, agents, and hooks
- **AGENTS.global.md** — shared guardrails installed as `AGENTS.md` (Cursor/Codex) or `CLAUDE.md` (Claude Code)
- **7 external skill references** — brainstorming, visual-explainer, security-reviewer, frontend-design, wcag-audit-patterns, reducing-entropy, typescript-magician (see `docs/global-skills.md`)
- **Claude Code hook** — SessionStart hook injects project-level `AGENTS.md` files into Claude Code context
- **Evidence-based workflow** — all claims tagged E0–E3; blocking claims require E2+ code evidence

### Improvements

- **Skill frontmatter** — added `name` field to all skill frontmatter for consistent identification across tools
- **Installer reliability** — auto-detects local repo checkout to avoid unnecessary downloads; fixed trap variable scoping for cleanup
- **Quality gates** — `do-plan` and `do-execute` now enforce docs impact classification and test evidence gates before declaring readiness
