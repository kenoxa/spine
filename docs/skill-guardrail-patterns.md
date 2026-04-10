---
updated: 2026-04-10
paths:
  - skills/use-skill-craft/SKILL.md
  - CONTRIBUTING.md
---

# Skill Guardrail Patterns

## Anti-Rationalization Bullets

Rationalization-awareness bullets in Anti-Patterns section. Format:
`"excuse" — reality: consequence`. Distinct from structural anti-patterns —
targets agent self-talk at step-skipping moments.

Converged independently in two major frameworks:
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (10k+ stars) — "Common Rationalizations" tables
- obra/superpowers (137k stars) — anti-rationalization tables + rationalization testing

Spine format: one-line telegraphic bullets, not 2-column tables. Fits existing
anti-pattern convention.

## Completion Sections

Optional `## Completion` for workflow skills with phase-gated exits. 3-6
evidence requirements, E-level tagged. Precedent: run-debug, do-build/finalize,
phase-audit completion gates.

Required for `do-*`/`run-*` with phase tables. Omit for `use-*`/`with-*`.

## Inline vs Hook Enforcement

Inline guardrail sections = salience aids at activation time. NOT cross-session
enforcement. Per rjmurillo/ai-agents post-mortem: trust-based inline instructions
~0% success for autonomous multi-session; hook-based enforcement 90%+.

Spine mitigation: skills reactivate per-session — activation-time salience is
the relevant mode. For true enforcement, pair with PostToolUse hooks.

## Ecosystem Context

agentskills.io spec (Anthropic, OpenAI, Sourcegraph): `name` + `description`
required; body sections free-form. Anti-rationalization/Red Flags/Verification
are community convention (addyosmani), not standard.

Red Flags most independently validated (narumiruna adopted independently).
Rationalization tables second (addyosmani + obra). Verification checklists
addyosmani-specific.
