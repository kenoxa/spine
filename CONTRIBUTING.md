# Contributing

## Adding a Skill

Use `/use-skill-craft` — it covers the full authoring workflow. Key points:

1. **Pass the authoring test**: Would an LLM perform the task worse without this skill? If the agent can figure it out from general knowledge or target files, don't create the skill.
2. **Structure**: `frontmatter → overview → core directives → anti-patterns`. No other sections unless prerequisites require it.
3. **Be concrete**: Vague directives fail the authoring test. "Handle errors properly" is cut. "Fail-closed: deny by default, allowlist explicitly" stays.
4. **Size**: Under 500 lines. Extract examples and templates to `references/` if needed. Never nest deeper than `SKILL.md → references/file.md`.
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

If a skill benefits from an external skill (too complex to distill), add a reference line in the skill body and register it in `global-skills.md`.

## Editing AGENTS.global.md

This file is installed as the global `AGENTS.md` (or `CLAUDE.md` for Claude Code). It's read on every invocation — keep it minimal.

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

## Installer (`install.sh`)

The install script downloads spine and copies files to each detected tool's config directory. For Claude Code, it also installs the Spine plugin.

**What it does**:
1. Downloads the repo via `git clone --depth 1` (or `curl` tarball fallback)
2. Detects tools by checking for `~/.cursor/`, `~/.claude/`, `~/.codex/`
3. Copies guardrails, agents, and skills to each tool's directory
4. For Claude Code: attempts `claude plugin marketplace add` + `claude plugin install`; falls back to manual hook installation if the CLI doesn't support plugins

**When to update**:
- Adding a new supported tool → add detection in `detect_tools()` and install logic in `install_tool()`
- Changing the guardrails filename → update the copy logic in `install_tool()`
- Changing plugin hooks → update `claude/hooks/hooks.json` and `claude/hooks/`
- Changing plugin metadata → update `claude/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`

**Testing**: Run with `HOME=$(mktemp -d) bash install.sh` to verify in an isolated environment.

## Review Checklist

Before submitting changes:

- [ ] Every skill line passes the authoring test
- [ ] No tool-specific references (k5-*, nestor, dotcursor)
- [ ] Anti-patterns are one line each
- [ ] Cross-references to global skills are registered in `global-skills.md`
- [ ] AGENTS.global.md stays under ~65 lines
