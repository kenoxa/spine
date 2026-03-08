# Global Skills

External skills that spine workflows reference or that provide standalone value.

## Install All

```sh
npx skills add obra/superpowers -s brainstorming -a '*' -g -y
npx skills add nicobailon/visual-explainer -s visual-explainer -a '*' -g -y
npx skills add jeffallan/claude-skills -s security-reviewer -a '*' -g -y
npx skills add anthropics/claude-code -s frontend-design -a '*' -g -y
npx skills add wshobson/agents -s wcag-audit-patterns -a '*' -g -y
npx skills add softaworks/agent-toolkit -s reducing-entropy -a '*' -g -y
npx skills add sickn33/antigravity-awesome-skills -s typescript-expert -a '*' -g -y
```

## Referenced by local skills

| Skill | Repo | Referenced by |
|-------|------|---------------|
| `brainstorming` | `obra/superpowers` | do-plan, do-discuss — divergent ideation when problem is known but solution space is open |
| `visual-explainer` | `nicobailon/visual-explainer` | do-plan, do-review — visual architecture and diff explanations |
| `security-reviewer` | `jeffallan/claude-skills` | do-review — high-risk security probe heuristics |
| `frontend-design` | `anthropics/claude-code` | with-frontend — distinctive visual craft (typography, color, motion, composition) |
| `wcag-audit-patterns` | `wshobson/agents` | with-frontend — comprehensive WCAG 2.2 audit methodology |
| `reducing-entropy` | `softaworks/agent-toolkit` | do-review — net-complexity measurement, counters code bloat |

## Standalone

Useful across all coding tasks without needing a local skill reference.

| Skill | Repo | Value |
|-------|------|-------|
| `typescript-expert` | `sickn33/antigravity-awesome-skills` | Advanced TS patterns: branded types, conditional types, project references, monorepo tooling |
