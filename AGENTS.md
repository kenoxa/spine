# Spine

Cross-provider AI coding framework: shared skills, subagents, guardrails for Cursor, Claude Code, and Codex.

## Repo Layout

SPINE.md              Global guardrails (~1800 token cap; installed to ~/.config/spine/)
CONTRIBUTING.md       Human authoring guide — read before editing skills or agents
skills/               Skills: SKILL.md + references/ per skill
  {do,run,with,use}-* Prefix: do- workflow, run- standalone, with- domain, use- tools
agents/               Subagents (250-1000 tokens each)
hooks/                Cross-provider hooks: _env.sh _ts.sh _nlx.sh _project.sh (helpers), shell/TS hooks, tests/
claude/               Claude Code plugin: hooks.json manifest, Claude-only skills (run-skill-eval)
opencode/             OpenCode plugin: spine-hooks.ts (in-process hook delegation)
docs/                 specs/, skills-reference.md, global-skills.md, tips.md
scripts/              Token counting, drift detection
install.sh            Installer — manages ~/.config/spine/ and provider symlinks
.scratch/             Ephemeral session output (gitignored)

## Token Budgets

| Artifact | Target | Flag |
|----------|--------|------|
| SPINE.md | ~1800 | — |
| SKILL.md | — | >5000 |
| Agent file | 250-1000 | >1000 |
| Reference file | 250-800 | >1000 |

Encoding: o200k_base. Measure: `tokenizer -f <file> -m gpt-4.1`.
After changing any AI-loaded file: `scripts/token-counts.sh --update`.

## Project Knowledge

Durable cross-provider insights in `docs/`. Backticked paths — not auto-loaded.
Managed by `/run-curate`; style: telegraphic, 250-800 tokens, `updated:` frontmatter.

- `docs/copilot-model-plan-gates.md` — Gemini/Grok require Copilot Pro+/Business plan
- `docs/multi-model-council-sizing.md` — 3-model default, diversity > performance, anti-patterns
- `docs/provider-privacy.md` — training/retention/residency per provider and tier

## Deep Dives

- Skill/agent authoring: CONTRIBUTING.md
- Architecture: docs/specs/2612-thin-orchestrator/spec.md
- Skill catalog: docs/skills-reference.md
- External skills: docs/global-skills.md
