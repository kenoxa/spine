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
| `ubiquitous-language` | `mattpocock/skills` | with-terminology — DDD-style glossary extraction and canonical term formalization |
| `tdd` | `mattpocock/skills` | with-testing — TDD cycle enforcement and mock implementation rules once test boundaries are mapped |

## Standalone

Useful across all coding tasks without needing a local skill reference.

| Skill | Repo | Value |
|-------|------|-------|
| `typescript-magician` | `mcollina/skills` | Advanced type-system mastery: 14 modular rule files covering generics, conditional types, branded types, inference patterns, error diagnosis |

> **Note:** Browser automation is now handled by the local `use-browser` skill (backed by [dev-browser](https://github.com/SawyerHood/dev-browser)), replacing the retired `agent-browser` global skill.
