# Spine

> **Same skills, same workflow, every provider.**

Spine is a shared AI coding setup for Cursor, Claude Code, and Codex. It gives each tool the same workflow skills, subagents, guardrails, and MCP defaults so you can move between providers without rebuilding your operating model.

## Contents

- [Quick Start](#quick-start)
- [What You Get](#what-you-get)
- [How Spine Installs](#how-spine-installs)
- [Workflow](#workflow)
- [Advanced Setup](#advanced-setup)
- [Troubleshooting And Updates](#troubleshooting-and-updates)
- [Contributing](#contributing)
- [Further Reading](#further-reading)

## Quick Start

> **If it's worth changing, it's worth planning.**

Install and sign in to the provider tools you want Spine to configure first. Spine does not install Cursor, Claude Code, or Codex for you.

**Provider Prerequisites**

<details>
<summary>Cursor</summary>

Cursor works with the editor alone. Install the CLI only if you want terminal access to `agent` commands:

```sh
curl https://cursor.com/install -fsS | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshenv
source ~/.zshenv
agent login
```

</details>

<details>
<summary>Codex</summary>

```sh
brew install codex
codex login
```

</details>

<details>
<summary>Claude Code</summary>

```sh
curl -fsSL https://claude.ai/install.sh | bash
claude auth login
```

</details>

### Install Spine

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
```

The installer configures every supported tool it can detect:

- Cursor via `~/.cursor/`
- Claude Code via the `claude` CLI on `PATH`
- Codex via the `codex` CLI on `PATH`

For Claude Code, the installer also attempts to install the [Spine plugin](claude/README.md).

### Start Using It

Use your provider in its most autonomous mode:

- Cursor: agent mode
- Claude Code: auto-accept edits
- Codex: full auto mode

Then start from the workflow:

```text
/do-discuss -> /do-plan -> /do-execute -> /do-commit
```

For straightforward work, start directly with `/do-execute`.

## What You Get

- A shared workflow: `do-discuss`, `do-plan`, `do-execute`, `do-commit`
- Utility skills for review, debugging, polish, insights, and recap
- Shared guardrails through `SPINE.md` and your own global overrides through `AGENTS.md`
- Shared subagents in `agents/`
- Context7 and Exa MCP server setup
- Claude Code plugin support for hooks and `use-agent-teams`

See [docs/skills-reference.md](docs/skills-reference.md) for the full skill and subagent catalog.

## How Spine Installs

Spine uses `~/.config/spine/` as the central source of truth.

| Path | Purpose |
|------|---------|
| `~/.config/spine/SPINE.md` | Shared guardrails synced from this repo |
| `~/.config/spine/AGENTS.md` | Your global customizations; created once and left alone |
| `~/.config/spine/agents/` | Canonical agent files used across providers |
| `~/.config/spine/.env` | Optional API keys for MCP auth |
| `~/.cursor/AGENTS.md` | References `SPINE.md` and `AGENTS.md` |
| `~/.claude/CLAUDE.md` | References `SPINE.md` and `AGENTS.md` |
| `~/.codex/AGENTS.md` | References `SPINE.md` and `AGENTS.md` |

The installer preserves existing provider root-file content when possible by upgrading or prepending the `@~/.config/spine/...` references instead of assuming a blank file.

Agents are linked from the provider directories back to `~/.config/spine/agents/` so updates stay in sync.

If `~/.config/spine/.env` exists, the installer reads it for MCP authentication. On zsh systems it may also add a `source ~/.config/spine/.env` line to `~/.zshenv` so future shells expose those variables.

## Workflow

Spine’s default path is four steps:

1. **[Discuss](docs/skills-reference.md#do-discuss)** with `/do-discuss` when the problem is vague.
2. **[Plan](docs/skills-reference.md#do-plan)** with `/do-plan` before multi-file or higher-risk work.
3. **[Execute](docs/skills-reference.md#do-execute)** with `/do-execute` once the plan is approved.
4. **[Commit](docs/skills-reference.md#do-commit)** with `/do-commit` when the change is ready to stage and ship.

Skills write session artifacts to `.scratch/` during planning and execution. Keep `.scratch/` in your project `.gitignore`.

Useful categories:

- `run-*`: standalone utilities like review, debug, polish, insights, and recap
- `with-*`: automatic domain standards such as frontend, backend, JavaScript, and testing
- `use-*`: active tools such as `use-explore`, `use-writing`, and `use-skill-craft`

## Advanced Setup

<details>
<summary>Inspect before running</summary>

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh -o install.sh
less install.sh
bash install.sh
```

</details>

<details>
<summary>Local checkout</summary>

```sh
git clone https://github.com/kenoxa/spine.git
cd spine
./install.sh
```

</details>

<details>
<summary>Install individual skills</summary>

```sh
npx skills add kenoxa/spine -s do-plan -a '*' -g -y
npx skills add kenoxa/spine -s run-review -a '*' -g -y
```

Public manual examples use `npx skills add` to match [skills.sh](https://skills.sh/). The installer can bootstrap the same `skills` CLI through another launcher.

</details>

<details>
<summary>Manual install</summary>

Fresh-setup example:

```sh
mkdir -p ~/.config/spine/agents ~/.cursor/agents ~/.claude/agents ~/.codex/agents
cp SPINE.md ~/.config/spine/SPINE.md
touch ~/.config/spine/AGENTS.md
cp agents/*.md ~/.config/spine/agents/

printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.cursor/AGENTS.md
printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.claude/CLAUDE.md
printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.codex/AGENTS.md

for agent in ~/.config/spine/agents/*.md; do
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.cursor/agents/
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.claude/agents/
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.codex/agents/
done
```

If a provider root file already exists, add the two `@~/.config/spine/...` lines at the top instead of blindly overwriting your file.

</details>

<details>
<summary>CLI tools installed by the installer</summary>

The installer checks for these tools and installs missing ones via Homebrew on macOS:

| Tool | Category | Purpose |
|------|----------|---------|
| `git` | Required | Version control |
| `jq` | Required | JSON processing |
| `node` | Required | JavaScript runtime for `skills` tooling and public `npx skills` commands |
| `ast-grep` | Recommended | AST-based structural code search and refactoring |
| `bun` | Recommended | Fast JavaScript runtime and package manager |
| `coreutils` | Recommended | GNU core utilities on macOS |
| `fd` | Recommended | Fast file finder |
| `ni` | Recommended | Universal JavaScript package manager wrapper |
| `ripgrep` | Recommended | Fast text search |
| `sd` | Recommended | In-place pattern replacement |
| `shellcheck` | Recommended | Shell script linter |
| `shfmt` | Recommended | Shell script formatter |

On Linux without Homebrew, the installer prints manual install hints.

</details>

<details>
<summary>MCP servers installed</summary>

The installer registers these MCP servers:

| Server | Tools Provided | URL |
|--------|---------------|-----|
| Context7 | `resolve-library-id`, `query-docs` | `https://mcp.context7.com/mcp` |
| Exa | `web_search_exa`, `get_code_context_exa` | `https://mcp.exa.ai/mcp?tools=get_code_context_exa,web_search_exa` |

Both work keyless by default. For higher rate limits, set API keys in `~/.config/spine/.env`:

```sh
export CONTEXT7_API_KEY=your-key-here
export EXA_API_KEY=your-key-here
```

</details>

<details>
<summary>Claude Code plugin</summary>

Spine ships a Claude Code plugin with hooks and the `use-agent-teams` skill. The installer attempts this automatically for Claude Code users.

Manual install:

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

See [claude/README.md](claude/README.md) for plugin details and fallback installation.

</details>

## Troubleshooting And Updates

- Re-run `./install.sh` after pulling new changes to sync guardrails, agents, MCP registration, and skills.
- If Claude Code or Codex were skipped, make sure the `claude` or `codex` CLI is installed and available on `PATH`.
- If Cursor works in the editor but `agent` is missing in the terminal, add `~/.local/bin` to `PATH` and open a new shell.
- If MCP auth is not applied, check `~/.config/spine/.env` and your shell environment. On zsh, the installer may add a source line to `~/.zshenv`.
- If Claude plugin installation fails, Spine falls back to the manual hook path described in [claude/README.md](claude/README.md).
- For operating tips such as agent mode, screenshot shortcuts, and model guidance, see [docs/tips.md](docs/tips.md).

## Contributing

For skill authoring, agent changes, installer maintenance, and repo conventions, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Further Reading

- [docs/skills-reference.md](docs/skills-reference.md) for workflow phases, skill details, and subagent roles
- [docs/tips.md](docs/tips.md) for operating advice and provider mode guidance
- [docs/global-skills.md](docs/global-skills.md) for optional external skills
- [claude/README.md](claude/README.md) for Claude Code plugin behavior and hooks
- [CHANGELOG.md](CHANGELOG.md) for user-facing changes
- [MIT License](LICENSE)
