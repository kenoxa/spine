---
name: use-skill-craft
description: >
  Write, review, or fix skills, agent files, reference files, and AGENTS.md.
  Use when creating a new skill, authoring agent or reference files, auditing
  an existing skill, refactoring a bloated AGENTS.md, or reviewing whether
  content passes the authoring test.
  Do NOT use for general documentation writing — see the `use-writing` skill.
argument-hint: "[skill name, agent/reference file, or AGENTS.md path]"
---

## Overview

Three tasks, three sections:
1. [Writing a new skill](#1-writing-a-new-skill)
2. [Reviewing an existing skill](#2-reviewing-an-existing-skill)
3. [Fixing a bloated AGENTS.md](#3-fixing-a-bloated-agentsmd)

---

## 1. Writing a New Skill

**Authoring test:** Would an LLM perform this task worse without the skill? If the
agent would figure it out from general knowledge or by reading the target files,
do not create the skill.

### Frontmatter

```yaml
---
description: >
  What it does. Use when [triggers]. Do NOT use when [exclusions].
---
```

Include a `name` field matching the directory name (with prefix).
`description` is the sole trigger surface — the body loads only after activation. Every behavior mode and trigger phrase must appear in the description or the skill won't auto-invoke.

**Prefix convention** — pick the prefix that matches your skill's role:

| Prefix | Use for |
|--------|---------|
| `do-` | Workflow chain (discuss → plan → execute → commit) |
| `run-` | Standalone utilities (debug, review, polish, recap) |
| `with-` | Domain constraints — applied when task matches a domain (backend, frontend, terminology, testing) |
| `use-` | Operational tools — utilities, conventions, cross-provider tooling |

Plain names (`handoff`, `catchup`): session primitives. See `docs/skills-reference.md` for full details.
Add `disable-model-invocation: true` only when the skill is a thin routing wrapper
that immediately delegates to another skill.

### Structure

`overview → core directives → anti-patterns` — no other sections unless the task
requires prerequisites.

Core directives must be domain-specific procedures the agent wouldn't know.
For multi-phase workflow skills: see `references/workflow-patterns.md` — pattern selection, phase structure, anti-patterns.

**Composition model.** Agent + reference file = augmented behavior. References add, never replace. Linked refs load into mainthread; backticked paths dispatch-only — do NOT Read. See `docs/specs/2612-thin-orchestrator/spec.md`.
**Dispatch visibility.** Every dispatched agent appears in both the phase table AND inline dispatch list. Bold standalone paragraphs read as annotations — inline as list items.
**Cross-skill refs.** Skills cross-reference sibling refs via `../` paths. When renaming/moving reference files, check downstream consumers.
**Retired names.** When renaming agents/skills/MCP servers, add old name to the retired array in `install.sh`.
**Declare, don't branch.** Reference files describe what they consume and produce. No caller-identity conditionals; parameterize I/O paths.
**Reference naming.** `{phase}-{role}.md`, `orchestrate-{mode}.md`, `template-{artifact}.md`, `{concept}.md`.
**Phases are mandatory, fanout is adaptive.** Every phase executes unless the skill explicitly gates it (e.g., depth classification). Zero-dispatch (phase executes, dispatches no subagents) is valid — not skip or fast-exit. Phase execution must be auditable: see `references/phase-audit.md` for logging, completion gates, and dispatch taxonomy.

Cut:
- Definitions ("A trace is the complete record of...")
- Motivation ("This is important because...")
- Framework lists ("You can use FastAPI, Flask, or...")
- Anything the agent can deduce from general knowledge or the target files

Anti-patterns: one line each. If a warning needs a paragraph to explain, convert
it to a directive in the main instructions instead.

**Be concrete.** Vague directives fail the authoring test. See
[references/examples.md](references/examples.md) for before/after pairs.

**Telegraphic prose.** Sacrifice grammar for scannability — imperative fragments over full sentences. Skills are LLM-consumed, not prose. Compress grammar, not behavioral qualifiers — if a phrase constrains *what the model outputs* (not just how it processes), keep it even if it looks like cuttable prose.

### Size

Keep under 5000 tokens. If examples push past the limit, extract to
`references/examples.md` and link from the relevant section. NEVER nest deeper
than `skill.md → references/file.md`.

---

## 2. Reviewing an Existing Skill

Apply the authoring test to every line: *"Would a capable agent deduce this from
general knowledge or from reading the target files?"* Cut any line that passes.

Audit in order:

1. **General knowledge** — definitions, motivation, framework lists → cut
2. **Wisdom** — paragraph warnings → one-line anti-patterns or fold into directives
3. **Duplication** — content in a canonical file → replace with pointer

**Delete a skill outright** if it only loads or references another skill.

Red flags:
- 2+ explanation sentences without a directive
- "It's important to..." / "Note that..." openers
- Anti-patterns that take more than one line to state
- Full sentences where imperative fragments suffice
- Tool-specific references (k5-*, nestor, dotcursor) in skills or agents

---

## 3. Fixing a Bloated AGENTS.md

**Step 1 — Find contradictions.** Surface conflicting instructions; ask user which to keep.

**Step 2 — Identify root-level essentials.** Root AGENTS.md keeps only:
- One-sentence project description
- Package manager (omit — `ni` is universal; see `use-js` skill)
- Non-standard build, typecheck, or test commands
- Instructions relevant to every single task

**Step 3 — Group and extract.** Everything else → logical categories, one file each. Link from root.

**Step 4 — Flag for deletion.** Present flagged items before deleting:
- Redundant (agent knows from general knowledge)
- Too vague to act on ("write clean code")
- Overly obvious ("don't commit secrets")

Root AGENTS.md is read every invocation — keep minimal. References load on demand.

---

## Anti-Patterns

- Creating a skill because the content is "useful" rather than because the agent
  would perform worse without it
- Writing explanation paragraphs instead of directives
- Anti-patterns that require more than one line (convert to a directive instead)
- AGENTS.md that lists all conventions inline instead of using progressive disclosure
- References nested deeper than one level (`skill.md → ref.md → detail.md`)
