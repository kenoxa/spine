# Changelog

All notable changes are documented here, focused on user impact.

## 2026-03-08

### Changed

- **Claude Code plugin** — hooks and `use-agent-teams` skill are now distributed as a Claude Code plugin at `claude/`. Install via `claude plugin marketplace add kenoxa/spine` and `claude plugin install spine@kenoxa`.
- **Installer updated** — `install.sh` attempts plugin installation for Claude Code; falls back to manual hook copy when the CLI doesn't support plugins. References to deleted root `hooks/` directory removed.
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
- **7 external skill references** — brainstorming, visual-explainer, security-reviewer, frontend-design, wcag-audit-patterns, reducing-entropy, typescript-expert (see `global-skills.md`)
- **Claude Code hook** — SessionStart hook injects project-level `AGENTS.md` files into Claude Code context
- **Evidence-based workflow** — all claims tagged E0–E3; blocking claims require E2+ code evidence

### Improvements

- **Skill frontmatter** — added `name` field to all skill frontmatter for consistent identification across tools
- **Installer reliability** — auto-detects local repo checkout to avoid unnecessary downloads; fixed trap variable scoping for cleanup
- **Quality gates** — `do-plan` and `do-execute` now enforce docs impact classification and test evidence gates before declaring readiness
