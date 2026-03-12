# Spine Plugin Marketplace

This directory contains the marketplace definition for the Spine Claude Code plugin.

## Install

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

From a local checkout:

```sh
claude plugin marketplace add ./
claude plugin install spine@kenoxa
```

## What the plugin provides

- **SessionStart hook** — injects project-level `AGENTS.md` files into Claude Code context
- **`use-agent-teams` skill** — upgrades subagent dispatch to Agent Teams for `do-plan` and `do-execute` phases

The plugin source lives at [`../claude/`](../claude/). Cross-platform skills, agents, and guardrails are installed separately via `install.sh`; public manual skill examples use `npx skills add` to match [`skills.sh`](https://skills.sh/), while the installer may bootstrap the same CLI through another launcher.

## Files

- [`marketplace.json`](marketplace.json) — marketplace configuration pointing to `./claude` as the plugin source
- [`../claude/.claude-plugin/plugin.json`](../claude/.claude-plugin/plugin.json) — plugin metadata
- [`../claude/hooks/hooks.json`](../claude/hooks/hooks.json) — hook definitions
