# Changelog

All notable changes are documented here, focused on user impact.

## 2026-03-06

### Initial Release

- **11 skills** — 5 workflow (`do-plan`, `do-execute`, `do-review`, `do-debug`, `do-commit`) + 5 domain (`explore`, `writing`, `frontend`, `backend`, `testing`) + 1 meta (`skill-craft`)
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
