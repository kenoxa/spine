# Contributing

AI contributors: see `AGENTS.md` for per-invocation constraints and token budgets.

## Repo Structure

```
SPINE.md                Global guardrails (installed to ~/.config/spine/SPINE.md)
skills/                 28 skills (19 workflow + 4 domain + 5 tools)
agents/                 14 subagents
claude/                 Claude Code plugin (hooks + skills)
docs/                   Reference docs (skills, tips, external skills)
.scratch/               Ephemeral subagent output (gitignored)
```

## Adding a Skill

Use `/use-skill-craft` — it covers the full authoring workflow. Key points:

1. **Pass the authoring test**: Would an LLM perform the task worse without this skill? If the agent can figure it out from general knowledge or target files, don't create the skill.
2. **Structure**: `frontmatter → overview → core directives → anti-patterns` + optional `## Completion` for skills with exit-evidence requirements. No other sections unless prerequisites require it.
3. **Be concrete**: Vague directives fail the authoring test. "Handle errors properly" is cut. "Fail-closed: deny by default, allowlist explicitly" stays.
4. **Phase enforcement**: Multi-phase skills: classify dispatch points (C/R/G per `workflow-patterns.md`), log Phase Trace at boundaries, verify coverage at completion. See `phase-audit.md`.
5. **Size**: Under 5000 tokens. Extract examples and templates to `references/` if needed. Never nest deeper than `SKILL.md → references/file.md`.
6. **Reference links**: In SKILL.md, use markdown links `[text](references/file.md)` only for references the mainthread reads at activation. For subagent dispatch references, use backticked paths `` `references/file.md` `` — these are passed as paths in dispatch prompts, not loaded by the skill loader. For lazy-loaded references (Tier B orchestrator refs), also use backticked paths with an explicit Read instruction.
7. **I/O path parameterization**: Subagent reference files declare all scratch I/O via `{placeholder}` names (`{output_path}`, `{input_name_path}`). The orchestrator constructs paths; subagents receive them. See `use-skill-craft/SKILL.md:64`.
   All size thresholds use token counts (o200k_base encoding). Verify with any o200k_base tokenizer (e.g., `tokenizer -f <file> -m gpt-4.1`; installed by `install.sh` or `brew install zahidcakici/tap/tokenizer`).
8. **Scripts**: Acceptable when the task involves processing data volumes exceeding LLM context limits. Place in `scripts/` subdirectory of the skill. Document runtime requirements (e.g., Python 3.9+) in the skill description. Keep scripts stdlib-only — no package-manager dependencies.

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
npx skills add mattpocock/skills -s ubiquitous-language -a '*' -g -y
npx skills add mattpocock/skills -s tdd -a '*' -g -y
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
model: haiku          # opus | sonnet | haiku | inherit (default)
effort: medium        # high (default) | medium — Codex only; Claude/Cursor ignore
readonly: true        # Cursor only; omit for agents that write to .scratch/
skills:
  - skill-to-preload  # Claude Code only; Cursor ignores
---
```

Tier guidance: `opus` for complex reasoning (Frontier), `sonnet` for review/research (Standard), `haiku` for fast reconnaissance (Fast), `inherit` for session-tracking agents (Adaptive). See [docs/model-selection.md](docs/model-selection.md).

Keep subagent bodies focused — they should define constraints and output format, not duplicate the skill content they preload.

**Dispatch rule**: Never pass `model` on Agent tool calls in skills or dispatch references — agent frontmatter declares the tier. Omitting `model` lets the definition control selection. Users may override per-session; skill code never does.

For Codex, the installer generates TOML role configs (including `model` and `effort` fields) from markdown source automatically — no manual TOML authoring needed.

### Scratchspace Convention

Subagents may create a scratchspace directory alongside their output file for intermediate work (verification scripts, draft analysis, evidence traces). Derive the directory path by stripping the file extension:

- `plan-discovery-researcher.md` → `plan-discovery-researcher/`
- `plan-review.html` → `plan-review/`
- `plan-planning-envoy.codex.md` → `plan-planning-envoy.codex/`

Scratchspace is inspectable (orchestrators and downstream agents may read it) but not formal output — synthesizer reads prescribed paths only. Agents create the directory on demand via `mkdir -p`; session cleanup handles deletion. The derivation rule lives in SPINE.md; do not repeat it in agent files or reference files.

**Exclusions**: `@envoy` (dispatcher — hard "ONLY write to `.prompt`" constraint) and `@synthesizer` (aggregation-only — writes prescribed output file, no intermediate work) do not get scratchspace.

### Dispatching @envoy

The Agent tool prompt must frame `@envoy` as a CLI assembler, not a task performer. Open with: `"Assemble a self-contained prompt for external CLI review of..."` Never open with task language (`"Analyze..."`, `"Review..."`, `"Plan..."`) — this causes envoy to self-answer instead of dispatching to the external CLI.

Task-specific content (planning briefs, review contexts, code references) is payload — pass it as prompt content for envoy to assemble into the CLI prompt file, not as a directive for envoy to act on. The assembly directive is a meta-instruction for `@envoy` — it must NOT appear in the `.prompt` file sent to external providers. `run.sh` strips it as a safeguard. See `skills/use-envoy/SKILL.md` for the full dispatch template.

**Output path routing.** `{output_path}` in envoy refs is routing metadata: dispatch prompt → `agents/envoy.md` → `run.sh --output-file`. It must NOT appear in the `.prompt` body sent to external providers — agentic providers (Codex, Cursor) will attempt file writes to the embedded path, causing race conditions in multi-mode. Envoy refs describe output *format* in `## Output`, not file destination. `run.sh` strips leaked `Write to` / `Output path:` / `Scratchspace:` lines as defense-in-depth.

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
4. Detects tools by checking for `~/.cursor/`, `~/.claude/`, `~/.codex/`, and `opencode` on `PATH`
5. Writes `@~/.config/spine/SPINE.md` and `@~/.config/spine/AGENTS.md` references to each provider's root file (preserves user content), symlinks agents (Claude Code) or generates provider-mapped copies (Cursor `.md` with mapped model values, Codex TOML with mapped model + effort, OpenCode `.md` with model field), and for Claude Code installs the Spine plugin
6. Configures Context7 + Exa MCP servers (`install_mcp_servers()`) — CLI commands for Claude Code/Codex, jq patch for Cursor
7. Installs skills via the `skills` CLI with its own launcher fallback (local spine skills + global external skills)
8. Cleans up stale symlinks and backup files

**When to update**:
- Adding a new supported tool → add detection in `detect_tools()` and install logic in `install_tool()`. Extensibility contract: `check-<provider>.sh` + `invoke-<provider>.sh`.
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

## Knowledge Files

Durable project insights live in `docs/` and are indexed by AGENTS.md `## Project Knowledge`. Managed via `/run-curate`.

**When to create**: cross-provider architectural insights, constraint discoveries, integration patterns — anything that improves future AI sessions and can't be derived from code or git history alone.

**Format**:
- Frontmatter: `updated: YYYY-MM-DD`, optional `paths: [list]` (codebase paths for staleness detection)
- Style: telegraphic skill-craft prose (same as agent files)
- Size: 250-800 tokens (o200k_base)
- Naming: descriptive, no prefix (e.g., `docs/session-inheritance.md`)

**AGENTS.md index**: backticked paths + 2-5 word gloss. No markdown links — prevents auto-loading.

```markdown
## Project Knowledge

`docs/session-inheritance.md` — skill vs agent session behavior
`docs/reviewer-limits.md` — parallel reviewer dispatch caps
```

**Routing rubric**: SPINE.md rules → SPINE.md. Skill/agent roles → skill/agent files. Durable insights → `docs/*.md` knowledge files. Ephemeral session notes → `.scratch/`.

**Evidence gate**: promotion requires E2+ anchor (code reference or executed command). E0/E1-only learnings are advisory. Exception: findings about third-party systems (provider policies, external libraries, academic results) accept E1 with 3+ independent sources — these are structurally incapable of producing E2 code references.

**Staleness detection**: `/run-curate` checks each knowledge file's `updated:` frontmatter against `git log --since=<updated_date>` on related codebase paths. Files with changed neighbors are flagged stale and prioritized for Update or Prune review. Knowledge files may declare related paths via `paths:` frontmatter for more accurate detection; files without declared paths are skipped.

**Coverage gap discovery**: `/run-curate` dispatches an envoy panel (frontier tier, multi-provider) to identify unrepresented knowledge domains. Output is advisory (E1) — envoy findings cannot self-promote through the E2+ evidence gate. Curator may recommend investigation of flagged gaps as follow-up; promotion still requires E2+ anchor.

**Candidate intake** (standalone mode): scans `.scratch/` session logs for entries with `knowledge_candidate: yes`. Other workflow skills may emit candidates in their finalize phases using the standard shape: `what_was_attempted`, `result`, `assumption_corrected`, `knowledge_candidate`. Collected candidates are passed to `@curator` alongside existing entries.

## Review Checklist

Before submitting changes:

- [ ] Every skill line passes the authoring test
- [ ] No tool-specific references (k5-*, nestor, dotcursor)
- [ ] Anti-patterns are one line each
- [ ] Cross-references to global skills are registered in `docs/global-skills.md`
- [ ] SPINE.md stays under ~1800 tokens
- [ ] AGENTS.md stays under ~1000 tokens
