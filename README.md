# Spine

> **Same skills, same workflow — every developer, every tool.**

Cross-platform AI coding setup for Cursor, Claude Code, and Codex. One set of skills, agents, and guardrails that works everywhere.

## Contents

- [What's Inside](#whats-inside)
- [Quick Start](#quick-start)
- [Typical Flow](#typical-flow)
- [Tips](#tips)
- [External Skills](#external-skills)
- [Design Principles](#design-principles)
- [Further Reading](#further-reading)

## What's Inside

> **Every change deserves a plan.**

```
AGENTS.global.md        Global guardrails (installed as AGENTS.md / CLAUDE.md)
skills/                 11 skills (5 workflow + 5 domain + skill-craft)
agents/                 2 subagents (explorer, reviewer)
hooks/                  Claude Code SessionStart hook for AGENTS.md injection
global-skills.md        External skills to install separately
```

### Skills

| Skill | Type | Purpose |
|-------|------|---------|
| `do-plan` | workflow | Structured planning before complex implementation |
| `do-execute` | workflow | Execute an approved plan through phased quality gates |
| `do-review` | workflow | Severity-bucketed code review |
| `do-debug` | workflow | 4-phase root-cause diagnosis and fix |
| `do-commit` | workflow | Scoped staging with conventional commits |
| `explore` | domain | Bounded codebase navigation and architecture mapping |
| `writing` | domain | Docs, changelogs, ADRs, and prose quality |
| `frontend` | domain | UI development with state coverage and accessibility gates |
| `backend` | domain | APIs, migrations, and security boundaries |
| `testing` | domain | Risk-based test design with perspective tables |
| `skill-craft` | meta | Write, review, or fix skills and AGENTS.md files |

**Workflow skills** are invoked explicitly via `/do-plan`, `/do-execute`, etc.

**Domain skills** are loaded automatically when the task matches their description.

### Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| `explorer` | haiku | Fast, readonly codebase navigation |
| `reviewer` | inherit | Spec compliance review with severity buckets |

## Quick Start

> **If it's worth changing, it's worth planning.**

### Quick Install

Installs guardrails, skills, agents, and hooks for all detected tools (Cursor, Claude Code, Codex):

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
```

Or inspect first:

```sh
curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh -o install.sh
less install.sh
bash install.sh
```

The installer auto-detects which tools you have (`~/.cursor/`, `~/.claude/`, `~/.codex/`) and installs to all of them. For Claude Code, it also sets up the SessionStart hook and patches `settings.json`.

<details>
<summary>Local checkout (recommended for contributors)</summary>

Clone the repo for editing, testing, and iterating on skills before syncing:

```sh
git clone https://github.com/kenoxa/spine.git
cd spine
./install.sh
```

</details>

### Individual Skills

Install specific skills without the full setup:

```sh
npx skills add kenoxa/spine -s do-plan -a '*' -g -y
npx skills add kenoxa/spine -s do-review -a '*' -g -y
```

### Manual Install

Copy files to your tool's config directory. Each tool loads from different paths.

| Source | Cursor | Claude Code | Codex |
|--------|--------|-------------|-------|
| `AGENTS.global.md` | `~/.cursor/AGENTS.md` | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| `skills/` | `~/.cursor/skills/` | `~/.claude/skills/` | `~/.codex/skills/` |
| `agents/` | `~/.cursor/agents/` | `~/.claude/agents/` | `~/.codex/agents/` |

<details>
<summary>Claude Code AGENTS.md hook</summary>

Claude Code natively loads `CLAUDE.md` but not `AGENTS.md`. If your projects use `AGENTS.md` files (shared with Cursor/Codex), install the SessionStart hook so Claude Code sees them too:

```sh
mkdir -p ~/.claude/hooks/
cp hooks/inject-agents-md.sh ~/.claude/hooks/
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/inject-agents-md.sh" }]
    }]
  }
}
```

</details>

## Typical Flow

> **Measure twice, ship once.**

The workflow follows a structured path: plan the change, execute it with quality gates, then commit.

1. **`/do-plan`** — always start here for non-trivial work. Draft and validate the plan.
2. Refine the plan via messages until ready.
3. **`/do-execute`** — runs phased implementation with built-in review and verification.
4. Apply learnings, if any.
5. **`/do-commit`** — stage scoped files and commit with a conventional message.

```mermaid
graph TD
    A[User request] --> B[do-plan]
    B --> C{Plan ready?}
    C -->|No| D[Refine via messages]
    D --> B
    C -->|Yes| E[do-execute]
    E --> F{Review + Verify passed?}
    F -->|No| G[Fix findings]
    G --> E
    F -->|Yes| H[do-commit]
```

For straightforward tasks, start directly with `/do-execute` — it handles planning inline when no plan exists.

<details>
<summary>What <code>/do-plan</code> runs under the hood</summary>

Five phases produce a self-sufficient, executable implementation plan:

1. **Discovery** — map the codebase: file scouting, docs exploration, external research. All claims tagged with evidence levels (E0–E3).
2. **Framing** — distill discoveries into a planning brief: goal, scope, constraints, key decisions, evidence manifest, and docs impact classification.
3. **Planning** — dispatch planners with distinct approach angles (conservative, thorough, innovative). Merge via consensus; rank by evidence level.
4. **Challenge** — adversarial review exposing hidden assumptions, underestimated risks, and unnecessary abstraction. Blocking findings require E2+ evidence and a better alternative.
5. **Synthesis** — assemble the final plan using the plan template. Validate self-sufficiency, test tasks, edge coverage, docs tasks, and completion criteria.

Ask checkpoints after discovery and after challenge ensure ambiguity is resolved before proceeding.

Canonical entry: [`skills/do-plan/SKILL.md`](skills/do-plan/SKILL.md).

</details>

<details>
<summary>What <code>/do-execute</code> runs under the hood</summary>

Six phases with built-in quality gates:

1. **Scope** — read the approved plan, classify depth (`focused`/`standard`/`deep`), partition work into independent and dependent groups.
2. **Implement** — one worker per partition. Parallel for independent groups; sequential for dependent. No overlapping writes. Worker self-review before reporting.
3. **Polish** — advisory pass (read-only reviewers produce findings) → apply pass (workers fix). Every E2+ finding acknowledged or explicitly rejected.
4. **Review** — two stages: tests & docs (skip when no behavior changes and docs_impact is `none`), then adversarial review with multiple lenses. Blocking findings re-enter polish.
5. **Verify** — single verifier instance. All claims require E3 evidence (executed command + observed output).
6. **Finalize** — content gates check for test evidence, edge coverage, and docs. Learnings captured as proposals (never auto-applied).

Re-entry loop: blocking review findings → polish → review → verify. Capped at 5 iterations.

Canonical entry: [`skills/do-execute/SKILL.md`](skills/do-execute/SKILL.md).

</details>

<details>
<summary>What <code>/do-review</code> does</summary>

Structured code review with severity-bucketed findings:

1. **Scope check** — confirm what was requested and what changed.
2. **Evidence check** — validate claims against current code and requirements.
3. **Spec compliance** — verify built behavior matches requested behavior.
4. **Risk pass** — correctness, security, performance, maintainability (scaled by risk level: low → spec + quality; medium → + testing depth; high → + security probe).
5. **Quality pass** — readability, cohesion, duplication, test adequacy, edge/failure coverage.

Findings are bucketed as `blocking` (must fix, E2+ required), `should_fix` (recommended, blocks unless deferred), or `follow_up` (tracked debt). Review is read-only — no file writes.

Canonical entry: [`skills/do-review/SKILL.md`](skills/do-review/SKILL.md).

</details>

<details>
<summary>What <code>/do-debug</code> does</summary>

Four-phase root-cause diagnosis:

1. **Observe** — reproduce deterministically. Capture exact error, steps, environment, and variance.
2. **Pattern** — compare failing path with known-good reference. Narrow to the smallest collision zone.
3. **Hypothesis** — one hypothesis at a time. Change one variable per test. Failed hypothesis → return to observe, not forward.
4. **Harden** — apply the smallest fix that resolves the confirmed root cause. Harden to make the bug class impossible. Verification requires E3 evidence.

Escalation: after 3 failed hypotheses, escalate with concrete evidence. Architectural uncertainty → re-enter planning.

Canonical entry: [`skills/do-debug/SKILL.md`](skills/do-debug/SKILL.md).

</details>

## Tips

> **Plan every change. No exceptions.**

### Slash command arguments

Text after a slash command is the task scope. Examples:

- `/do-plan add retry strategy for API calls`
- `/do-review` — reviews current changes against the plan
- `/do-debug failing auth test in CI`
- `/explore auth module architecture`
- `/do-execute` — starts execution of an approved plan (or plans inline if none exists)

### Workflow tips

- **Domain skills auto-load** — `frontend`, `backend`, `testing`, `writing`, and `explore` activate automatically when the task matches. No slash command needed.
- **Refine before executing** — polish the plan via messages before running `/do-execute`. The plan drives all quality gates downstream.
- **Use subagents for parallel work** — the `explorer` agent handles fast codebase navigation; the `reviewer` agent runs focused code review. Both are readonly and can run in parallel without conflicts.
- **Evidence levels matter** — all claims in plans, reviews, and execution are tagged E0–E3. Blocking claims require code evidence (E2+). Verification requires executed output (E3).
- **Skill-craft for meta-work** — use `/skill-craft` to write, review, or audit skills and AGENTS.md files. It enforces the authoring test: every skill line must address something an LLM handles worse without guidance.

### Installer tips

- **Re-run to update** — run `./install.sh` again after pulling new changes to sync skills and guardrails.
- **Isolated test** — verify the installer in a sandbox: `HOME=$(mktemp -d) bash install.sh`
- **Individual skills** — install just the skills you need via `npx skills add kenoxa/spine -s <skill-name> -a '*' -g -y`

## External Skills

Some local skills reference external skills that provide specialized capabilities too complex to distill. Install them separately:

```sh
npx skills add obra/superpowers -s brainstorming -a '*' -g -y
npx skills add nicobailon/visual-explainer -s visual-explainer -a '*' -g -y
npx skills add jeffallan/claude-skills -s security-reviewer -a '*' -g -y
npx skills add anthropics/claude-code -s frontend-design -a '*' -g -y
npx skills add wshobson/agents -s wcag-audit-patterns -a '*' -g -y
npx skills add softaworks/agent-toolkit -s reducing-entropy -a '*' -g -y
npx skills add sickn33/antigravity-awesome-skills -s typescript-expert -a '*' -g -y
```

These are optional — local skills work without them but reference them for specialized tasks. See [`global-skills.md`](global-skills.md) for which local skills reference which external skills.

## Design Principles

- **Authoring test**: Every skill must address a task an LLM demonstrably handles worse without explicit guidance. No skills for general knowledge.
- **Cross-platform**: No tool-specific formats. Skills, agents, and AGENTS.md work in Cursor, Claude Code, and Codex without modification.
- **Progressive disclosure**: AGENTS.md is minimal (~65 lines). Skills load on demand. Reference files extract detail from skill bodies.
- **Evidence-based**: Claims in plans, reviews, and execution must be tagged E0–E3. Blocking claims require code evidence (E2+).
- **Self-contained**: No external registry or manifest system. Skills are plain markdown. The installer is a single bash script.

## Further Reading

- [Contributing guide](CONTRIBUTING.md) — authoring skills, subagents, and installer changes
- [Changelog](CHANGELOG.md) — version history and user-facing changes
- [External skills reference](global-skills.md) — optional skills from other repos
- [MIT License](LICENSE)
