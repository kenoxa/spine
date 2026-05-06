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
npx skills add trailofbits/skills -s differential-review -a '*' -g -y
npx skills add trailofbits/skills -s fp-check -a '*' -g -y
npx skills add mattpocock/skills -s ubiquitous-language -a '*' -g -y
npx skills add mattpocock/skills -s tdd -a '*' -g -y
```

## Referenced by local skills

| Skill | Repo | Referenced by |
|-------|------|---------------|
| `brainstorming` | `obra/superpowers` | do-design, do-frame — divergent ideation when problem is known but solution space is open |
| `visual-explainer` | `nicobailon/visual-explainer` | `@visualizer` agent — visual architecture and diff explanations |
| `security-reviewer` | `jeffallan/claude-skills` | run-review — high-risk security probe heuristics |
| `frontend-design` | `anthropics/claude-code` | with-frontend — distinctive visual craft (typography, color, motion, composition) |
| `wcag-audit-patterns` | `wshobson/agents` | with-frontend — comprehensive WCAG 2.2 audit methodology |
| `reducing-entropy` | `softaworks/agent-toolkit` | run-review — net-complexity measurement, counters code bloat |
| `differential-review` | `trailofbits/skills` | run-review — security-focused PR review with blast radius and regression detection |
| `fp-check` | `trailofbits/skills` | run-review — systematic true/false positive verification for security findings |
| `ubiquitous-language` | `mattpocock/skills` | with-terminology — DDD-style glossary extraction and canonical term formalization (expects sections: Relationships, Example dialogue, Flagged ambiguities) |
| `tdd` | `mattpocock/skills` | with-testing — TDD cycle enforcement and mock implementation rules once test boundaries are mapped |

## Standalone

Useful across all coding tasks without needing a local skill reference.

| Skill | Repo | Value |
|-------|------|-------|
| `typescript-magician` | `mcollina/skills` | Advanced type-system mastery: 14 modular rule files covering generics, conditional types, branded types, inference patterns, error diagnosis |

> **Note:** Browser automation is now handled by the local `use-browser` skill (backed by [dev-browser](https://github.com/SawyerHood/dev-browser)), replacing the retired `agent-browser` global skill.

## Description Budget

Claude Code loads all skill descriptions at session start into a fixed character budget (default: 8,000 chars). Spine's 43 active skills (32 local + 11 global) must fit within 7,500 chars to leave headroom across context sizes.

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
