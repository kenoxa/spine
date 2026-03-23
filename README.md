# Spine

> **Same skills, same workflow, every provider.**

Spine is a shared AI coding setup for Cursor, Claude Code, Codex, and Qwen Code. It gives each tool the same workflow skills, subagents, guardrails, and MCP defaults so you can move between providers without rebuilding your operating model.

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

Install and sign in to the provider tools you want Spine to configure first. Spine does not install Cursor, Claude Code, Codex, or Qwen Code for you.

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
<summary id="codex-cross-provider-setup">Codex cross-provider setup</summary>

Spine's envoy skill can invoke Claude Code from within a Codex session. On macOS, Codex runs shell commands inside a [Seatbelt sandbox](https://developer.apple.com/documentation/security/app-sandbox) that blocks macOS Keychain access. Claude Code stores OAuth credentials in Keychain, so `claude auth status` fails under the default sandbox.

To enable cross-provider invocation, relax the sandbox in `~/.codex/config.toml`:

```toml
sandbox_mode = "danger-full-access"
approval_policy = "on-request"          # keeps human-in-the-loop approval
```

Or per-session via CLI flag:

```sh
codex -s danger-full-access
```

| Setting | What it does |
|---------|-------------|
| `sandbox_mode` | `read-only` (default), `workspace-write`, or `danger-full-access` (disables Seatbelt) |
| `approval_policy` | `untrusted` (ask every command), `on-failure`, `on-request` (auto within boundaries), `never` |

`danger-full-access` disables the Seatbelt sandbox entirely — shell commands run with full system access. Keep `approval_policy = "on-request"` so Codex still asks before running unexpected commands.

This is only required for cross-provider envoy (Codex calling Claude). Standard Codex usage and Claude calling Codex work without this change.

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
/do-discuss -> /do-plan -> /do-execute -> /commit
```

## What You Get

- A shared workflow: `do-discuss`, `do-plan`, `do-execute`, `commit`
- Utility skills for review, debugging, polish, insights, and recap
- Shared guardrails through `SPINE.md` and your own global overrides through `AGENTS.md`
- Shared subagents in `agents/`
- Context7 and Exa MCP server setup
- Claude Code plugin support for hooks and skills

See [docs/skills-reference.md](docs/skills-reference.md) for the full skill and subagent catalog.

## How Spine Installs

Spine uses `~/.config/spine/` as the central source of truth.

| Path | Purpose |
|------|---------|
| `~/.config/spine/SPINE.md` | Shared guardrails synced from this repo |
| `~/.config/spine/AGENTS.md` | Your global customizations; created once and left alone |
| `~/.config/spine/agents/` | Canonical agent files used across providers |
| `~/.config/spine/.env` | API keys and model overrides (seeded from `.env.example` on first install) |
| `~/.cursor/AGENTS.md` | References `SPINE.md` and `AGENTS.md` |
| `~/.claude/CLAUDE.md` | References `SPINE.md` and `AGENTS.md` |
| `~/.codex/AGENTS.md` | References `SPINE.md` and `AGENTS.md` |

The installer preserves existing provider root-file content when possible by upgrading or prepending the `@~/.config/spine/...` references instead of assuming a blank file.

Agents are linked (Claude Code symlinks) or generated (Cursor `.md` copies with provider-mapped model values, Codex TOML role configs) from the provider directories back to `~/.config/spine/agents/`.

If `~/.config/spine/.env` exists, the installer reads it for MCP authentication. On zsh systems it may also add a `source ~/.config/spine/.env` line to `~/.zshenv` so future shells expose those variables.

## Workflow

1. **[Discuss](docs/skills-reference.md#do-discuss)** with `/do-discuss` to frame the problem. Handles vague inputs, multi-session scoping, and per-phase discussion when a spec exists.
2. **[Plan](docs/skills-reference.md#do-plan)** with `/do-plan` to produce an executable implementation plan.
3. **[Execute](docs/skills-reference.md#do-execute)** with `/do-execute` once the plan is approved.
4. **[Commit](docs/skills-reference.md#commit)** with `/commit` when the change is ready to stage and ship.

Skills write session artifacts to `.scratch/` during planning and execution. Keep `.scratch/` in your project `.gitignore`.

Useful categories:

- `run-*`: standalone utilities like explore, review, debug, polish, insights, and recap
- `with-*`: automatic domain standards such as frontend, backend, terminology, and testing
- `use-*`: active tools such as `use-writing`, `use-skill-craft`, and `use-envoy`

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
mkdir -p ~/.config/spine/agents ~/.cursor/agents ~/.claude/agents ~/.codex/agents ~/.qwen/agents
cp SPINE.md ~/.config/spine/SPINE.md
touch ~/.config/spine/AGENTS.md
cp agents/*.md ~/.config/spine/agents/

printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.cursor/AGENTS.md
printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.claude/CLAUDE.md
printf '%s\n' '@~/.config/spine/SPINE.md' '@~/.config/spine/AGENTS.md' > ~/.codex/AGENTS.md

# Claude Code: symlink agents
for agent in ~/.config/spine/agents/*.md; do
  ln -sf "../../.config/spine/agents/$(basename "$agent")" ~/.claude/agents/
done
# Cursor/Codex: use install.sh — it generates provider-mapped copies
# (Cursor: .md with mapped models; Codex: TOML with mapped model + effort)
```

If a provider root file already exists, add the two `@~/.config/spine/...` lines at the top instead of blindly overwriting your file.

</details>

<details>
<summary>Installer-managed host CLI tools</summary>

The installer manages one list of CLI tools. On macOS, it uses Homebrew to install missing tools when formulae are available.

| Tool | Purpose |
|------|---------|
| `git` | Version control |
| `jq` | JSON processing |
| `node` | JavaScript runtime for `skills` tooling and public `npx skills` commands |
| `python3` | Python 3.9+ runtime in Spine's managed Python toolchain; needed on `PATH` for session-history and reporting skills such as `run-insights` and `run-recap` |
| `uv` | Python package and project manager in Spine's managed Python toolchain; not a direct runtime requirement of `run-insights` or `run-recap` today |
| `ast-grep` | AST-based structural code search and refactoring |
| `bun` | Fast JavaScript runtime and package manager |
| `coreutils` | GNU core utilities on macOS |
| `fd` | Fast file finder |
| `ni` | Universal JavaScript package manager wrapper |
| `ripgrep` | Fast text search |
| `sd` | In-place pattern replacement |
| `shellcheck` | Shell script linter |
| `shfmt` | Shell script formatter |

`pip` is not installed as a separate tool. It comes from Python 3 as `pip3` or `python3 -m pip`.

If your environment exposes only `python`, Spine treats it as satisfying the managed `python3` requirement only when it is Python 3.9 or newer.

On Linux without Homebrew, the installer prints example manual install hints instead of auto-installing packages.

**Recommended but not managed:** [`gh`](https://cli.github.com/) (GitHub CLI) — provides reliable GitHub content fetching when raw URL access is flaky. Requires `gh auth login` after install.

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
<summary>Envoy model overrides</summary>

The envoy skill defaults to high-capability models per provider. Override via `~/.config/spine/.env`:

```sh
# Format: model[:effort]  (effort defaults to "high" if omitted)
export SPINE_ENVOY_CLAUDE=opus:high
export SPINE_ENVOY_CODEX=gpt-5.4:high

# Cursor-agent fallback models (used when primary provider is unavailable)
export SPINE_ENVOY_CLAUDE_CURSOR_FALLBACK=composer-2
export SPINE_ENVOY_CODEX_CURSOR_FALLBACK=composer-2
```

See [`env.example`](env.example) for the full template.

</details>

<details>
<summary>Claude Code plugin</summary>

Spine ships a Claude Code plugin with hooks and skills. The installer attempts this automatically for Claude Code users.

Manual install:

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

See [claude/README.md](claude/README.md) for plugin details and fallback installation.

</details>

<details>
<summary>Browser access (agent-browser)</summary>

Spine installs [agent-browser](https://github.com/vercel-labs/agent-browser) via Homebrew and the `agent-browser` skill via the skills CLI. Agents can use browser automation for web interaction, testing, and debugging.

After installation, download Chrome for Testing (~500MB, one-time):

```sh
agent-browser install
```

Manual skill install:

```sh
npx skills add vercel-labs/agent-browser -s agent-browser -a '*' -g -y
```

**Note:** Browser automation is not available in Codex sandboxed mode. Enable `danger-full-access` mode if required.

</details>

<details>
<summary>Model selection</summary>

**Standard tier is the recommended default** (sonnet / gpt-5.4 / composer-2). Subagents use specialized models by tier automatically — frontier for gate authority, fast for recon — regardless of your session choice.

Upgrade to Frontier for ambiguous requirements, cascading architectural decisions, or elusive root causes. Claude Code and Codex have generous rolling budgets (5h/7d); Cursor has a tighter monthly cap — stay on composer-2, upgrade selectively.

For the full guide — tier mapping, provider pricing, env overrides, and benchmarks — see [docs/model-selection.md](docs/model-selection.md).

</details>

## Troubleshooting And Updates

- Re-run `./install.sh` after pulling new changes to sync guardrails, agents, MCP registration, and skills.
- If Claude Code or Codex were skipped, make sure the `claude` or `codex` CLI is installed and available on `PATH`.
- If Codex's envoy fails with "Keychain access blocked by Seatbelt sandbox", see [Codex cross-provider setup](#codex-cross-provider-setup).
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
