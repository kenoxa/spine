# Contributing

## Repo Structure

```
SPINE.md                Global guardrails (installed to ~/.config/spine/SPINE.md)
skills/                 20 skills (11 workflow + 3 domain + 6 tools)
agents/                 13 subagents
claude/                 Claude Code plugin (hooks + skills)
docs/                   Reference docs (skills, tips, external skills)
.scratch/               Ephemeral subagent output (gitignored)
```

## Adding a Skill

Use `/use-skill-craft` — it covers the full authoring workflow. Key points:

1. **Pass the authoring test**: Would an LLM perform the task worse without this skill? If the agent can figure it out from general knowledge or target files, don't create the skill.
2. **Structure**: `frontmatter → overview → core directives → anti-patterns`. No other sections unless prerequisites require it.
3. **Be concrete**: Vague directives fail the authoring test. "Handle errors properly" is cut. "Fail-closed: deny by default, allowlist explicitly" stays.
4. **Size**: Under 5000 tokens. Extract examples and templates to `references/` if needed. Never nest deeper than `SKILL.md → references/file.md`.
   All size thresholds use token counts (o200k_base encoding). Verify with any o200k_base tokenizer (e.g., `tokenizer -f <file> -m gpt-4.1`; installed by `install.sh` or `brew install zahidcakici/tap/tokenizer`).
5. **Scripts**: Acceptable when the task involves processing data volumes exceeding LLM context limits. Place in `scripts/` subdirectory of the skill. Document runtime requirements (e.g., Python 3.9+) in the skill description. Keep scripts stdlib-only — no package-manager dependencies.

### Frontmatter

```yaml
---
name: skill-name
description: >
  What it does. Use when [triggers]. Do NOT use when [exclusions].
argument-hint: "[what the user passes after /skill-name]"
---
```

Optional fields:
- `disable-model-invocation: true` — only loaded via slash command, never auto-applied

### Referencing External Skills

If a skill benefits from an external skill (too complex to distill), add a reference line in the skill body and register it in `[docs/global-skills.md](docs/global-skills.md)`.

To install all referenced external skills manually:

```sh
npx skills add obra/superpowers -s brainstorming -a '*' -g -y
npx skills add nicobailon/visual-explainer -s visual-explainer -a '*' -g -y
npx skills add jeffallan/claude-skills -s security-reviewer -a '*' -g -y
npx skills add anthropics/claude-code -s frontend-design -a '*' -g -y
npx skills add wshobson/agents -s wcag-audit-patterns -a '*' -g -y
npx skills add softaworks/agent-toolkit -s reducing-entropy -a '*' -g -y
npx skills add mcollina/skills -s typescript-magician -a '*' -g -y
npx skills add trailofbits/skills -s differential-review -a '*' -g -y
npx skills add trailofbits/skills -s fp-check -a '*' -g -y
```

Public manual examples intentionally use `npx skills add` to match [`skills.sh`](https://skills.sh/). The installer may bootstrap the same CLI through another launcher.

See [docs/global-skills.md](docs/global-skills.md) for which local skills reference each external skill.

## Editing SPINE.md

This file is installed to `~/.config/spine/SPINE.md` and referenced via `@~/.config/spine/SPINE.md` from each provider's root file (CLAUDE.md, AGENTS.md). It's read on every invocation — keep it minimal.

- Only add instructions relevant to **every single task**
- Domain-specific content belongs in skills, not here
- If content fits an existing skill, put it there instead

## Adding a Subagent

Subagents go in `agents/`. Use cross-platform frontmatter:

```yaml
---
name: agent-name
description: >
  When to use. What it does.
model: haiku          # or inherit (default)
readonly: true        # Cursor only; omit for agents that write to .scratch/
skills:
  - skill-to-preload  # Claude Code only; Cursor ignores
---
```

Keep subagent bodies focused — they should define constraints and output format, not duplicate the skill content they preload.

For Codex, the installer generates TOML role configs from markdown source automatically — no manual TOML authoring needed.

### Renaming an Agent

1. `git mv agents/old.md agents/new.md` and update `name:` in frontmatter
2. Update all `@old` dispatch refs in skills and docs
3. Add `"old"` to `RETIRED_AGENT_NAMES` in `install.sh` (mirrors `RETIRED_MCP_SERVERS`)
4. Re-run `install.sh` — cleanup removes stale files across all providers

## Installer (`install.sh`)

The install script downloads spine and sets up the central directory, provider links, MCP servers, and skills. For Claude Code, it also installs the Spine plugin.

**What it does** (8 steps):
1. Checks system dependencies — installs missing tools via Homebrew on macOS
2. Downloads the repo via `git clone --depth 1` (or `curl` tarball fallback)
3. Sets up `~/.config/spine/` with `SPINE.md` and `agents/*.md` (user-owned copies)
4. Detects tools by checking for `~/.cursor/`, `~/.claude/`, `~/.codex/`
5. Writes `@~/.config/spine/SPINE.md` and `@~/.config/spine/AGENTS.md` references to each provider's root file (preserves user content), symlinks agents (Claude/Cursor) or generates TOML role configs (Codex), and for Claude Code installs the Spine plugin
6. Configures Context7 + Exa MCP servers (`install_mcp_servers()`) — CLI commands for Claude Code/Codex, jq patch for Cursor
7. Installs skills via the `skills` CLI with its own launcher fallback (local spine skills + global external skills)
8. Cleans up stale symlinks and backup files

**When to update**:
- Adding a new supported tool → add detection in `detect_tools()` and install logic in `install_tool()`
- Changing the guardrails filename → update `setup_central_dir()` and `install_tool()`
- Changing plugin hooks → update `claude/hooks/hooks.json` and `claude/hooks/`
- Changing plugin metadata → update `claude/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
- Adding/removing MCP servers → update `install_mcp_servers()` and `RETIRED_MCP_SERVERS`

**Testing**: Run with `HOME=$(mktemp -d) bash install.sh` to verify in an isolated environment.

### Tips

- **Re-run to update** — run `./install.sh` again after pulling new changes to sync skills, guardrails, and agents. Your `~/.config/spine/` directory is updated, and provider root files are left untouched if they already contain the `@` reference.
- **Individual skills** — install just the skills you need via `npx skills add kenoxa/spine -s <skill-name> -a '*' -g -y`

### Renaming or Removing a Skill

- **Local skill (in `skills/`)**: delete or rename the skill directory, then re-run `install.sh`. The manifest diff detects the old name as an orphan and removes `~/.agents/skills/<old-name>` automatically. The resulting broken symlink in `~/.{claude,cursor,codex}/skills/` is swept by `cleanup_stale_files()`.
- **Global/external skill (`GLOBAL_SKILLS[]`)**: update the array entry and add the old name to `RETIRED_GLOBAL_SKILLS` in `install_skills()`. The lockfile-based mechanism handles removal.
- **Note**: public docs use `npx skills remove`, but do not use it for local spine skills — it is a no-op for local-path installs.

## Review Checklist

Before submitting changes:

- [ ] Every skill line passes the authoring test
- [ ] No tool-specific references (k5-*, nestor, dotcursor)
- [ ] Anti-patterns are one line each
- [ ] Cross-references to global skills are registered in `docs/global-skills.md`
- [ ] SPINE.md stays under ~1800 tokens
