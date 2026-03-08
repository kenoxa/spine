# Spine — Claude Code Plugin

Claude Code-specific extensions that don't apply to Cursor or Codex.

## Install

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

The [`install.sh`](../install.sh) script attempts this automatically for Claude Code users.

## Contents

### SessionStart hook

Injects project-level `AGENTS.md` files into Claude Code context. Claude Code natively loads `CLAUDE.md` but not `AGENTS.md` — this hook bridges the gap so projects using `AGENTS.md` (shared with Cursor and Codex) are visible in Claude Code sessions.

Configured in [`hooks/hooks.json`](hooks/hooks.json). Script: [`hooks/inject-agents-md.sh`](hooks/inject-agents-md.sh).

### `use-agent-teams` skill

Upgrades Spine's parallel subagent dispatch to Claude Code Agent Teams for 4 phases:

| Phase | Why teams over subagents |
|-------|------------------------|
| do-plan Phase 3 (Planning) | Planners share partial findings, build on each other's insights |
| do-plan Phase 4 (Challenge) | Socratic debate with real-time rebuttals |
| do-execute Phase 3 (Polish) | Advisors avoid duplicate findings by seeing each other's output |
| do-execute Phase 4 (Review) | Reviewers coordinate coverage, probe each other's findings |

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Without the env var, this skill has zero effect — Spine's built-in subagent dispatch applies unchanged.

## Structure

```
claude/
├── .claude-plugin/
│   └── plugin.json          Plugin metadata
├── hooks/
│   ├── hooks.json           Hook definitions (SessionStart)
│   └── inject-agents-md.sh  Hook script
└── skills/
    └── use-agent-teams/
        └── SKILL.md          Agent Teams overlay skill
```
