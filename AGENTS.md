# Spine

Cross-provider AI coding framework: shared skills, subagents, guardrails for Cursor, Claude Code, and Codex.

## Repo Layout

SPINE.md              Global guardrails (~1800 token cap; installed to ~/.config/spine/)
CONTRIBUTING.md       Human authoring guide — read before editing skills or agents
skills/               Skills: SKILL.md + references/ per skill
  {do,run,with,use}-* Prefix: do- workflow, run- standalone, with- domain, use- tools
agents/               Subagents (250-750 tokens each)
claude/               Claude Code plugin: hooks, Claude-only skills (run-skill-eval)
docs/                 specs/, skills-reference.md, global-skills.md, tips.md
scripts/              Token counting, drift detection
install.sh            Installer — manages ~/.config/spine/ and provider symlinks
.scratch/             Ephemeral session output (gitignored)

## Token Budgets

| Artifact | Target | Flag |
|----------|--------|------|
| SPINE.md | ~1800 | — |
| SKILL.md | — | >5000 |
| Agent file | 250-750 | >750 |
| Reference file | 250-800 | >1000 |

Encoding: o200k_base. Measure: `tokenizer -f <file> -m gpt-4.1`.
After changing any AI-loaded file: `scripts/token-counts.sh --update`.

## Every-Task Rules

- **Authoring test**: every line in skills/agents must address something AI handles worse without guidance — cut if no
- **Description-is-the-trigger**: skill frontmatter `description:` must contain trigger phrases — body loads only after activation
- **No tool-specific references**: no k5-*, nestor, dotcursor in skills or agents
- **Composition model**: agent + reference file = augmented behavior. References add, never replace. In SKILL.md, linked refs load into mainthread; backticked paths are dispatch-only — do NOT Read. See `docs/specs/2612-thin-orchestrator/spec.md`
- **Retired names**: when renaming agents/skills/MCP servers, add old name to the corresponding retired array in install.sh
- **Reference naming**: `{phase}-{role}.md`, `orchestrate-{mode}.md`, `template-{artifact}.md`

## Deep Dives

- Skill/agent authoring: CONTRIBUTING.md
- Architecture: docs/specs/2612-thin-orchestrator/spec.md
- Skill catalog: docs/skills-reference.md
- External skills: docs/global-skills.md
