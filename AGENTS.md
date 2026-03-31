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

## Project Knowledge

Durable cross-provider insights in `docs/`. Backticked paths — not auto-loaded.
Managed by `/run-curate`; style: telegraphic, 250-800 tokens, `updated:` frontmatter.

_(no entries yet)_

## Deep Dives

- Skill/agent authoring: CONTRIBUTING.md
- Architecture: docs/specs/2612-thin-orchestrator/spec.md
- Skill catalog: docs/skills-reference.md
- External skills: docs/global-skills.md
