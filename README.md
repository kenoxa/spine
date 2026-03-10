# Spine

> **Same skills, same workflow — every developer, every tool.**

AI coding setup for Cursor, Claude Code, and Codex. One set of skills, agents, and guardrails that works everywhere.

## Contents

- [Quick Start](#quick-start)
- [Workflow](#workflow)
- [Skills and Agents](#skills-and-agents)
- [Tips](#tips)
- [Design Principles](#design-principles)
- [Further Reading](#further-reading)

## Quick Start

> **If it's worth changing, it's worth planning.**

Installs guardrails, skills, agents, and hooks for all detected tools (Cursor, Claude Code, Codex):

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
```

The installer auto-detects which tools you have (`~/.cursor/`, `~/.claude/`, `~/.codex/`) and installs to all of them. For Claude Code, it also installs the [Spine plugin](#claude-code-plugin) (hooks and `use-agent-teams` skill).

<details>
<summary>Inspect before running</summary>

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh -o install.sh
less install.sh
bash install.sh
```

</details>

<details>
<summary>Local checkout (recommended for contributors)</summary>

Clone the repo for editing, testing, and iterating on skills before syncing:

```sh
git clone https://github.com/kenoxa/spine.git
cd spine
./install.sh
```

</details>

<details>
<summary>Install individual skills</summary>

Install specific skills without the full setup:

```sh
npx skills add kenoxa/spine -s do-plan -a '*' -g -y
npx skills add kenoxa/spine -s do-review -a '*' -g -y
```

</details>

<details>
<summary>Manual install</summary>

Set up the central directory and reference it from each tool:

```sh
# 1. Copy guardrails and agents to the central directory
mkdir -p ~/.config/spine/agents
cp SPINE.md ~/.config/spine/SPINE.md
cp agents/*.md ~/.config/spine/agents/

# 2. Reference from each tool's root file (add your own instructions below the @ line)
echo '@~/.config/spine/SPINE.md' > ~/.cursor/AGENTS.md
echo '@~/.config/spine/SPINE.md' > ~/.claude/CLAUDE.md
echo '@~/.config/spine/SPINE.md' > ~/.codex/AGENTS.md

# 3. Symlink agents (or copy with: cp ~/.config/spine/agents/*.md ~/.<tool>/agents/)
for agent in ~/.config/spine/agents/*.md; do
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.cursor/agents/
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.claude/agents/
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.codex/agents/
done
```

Skills are installed separately via `npx skills add` (see above).

**Claude Code plugin:** Install the Spine plugin for hooks and the `use-agent-teams` skill:

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

If your Claude Code CLI doesn't support plugins, install the AGENTS.md hook manually:

```sh
mkdir -p ~/.claude/hooks/
cp claude/hooks/inject-agents-md.sh ~/.claude/hooks/
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

</details>

> **Use agent mode.** Spine expects your AI tool to run in its most autonomous
> mode — Cursor agent mode, Claude Code with auto-accept, or Codex auto mode.
> Spine's skills replace built-in plan modes. See [Tips](docs/tips.md#agent-mode)
> for details.

## Workflow

> **Measure twice, ship once.**

Four steps from idea to commit:

1. **[Discuss](docs/skills-reference.md#do-discuss)** (`/do-discuss`) — frame the problem when it's vague or ambiguous
2. **[Plan](docs/skills-reference.md#do-plan)** (`/do-plan`) — draft and validate an implementation plan
3. **[Execute](docs/skills-reference.md#do-execute)** (`/do-execute`) — phased implementation with built-in review and verification
4. **[Commit](docs/skills-reference.md#do-commit)** (`/do-commit`) — stage scoped files and commit with a conventional message

Refine the plan via messages between steps 2 and 3. For straightforward tasks, start directly with `/do-execute` — it handles planning inline when no plan exists.

Skills store intermediate output in `.scratch/` during planning and execution — ephemeral, safe to delete between sessions; during a session the log provides observability. Add `.scratch/` to your `.gitignore`.

```mermaid
graph LR
    A["/do-discuss"] --> B["/do-plan"] --> C["/do-execute"] --> D["/do-commit"]
```

<details>
<summary>Detailed flow with loops</summary>

```mermaid
graph TD
    A[User request] --> B{Problem clear?}
    B -->|No| C[do-discuss]
    C --> D[do-plan]
    B -->|Yes| D
    D --> E{Plan ready?}
    E -->|No| F[Refine via messages]
    F --> D
    E -->|Yes| G[do-execute]
    G --> H{Review + Verify passed?}
    H -->|No| I[Fix findings]
    I --> G
    H -->|Yes| J[do-commit]
```

</details>

## Skills and Agents

Skills use prefixes for quick discovery in slash-autocomplete: `do-` for workflow commands you invoke explicitly, `with-` for domain standards that activate automatically, and `use-` for tools that produce artifacts.

### Workflow skills (`do-*`)

Invoked via slash commands — `/do-plan`, `/do-execute`, etc.

| Skill | Purpose |
|-------|---------|
| [`do-discuss`](docs/skills-reference.md#do-discuss) | Structured problem framing before planning |
| [`do-plan`](docs/skills-reference.md#do-plan) | Structured planning before complex implementation |
| [`do-execute`](docs/skills-reference.md#do-execute) | Execute an approved plan through phased quality gates |
| [`do-review`](docs/skills-reference.md#do-review) | Severity-bucketed code review |
| [`do-debug`](docs/skills-reference.md#do-debug) | 4-phase root-cause diagnosis and fix |
| [`do-polish`](docs/skills-reference.md#do-polish) | Advisory code polish with conventions, complexity, and efficiency lenses |
| [`do-commit`](docs/skills-reference.md#do-commit) | Scoped staging with conventional commits |
| [`do-handoff`](docs/skills-reference.md#do-handoff) | Distill session context into a structured prompt for a fresh session |
| [`do-history-insights`](docs/skills-reference.md#do-history-insights) | Mine cross-tool session history for workflow/setup improvement recommendations (Python 3.9+, Claude Code) |
| [`do-history-recap`](docs/skills-reference.md#do-history-recap) | Summarize work done across AI agent sessions for standups, timesheets, and activity reports |

### Domain standards (`with-*`)

Loaded automatically when the task matches their description — no slash command needed.

| Skill | Purpose |
|-------|---------|
| `with-frontend` | UI development with state coverage and accessibility gates |
| `with-backend` | APIs, migrations, and security boundaries |
| `with-testing` | Risk-based test design with perspective tables |

### Active tools (`use-*`)

Invoked explicitly to produce artifacts or perform discovery.

| Skill | Purpose |
|-------|---------|
| `use-explore` | Bounded codebase navigation and architecture mapping |
| `use-writing` | Docs, changelogs, ADRs, and prose quality |
| `use-skill-craft` | Write, review, or fix skills and AGENTS.md files |

See also: [Subagents](docs/skills-reference.md#subagents) · [Prefix convention](docs/skills-reference.md#skill-prefix-convention) · [External skills](docs/global-skills.md)

<details>
<summary>Claude Code plugin</summary>

### Claude Code Plugin

Spine ships a Claude Code plugin with a SessionStart hook (injects `AGENTS.md` into context) and the `use-agent-teams` skill. The [installer](#quick-start) handles setup automatically.

Manual install: `claude plugin marketplace add kenoxa/spine && claude plugin install spine@kenoxa`

See [`claude/README.md`](claude/README.md) for hook details and fallback installation.

</details>

## Tips

See [Tips](docs/tips.md) for slash command usage, workflow advice, model recommendations, and macOS screenshot shortcuts.

## Design Principles

- **Authoring test**: Every skill must address a task an LLM demonstrably handles worse without explicit guidance. No skills for general knowledge.
- **Cross-platform**: No tool-specific formats. Skills, agents, and SPINE.md work in Cursor, Claude Code, and Codex without modification.
- **Progressive disclosure**: SPINE.md is minimal (~65 lines). Skills load on demand. Reference files extract detail from skill bodies.
- **Evidence-based**: Claims in plans, reviews, and execution must be tagged E0–E3. Blocking claims require code evidence (E2+).
- **Self-contained**: No external registry or manifest system. Skills are plain markdown. The installer is a single bash script.

## Further Reading

- [Skills reference](docs/skills-reference.md) — detailed phase descriptions for each workflow skill
- [Tips](docs/tips.md) — workflow tips, model selection, slash command usage
- [External skills reference](docs/global-skills.md) — optional skills from other repos
- [Contributing guide](CONTRIBUTING.md) — authoring skills, subagents, and installer changes
- [Changelog](CHANGELOG.md) — version history and user-facing changes
- [MIT License](LICENSE)
