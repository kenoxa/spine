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

### PostToolUse hook (check-on-edit)

Runs project-appropriate checkers after file edits (Edit, Write, MultiEdit). Uses a registry-based pattern with `detect_*/run_*` function pairs for easy extensibility.

**Supported checkers:**

| Checker | Detects via | Runs |
|---------|------------|------|
| TypeScript | `tsconfig.json` + `.ts/.tsx/.mts/.cts` file | `tsc --noEmit` |
| Svelte | `svelte.config.*` + `.svelte/.ts/.js` file | `svelte-check` |
| Biome | `biome.json` or `biome.jsonc` | `biome check <file>` |

Automatically detects the project's package manager from lockfiles. Always exits 0 — errors are reported via `systemMessage`, never by exit code. Output is truncated to 20 lines per checker.

To add a new checker, define `detect_<name>` and `run_<name>` functions and append to the `CHECKERS` array.

Configured in [`hooks/hooks.json`](hooks/hooks.json) (30s timeout). Script: [`hooks/check-on-edit.sh`](hooks/check-on-edit.sh).

### `use-agent-teams` skill

Upgrades Spine's parallel subagent dispatch to Claude Code Agent Teams for 4 phases:

| Phase | Why teams over subagents |
|-------|------------------------|
| do-plan Phase 3 (Planning) | Planners share partial findings, build on each other's insights |
| do-plan Phase 4 (Challenge) | Socratic debate with real-time rebuttals |
| do-execute Phase 3 (Polish) | Advisors avoid duplicate findings by seeing each other's output |
| do-execute Phase 4 (Review) | Reviewers coordinate coverage, probe each other's findings |

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Without the env var, this skill has zero effect — Spine's built-in subagent dispatch applies unchanged.

### `run-skill-eval` skill

Optimizes and evaluates changed skill/agent/instruction files in any repo:

| Phase | What happens |
|-------|-------------|
| Detect | Auto-discover changed evaluatable files via `git diff` + `git status` |
| Optimize | Generate 1-3 improved variations per file using use-skill-craft criteria + model intelligence |
| Evaluate | Run all variants (HEAD baseline, working copy, optimizations) through `claude -p` CLI |
| Report | Present comparison via `@visualizer` as interactive HTML |
| Iterate | Refine variations based on user feedback until optimal |

Works in any repo, not spine-specific. Requires the `skill-creator` plugin for grading and benchmarking.

## Structure

```
claude/
├── .claude-plugin/
│   └── plugin.json          Plugin metadata
├── hooks/
│   ├── hooks.json           Hook definitions (SessionStart, PostToolUse)
│   ├── check-on-edit.sh     PostToolUse checker hook
│   └── inject-agents-md.sh  SessionStart hook script
└── skills/
    ├── run-skill-eval/
    │   └── SKILL.md          Skill optimization + evaluation loop
    └── use-agent-teams/
        └── SKILL.md          Agent Teams overlay skill
```
