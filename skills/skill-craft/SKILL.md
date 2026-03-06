---
name: skill-craft
description: >
  Write, review, or fix skills and AGENTS.md files.
  Use when creating a new skill, auditing an existing one, refactoring a
  bloated AGENTS.md, or reviewing whether content passes the authoring test.
  Do NOT use for general documentation writing — see the `writing` skill.
argument-hint: "[skill name or AGENTS.md path]"
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

Name is derived from the directory name — do not add a `name` field.
Add `disable-model-invocation: true` only when the skill is a thin routing wrapper
that immediately delegates to another skill.

### Structure

`overview → core directives → anti-patterns` — no other sections unless the task
requires prerequisites.

Core directives must be domain-specific procedures the agent wouldn't know. Cut:
- Definitions ("A trace is the complete record of...")
- Motivation ("This is important because...")
- Framework lists ("You can use FastAPI, Flask, or...")
- Anything the agent can deduce from general knowledge or the target files

Anti-patterns: one line each. If a warning needs a paragraph to explain, convert
it to a directive in the main instructions instead.

**Be concrete.** Vague directives fail the authoring test. See
[references/examples.md](references/examples.md) for before/after pairs.

### Size

Keep under 500 lines. If examples push past the limit, extract to
`references/examples.md` and link from the relevant section. NEVER nest deeper
than `skill.md → references/file.md`.

---

## 2. Reviewing an Existing Skill

Apply the authoring test to every line: *"Would a capable agent deduce this from
general knowledge or from reading the target files?"* Cut any line that passes.

Audit in order:

1. **General knowledge** — definitions, motivation, framework lists → cut
2. **Wisdom** — warnings with paragraph explanations → convert to one-line
   anti-patterns or fold into a directive in the main instructions
3. **Duplication** — content already in a canonical file → replace with a pointer

**Delete a skill outright** if its sole purpose is to load or reference another skill.

Red flags:
- More than two consecutive sentences of explanation with no directive
- Any sentence starting with "It's important to..." or "Note that..."
- Anti-patterns that take more than one line to state

---

## 3. Fixing a Bloated AGENTS.md

**Step 1 — Find contradictions.** Identify conflicting instructions; ask the user
which to keep before proceeding.

**Step 2 — Identify root-level essentials.** Root AGENTS.md keeps only:
- One-sentence project description
- Package manager (omit if npm — it's the default)
- Non-standard build, typecheck, or test commands
- Instructions relevant to every single task

**Step 3 — Group and extract.** Organize everything else into logical categories
(TypeScript conventions, API design, testing patterns, git workflow). One file per
category. Link from root using markdown links.

**Step 4 — Flag for deletion.** Present flagged items to the user before deleting.
Mark instructions that are:
- Redundant (agent already knows from general knowledge)
- Too vague to be actionable ("write clean code")
- Overly obvious ("don't commit secrets")

Root AGENTS.md is read on every invocation — keep it minimal. Reference files are
loaded on demand.

---

## Anti-Patterns

- Creating a skill because the content is "useful" rather than because the agent
  would perform worse without it
- Writing explanation paragraphs instead of directives
- Anti-patterns that require more than one line (convert to a directive instead)
- AGENTS.md that lists all conventions inline instead of using progressive disclosure
- References nested deeper than one level (`skill.md → ref.md → detail.md`)
