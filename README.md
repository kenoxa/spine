# Spine

Cross-platform AI coding setup for Cursor, Claude Code, and Codex. One set of skills, agents, and guardrails — works everywhere.

## What's Inside

```
AGENTS.global.md        Global guardrails (install as AGENTS.md / CLAUDE.md)
skills/                 11 skills (5 workflow + 5 domain + skill-craft)
agents/                 2 subagents (explorer, reviewer)
hooks/                  Claude Code SessionStart hook for AGENTS.md injection
global-skills.md        External skills to install separately
```

### Skills

| Skill | Type | Purpose |
|-------|------|---------|
| `do-plan` | workflow | Structured planning before complex implementation |
| `do-execute` | workflow | Execute an approved plan through phased quality gates |
| `do-review` | workflow | Severity-bucketed code review |
| `do-debug` | workflow | 4-phase root-cause diagnosis and fix |
| `do-commit` | workflow | Scoped staging with conventional commits |
| `explore` | domain | Bounded codebase navigation and architecture mapping |
| `writing` | domain | Docs, changelogs, ADRs, and prose quality |
| `frontend` | domain | UI development with state coverage and accessibility gates |
| `backend` | domain | APIs, migrations, and security boundaries |
| `testing` | domain | Risk-based test design with perspective tables |
| `skill-craft` | meta | Write, review, or fix skills and AGENTS.md files |

**Workflow skills** are invoked explicitly via `/do-plan`, `/do-execute`, etc.

**Domain skills** are loaded automatically when the task matches their description.

### Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| `explorer` | haiku | Fast, readonly codebase navigation |
| `reviewer` | inherit | Spec compliance review with severity buckets |

## Installation

### Quick Install

Installs guardrails, skills, agents, and hooks for all detected tools (Cursor, Claude Code, Codex):

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
```

Or inspect first:

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh -o install.sh
less install.sh
bash install.sh
```

The installer auto-detects which tools you have (`~/.cursor/`, `~/.claude/`, `~/.codex/`) and installs to all of them. For Claude Code, it also sets up the SessionStart hook and patches `settings.json`.

### Individual Skills

Install specific skills without the full setup:

```sh
npx skills add kenoxa/spine -s do-plan -a '*' -g -y
npx skills add kenoxa/spine -s do-review -a '*' -g -y
```

### Manual Install

Copy files to your tool's config directory. Each tool loads from different paths.

| Source | Cursor | Claude Code | Codex |
|--------|--------|-------------|-------|
| `AGENTS.global.md` | `~/.cursor/AGENTS.md` | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| `skills/` | `~/.cursor/skills/` | `~/.claude/skills/` | `~/.codex/skills/` |
| `agents/` | `~/.cursor/agents/` | `~/.claude/agents/` | `~/.codex/agents/` |

**Claude Code AGENTS.md hook**: Claude Code natively loads `CLAUDE.md` but not `AGENTS.md`. If your projects use `AGENTS.md` files (shared with Cursor/Codex), install the SessionStart hook so Claude Code sees them too:

```sh
mkdir -p ~/.claude/hooks/
cp hooks/inject-agents-md.sh ~/.claude/hooks/
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/inject-agents-md.sh" }]
    }]
  }
}
```

## External Skills

Some skills reference external skills that are too good to distill. Install them separately per `global-skills.md`. These are optional — local skills work without them but reference them for specialized tasks.

## Design Principles

- **Authoring test**: Every skill must address a task an LLM demonstrably handles worse without explicit guidance. No skills for general knowledge.
- **Cross-platform**: No tool-specific formats. Skills, agents, and AGENTS.md work in Cursor, Claude Code, and Codex.
- **Progressive disclosure**: AGENTS.md is minimal. Skills load on demand. Reference files extract detail from skill bodies.
- **Evidence-based**: Claims in plans, reviews, and execution must be tagged E0–E3. Blocking claims require code evidence (E2+).
