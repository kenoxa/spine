# Spine

> **Same skills, same workflow, every provider.**

Spine is a shared AI coding setup for Cursor, Claude Code, Codex, and OpenCode. It gives each tool the same workflow skills, subagents, guardrails, and MCP defaults so you can move between providers without rebuilding your operating model.

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

Install and sign in to the provider tools you want Spine to configure first. Spine does not install provider CLIs for you.

<details>
<summary><strong>Supported Providers</strong></summary>

| Provider | CLI | Host | Skills | Subagents | Envoy | Notes |
|----------|-----|------|--------|-----------|-------|-------|
| **Claude Code** | `claude` | Full | Full | Full | Default | Primary recommended. SWE-Bench 80.8% (Opus). |
| **Codex** | `codex` | Full | Full | Full | Default | Strongest agentic tool use (Terminal-Bench 75.1%). |
| **Cursor** | `cursor-agent` | Full | Full | Partial¹ | Default | Best IDE integration. Monthly cap. |
| **OpenCode** | `opencode` | Full | Full | Full | Availability-gated | Multi-model gateway (GLM, MiniMax). Go subscription + Free tier. |

¹ Legacy plans ignore subagent model config.

**Envoy** dispatches cross-provider perspectives during design and review. Default: 3 core providers (`claude`, `codex`, `cursor`) + availability-gated `opencode`. Override with `SPINE_ENVOY_PROVIDERS`.

For tier-to-model mappings, pricing, and benchmarks see [docs/model-selection.md](docs/model-selection.md).

</details>

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

<details>
<summary>OpenCode</summary>

```sh
brew install anomalyco/tap/opencode
opencode providers
```

OpenCode is a multi-model gateway supporting GLM, MiniMax, and many others. Spine uses two pricing tiers:
- **Go subscription** (`opencode-go/` prefix) — included in subscription, free at margin
- **Free** (`opencode/` prefix with `-free` suffix) — zero cost Zen models

See [opencode.ai/docs/models](https://opencode.ai/docs/models/) for the full model catalog.

</details>

### Install Spine

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
```

The installer configures every supported tool it can detect:

- Cursor via `~/.cursor/`
- Claude Code via the `claude` CLI on `PATH`
- Codex via the `codex` CLI on `PATH`
- OpenCode via the `opencode` CLI on `PATH`

For Claude Code, the installer also attempts to install the [Spine plugin](claude/README.md).

### Start Using It

Use your provider in its most autonomous mode:

- Cursor: agent mode
- Claude Code: auto-accept edits
- Codex: full auto mode

Then start from the workflow:

```text
/do -> /do-frame -> /do-design -> /do-build -> /commit
```

## What You Get

- A shared workflow: `do-frame`, `do-design`, `do-build`, `commit` (or `/do` as single entry point)
- Utility skills for review, debugging, polish, insights, and recap
- Shared guardrails through `SPINE.md` and your own global overrides through `AGENTS.md`
- Shared subagents in `agents/`
- Context7 and Exa MCP server setup
- [RTK](https://github.com/rtk-ai/rtk) token optimization proxy — reduces LLM context usage by 60-90% on tool outputs (auto-configured per provider)
- Cross-provider hooks — security guards, type context injection, post-edit checking, and session augmentation installed per provider (see [Hooks installed](#hooks-installed))
- Claude Code plugin support for hooks and skills

See [docs/skills-reference.md](docs/skills-reference.md) for the full skill and subagent catalog.

<a id="how-spine-installs"></a>
<details>
<summary><strong>How Spine Installs</strong></summary>

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

Agents are linked (Claude Code symlinks) or generated (Cursor `.md`, Codex TOML, OpenCode `.md` with model field) from the provider directories back to `~/.config/spine/agents/`.

If `~/.config/spine/.env` exists, the installer reads it for MCP authentication. On zsh systems it may also add a `source ~/.config/spine/.env` line to `~/.zshenv` so future shells expose those variables.

</details>

## Workflow

1. **[Frame](docs/skills-reference.md#do-frame)** with `/do-frame` to define the problem, constraints, and success criteria.
2. **[Design](docs/skills-reference.md#do-design)** with `/do-design` to compare approaches and get a cross-model recommendation.
3. **[Build](docs/skills-reference.md#do-build)** with `/do-build` to prototype, review, and polish.
4. **[Commit](docs/skills-reference.md#commit)** with `/commit` when the change is ready to stage and ship.

Or use `/do` as a single entry point that routes through all three phases.

**Session model:** Standard is the default (sonnet:medium / gpt-5.4:medium / auto). Switch via your provider's model selector or `--model` flag when launching. See [docs/model-selection.md](docs/model-selection.md) for when to upgrade to Frontier and when to step down to Fast.

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
npx skills add kenoxa/spine -s do-build -a '*' -g -y
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
| `yq` | YAML processing |
| `node` | JavaScript runtime for `skills` tooling and public `npx skills` commands |
| `python3` | Python 3.9+ runtime in Spine's managed Python toolchain; needed on `PATH` for session-history and reporting skills such as `run-insights` and `run-recap` |
| `uv` | Python package and project manager in Spine's managed Python toolchain; not a direct runtime requirement of `run-insights` or `run-recap` today |
| `ast-grep` | AST-based structural code search and refactoring |
| `bun` | Fast JavaScript runtime and package manager |
| `coreutils` | GNU core utilities on macOS |
| `fd` | Fast file finder |
| `ni` | Universal JavaScript package manager wrapper |
| `probe` | Semantic code search (BM25 + tree-sitter AST) |
| `ripgrep` | Fast text search |
| `rtk` | Token-optimized CLI proxy — rewrites tool output before it reaches the LLM context |
| `sd` | In-place pattern replacement |
| `shellcheck` | Shell script linter |
| `shfmt` | Shell script formatter |

`pip` is not installed as a separate tool. It comes from Python 3 as `pip3` or `python3 -m pip`.

`probe` has no Homebrew formula — the installer downloads the binary directly from GitHub Releases to `~/.local/bin/probe` and caches the installed version in `~/.config/spine/tool-versions` to skip redundant downloads.

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
<summary id="hooks-installed">Hooks installed</summary>

The installer copies shared hooks to `~/.config/spine/hooks/` with shebang rewriting, then generates provider-specific hook configs. TypeScript hooks that use local modules (for example `inject-types-on-read.ts` plus the `inject-types/` directory) are copied as a tree so imports resolve after install. Not all providers support all hook events.

| Hook | Event | What it does |
|------|-------|-------------|
| `guard-shell` | PreToolUse (Bash) | Security deny-list: blocks recursive `rm`, docker container escapes (run + exec), file uploads via curl/wget. RTK-rewrite agnostic. |
| `guard-read-large` | PreToolUse (Read) | Warns when reading files >2000 lines without a `limit` parameter. Prevents context window waste. |
| `inject-types-on-read` | PostToolUse (Read) | Injects symbol/signature context into reads for JS/TS/Svelte, Python, and Java files via `probe symbols` (tree-sitter). |
| `check-on-edit` | PostToolUse (Edit/Write/MultiEdit) | Runs `tsc`, `svelte-check`, and `biome` after file edits. Registry-based — easy to extend. |
| `inject-agents-md` | SessionStart | Injects project `AGENTS.md` into session context (Claude Code only — other providers load it natively). |
| `inject-compact-essentials` | SessionStart | Reinjects essential context on compaction events. |
| `pre-compact` | PreCompact | Prompts a handoff artifact before context compaction as a safety net. |

**Provider compatibility:**

| Hook | Claude | Codex | Cursor | OpenCode |
|------|--------|-------|--------|----------|
| `guard-shell` | ✓ | ✓ | ✓ | ✓ |
| `guard-read-large` | ✓ | ✓ | ✓ | ✓ |
| `inject-types-on-read` | ✓ | ‒ | ✓ | ✓ |
| `check-on-edit` | ✓ | ‒ | ✓ | ✓ |
| `inject-agents-md` | ✓ | ‒ | ‒ | ‒ |
| `inject-compact-essentials` | ✓ | ‒ | ‒ | ‒ |
| `pre-compact` | ✓ | ‒ | ‒ | ‒ |

Codex PostToolUse is Bash-only — `inject-types-on-read` and `check-on-edit` are deferred until Codex supports Read/Edit PostToolUse events. OpenCode uses an in-process TS plugin (`opencode/spine-hooks.ts`) that delegates to the shared shell hooks.

All hooks fail open on missing dependencies (jq, bun, probe) — warnings only, never workflow-blocking. Security and context guards (`guard-shell`, `guard-read-large`) intentionally block when triggered.

</details>

<details>
<summary>Envoy model overrides</summary>

The envoy skill defaults to high-capability models per provider. Override via `~/.config/spine/.env`:

```sh
# Format: model[:effort]  (effort defaults to "high" if omitted)
export SPINE_ENVOY_CLAUDE=opus:high
export SPINE_ENVOY_CODEX=gpt-5.4:high
export SPINE_ENVOY_OPENCODE=opencode-go/glm-5:high

# Per-tier overrides: SPINE_ENVOY_{TIER}_{PROVIDER}=model:effort
export SPINE_ENVOY_FAST_OPENCODE=opencode/minimax-m2.5-free:minimal
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
<summary>Browser access (dev-browser)</summary>

Spine installs [dev-browser](https://github.com/SawyerHood/dev-browser) as a standalone binary to `~/.local/bin/` and provides the local `use-browser` skill. Scripts are passed as Playwright JavaScript via stdin heredoc and run in a QuickJS WASM sandbox.

First-time setup downloads Playwright Chromium (~500MB, one-time):

```sh
dev-browser install
```

**Note:** Browser automation is not available in Codex sandboxed mode. Enable `danger-full-access` mode if required.

</details>

<details>
<summary>Model selection</summary>

**Standard tier is the recommended default** (sonnet:medium / gpt-5.4:medium / auto). Subagents use specialized models by tier automatically — frontier for gate authority and synthesis, standard for `@implementer`, fast for recon — regardless of your session choice.

**When to upgrade the session (mainthread) to Frontier:** ambiguous requirements, cascading architectural decisions, elusive root causes, very large accumulated context (~50K+ tokens across subagent work), or tangled phase gates. **When implementation alone needs more:** cross-cutting multi-file refactors that outrun the design artifact — escalate `@implementer` workload or partition scope (see [docs/model-tier-assignments.md](docs/model-tier-assignments.md)); that is not always the same as upgrading the orchestrator.

Claude Code and Codex have generous rolling budgets (5h/7d); Cursor has a tighter monthly cap — stay on auto, upgrade selectively to composer-2.

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
