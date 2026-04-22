---
updated: 2026-04-22
paths:
  - skills/use-skill-craft/SKILL.md
  - CONTRIBUTING.md
  - SPINE.md
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

## Cross-File Safety Qualifier Echoing

When a SPINE.md rule summarizes a constraint from a reference file, echo any
safety-critical qualifier inline in SPINE.md. Subagents receive SPINE.md via
`@~/.config/spine/SPINE.md` import (CLAUDE.md / AGENTS.md → SPINE.md) but do NOT
load reference files unless a specific review or polish skill dispatches them.

Example: `advisory-complexity.md:7,38` carries `NEVER flag auth, authz, or
validation boundaries`. SPINE.md L22's "impossible conditions" rule summarized
the same heuristic but omitted that qualifier — a subagent reading only SPINE.md
could strip required auth validation as "defensive bloat". Fix: append the qualifier
directly in the SPINE.md rule. [E2: `SPINE.md:22`, `advisory-complexity.md:7,38`;
commit 4fba8df]

**Audit trigger**: when compressing a rule from a reference file into SPINE.md,
check whether the reference file carries a `NEVER`/`always` safety clause that
the compressed form omits. If yes, echo it in the SPINE.md line — one clause cost.

## New Rule Conflict Audit

When adding a rule to SPINE.md `## Collaboration` (or any section with
competing directives), explicitly precedence-rank it against existing rules
before committing.

**Pattern that fails**: new rule adds a valid behavior but creates an implicit
override of an existing rule. Example: `surface multiple interpretations when
a request is ambiguous` conflicted with `Lead with clear takes` and
`Avoid "it depends"` — an over-literal agent treats mild under-specification
as ambiguity and asks instead of deciding. Caught independently by 3 envoys
(codex/cursor/opencode all flagged MEDIUM). [E2: `SPINE.md:91-92`;
commit 4fba8df]

**Fix pattern**: tighten the trigger to make precedence implicit in the clause
itself. `only when readings would produce different deliverables` makes L92 fire
only on high-grade ambiguity; `Lead with clear takes` (L91) wins on everything
else. No explicit ordering needed when trigger is narrow enough.

**Audit trigger**: before merging a new Collaboration rule, scan existing rules
for decide/ask tension. If the new rule expands ask-surface, add `only when` or
`only if` to narrow the trigger. Advisory — not a gate, but catches the most
common multi-rule conflict pattern in Spine's history.
