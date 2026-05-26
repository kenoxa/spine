# Global Skills

External skills that spine workflows reference or that provide standalone value.

Public install examples intentionally use `npx skills add` to match [`skills.sh`](https://skills.sh/). The installer may bootstrap the same CLI through another launcher.

## Install All

```sh
npx skills add obra/superpowers -s brainstorming -a '*' -g -y
npx skills add nicobailon/visual-explainer -s visual-explainer -a '*' -g -y
npx skills add jeffallan/claude-skills -s security-reviewer -a '*' -g -y
npx skills add anthropics/claude-code -s frontend-design -a '*' -g -y
npx skills add wshobson/agents -s wcag-audit-patterns -a '*' -g -y
npx skills add softaworks/agent-toolkit -s reducing-entropy -a '*' -g -y
npx skills add mcollina/skills -s typescript-magician -a '*' -g -y
npx skills add trailofbits/skills -s fp-check -a '*' -g -y
npx skills add mattpocock/skills -s ubiquitous-language -a '*' -g -y
npx skills add mattpocock/skills -s tdd -a '*' -g -y
npx skills add GoogleChrome/modern-web-guidance -s modern-web-guidance -a '*' -g -y
```

> **Note:** `modern-web-guidance` is version-pinned. `install.sh` rewrites the installed `SKILL.md` from `@latest` to a known-good version (upstream is early-preview and churns daily); a manual `npx skills add` tracks upstream `@latest` until you re-run `install.sh`.

## Referenced by local skills

| Skill | Repo | Referenced by |
|-------|------|---------------|
| `brainstorming` | `obra/superpowers` | design phase — divergent ideation when problem is known but solution space is open |
| `visual-explainer` | `nicobailon/visual-explainer` | `@visualizer` agent — visual architecture and diff explanations |
| `security-reviewer` | `jeffallan/claude-skills` | run-review — high-risk security probe heuristics |
| `frontend-design` | `anthropics/claude-code` | with-frontend — distinctive visual craft (typography, color, motion, composition) |
| `wcag-audit-patterns` | `wshobson/agents` | with-frontend — comprehensive WCAG 2.2 audit methodology |
| `reducing-entropy` | `softaworks/agent-toolkit` | run-review — net-complexity measurement, counters code bloat |
| `fp-check` | `trailofbits/skills` | run-review — systematic true/false positive verification for security findings |
| `ubiquitous-language` | `mattpocock/skills` | with-terminology — DDD-style glossary extraction and canonical term formalization (expects sections: Relationships, Example dialogue, Flagged ambiguities) |
| `tdd` | `mattpocock/skills` | with-testing — TDD cycle enforcement and mock implementation rules once test boundaries are mapped |
| `modern-web-guidance` | `GoogleChrome/modern-web-guidance` | with-frontend — modern web-platform best-practice guides |

## Standalone

Useful across all coding tasks without needing a local skill reference.

| Skill | Repo | Value |
|-------|------|-------|
| `typescript-magician` | `mcollina/skills` | Advanced type-system mastery: 14 modular rule files covering generics, conditional types, branded types, inference patterns, error diagnosis |

> **Note:** Browser automation is now handled by the local `use-browser` skill (backed by [dev-browser](https://github.com/SawyerHood/dev-browser)), replacing the retired `agent-browser` global skill.

## Upstream Plugins

Bundled by upstream maintainers — distributed via each provider's plugin system rather than `skills add`. `install.sh` wires them up per provider.

| Plugin | Upstream | Bundles | Provider mechanism |
|--------|----------|---------|--------------------|
| `svelte` | `sveltejs/ai-tools` | Svelte MCP server (`https://mcp.svelte.dev/mcp`), `svelte-code-writer` + `svelte-core-bestpractices` skills, `svelte-file-editor` subagent | Claude Code: `claude plugin install svelte` (auto). OpenCode: `@sveltejs/opencode` merged into `opencode.json` plugin array (auto). Cursor: manual — `/add-plugin svelte` (notice emitted by installer). Codex: no plugin upstream; installer runs `codex mcp add svelte --url https://mcp.svelte.dev/mcp` for MCP-level access. Team conventions and MCP workflow live in `skills/with-frontend/references/svelte.md`. |

## Description Budget

Claude Code loads all skill descriptions at session start into a fixed character budget (default: 8,000 chars). Spine's 45 active skills (33 local + 12 global) must fit within 7,700 chars to leave headroom across context sizes.

Each skill occupies `desc_len + 109` chars of budget. Run the checker after any description change:

```sh
scripts/check-skill-budget.sh
```

### Tier classification (invocation surface)

| Tier | Who fires it | Budget | Triggers? |
|------|-------------|--------|-----------|
| `global-fp` | User directly | ≤95c | Yes, quoted cluster |
| `sub-skill` | Workflow skill only | ≤50c | No — purpose only |

### Compact descriptions via `skill-overrides.yaml`

Global skill upstream descriptions are often verbose (200–500 chars). `skill-overrides.yaml` at the repo root declares compact replacements:

```yaml
skills:
  typescript-magician:
    tier: global-fp
    description: >-
      Advanced TypeScript type mastery. Use when: 'type error', 'generics', 'TS types'.
  security-reviewer:
    tier: sub-skill
    description: >-
      Security audit heuristics for run-review.
```

`install.sh` applies these automatically after each `skills add` via `patch_global_skill_descriptions()`, using `yq --front-matter=process` to rewrite only the `description` field in `~/.agents/skills/<name>/SKILL.md`. The patch is idempotent — a second install run writes nothing if the description already matches.
