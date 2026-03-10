# Skills Reference

> Detailed descriptions of spine's workflow skills, subagents, and naming conventions. For a quick overview, see the [README](../README.md#workflow).

## Workflow Skills

### do-discuss

Structured problem framing through tiered Socratic dialogue. Use when the problem is vague, ambiguous, or too broad for direct planning.

- **Tier 1** — Socratic dialogue: batch questions, track known/unknown inventory, converge on the core problem.
- **Tier 2** — (conditional) dispatch `@scout` or `@researcher` when codebase evidence is needed.
- **Tier 3** — (conditional) multi-perspective `@framer` team (stakeholder-advocate, systems-thinker, skeptic) for ambiguous scope with one-way-door decisions.

Produces a `problem_frame` artifact (goal, scope, constraints, key decisions, unknowns) and a confidence-gated handoff recommendation.

Canonical entry: [`skills/do-discuss/SKILL.md`](../skills/do-discuss/SKILL.md).

### do-plan

Five phases produce a self-sufficient, executable implementation plan:

1. **Discovery** — map the codebase: file scouting, docs exploration, external research. All claims tagged with evidence levels (E0–E3).
2. **Framing** — distill discoveries into a planning brief: goal, scope, constraints, key decisions, evidence manifest, and docs impact classification.
3. **Planning** — dispatch planners with distinct approach angles (conservative, thorough, innovative). Merge via consensus; rank by evidence level.
4. **Challenge** — adversarial review exposing hidden assumptions, underestimated risks, and unnecessary abstraction. Blocking findings require E2+ evidence and a better alternative.
5. **Synthesis** — assemble the final plan using the plan template. Validate self-sufficiency, test tasks, edge coverage, docs tasks, and completion criteria.

Ask checkpoints after discovery and after challenge ensure ambiguity is resolved before proceeding.

Canonical entry: [`skills/do-plan/SKILL.md`](../skills/do-plan/SKILL.md).

### do-execute

Six phases with built-in quality gates:

1. **Scope** — read the approved plan, classify depth (`focused`/`standard`/`deep`), partition work into independent and dependent groups.
2. **Implement** — one `@worker` per partition. Parallel for independent groups; sequential for dependent. No overlapping writes. Worker self-review before reporting.
3. **Polish** — advisory pass (read-only reviewers produce findings) → apply pass (workers fix). Every E2+ finding acknowledged or explicitly rejected.
4. **Review** — two stages: tests & docs (skip when no behavior changes and docs_impact is `none`), then adversarial review with multiple lenses. Blocking findings re-enter polish.
5. **Verify** — single verifier instance. All claims require E3 evidence (executed command + observed output).
6. **Finalize** — content gates check for test evidence, edge coverage, and docs. Learnings captured as proposals (never auto-applied).

Re-entry loop: blocking review findings → polish → review → verify. Capped at 5 iterations.

Canonical entry: [`skills/do-execute/SKILL.md`](../skills/do-execute/SKILL.md).

### do-review

Structured code review with severity-bucketed findings:

1. **Scope check** — confirm what was requested and what changed.
2. **Evidence check** — validate claims against current code and requirements.
3. **Spec compliance** — verify built behavior matches requested behavior.
4. **Risk pass** — correctness, security, performance, maintainability (scaled by risk level: low → spec + quality; medium → + testing depth; high → + security probe).
5. **Quality pass** — readability, cohesion, duplication, test adequacy, edge/failure coverage.

Findings are bucketed as `blocking` (must fix, E2+ required), `should_fix` (recommended, blocks unless deferred), or `follow_up` (tracked debt). Review is read-only — no file writes.

Canonical entry: [`skills/do-review/SKILL.md`](../skills/do-review/SKILL.md).

### do-debug

Four-phase root-cause diagnosis:

1. **Observe** — reproduce deterministically. Capture exact error, steps, environment, and variance.
2. **Pattern** — compare failing path with known-good reference. Narrow to the smallest collision zone.
3. **Hypothesis** — one hypothesis at a time. Change one variable per test. Failed hypothesis → return to observe, not forward.
4. **Harden** — apply the smallest fix that resolves the confirmed root cause. Harden to make the bug class impossible. Verification requires E3 evidence.

Escalation: after 3 failed hypotheses, escalate with concrete evidence. Architectural uncertainty → re-enter planning.

Canonical entry: [`skills/do-debug/SKILL.md`](../skills/do-debug/SKILL.md).

### do-history-insights

Periodic cross-tool session analysis. Python scripts parse raw session data from Claude Code, Codex, and Cursor (~256 MB) into structured analytics (~100 KB), then subagents mine it for automation opportunities.

1. **Collect** — run parser scripts to extract and normalize session data from all three tools into `analytics.json`.
2. **Analyze** — dispatch source-expert `@miner` subagents in parallel (one per provider with sessions) to identify provider-specific patterns.
3. **Synthesize** — a synthesizer `@miner` merges all expert outputs into recommendations across 7 categories: skills, hooks, MCP servers, plugins, agents, CLAUDE.md rules, and anti-patterns.
4. **Present** — activity stats table and prioritized recommendations in the terminal. Optional HTML dashboard via `visual-explainer`.

Every recommendation includes evidence (session counts, specific examples) and a concrete action. Cross-tool patterns — the same workflow repeated across multiple tools — are the highest-value findings.

Requires Python 3.9+. Run weekly or bi-weekly.

Canonical entry: [`skills/do-history-insights/SKILL.md`](../skills/do-history-insights/SKILL.md).

### do-polish

Advisory code polish with conventions, complexity, and efficiency lenses.

Canonical entry: [`skills/do-polish/SKILL.md`](../skills/do-polish/SKILL.md).

### do-commit

Scoped staging with conventional commits.

Canonical entry: [`skills/do-commit/SKILL.md`](../skills/do-commit/SKILL.md).

### do-handoff

Distill session context into a structured prompt for a fresh session.

Canonical entry: [`skills/do-handoff/SKILL.md`](../skills/do-handoff/SKILL.md).

### do-history-recap

Summarize work done across AI agent sessions for standups, timesheets, and activity reports. Three output formats:

- **standup** — bullet points grouped by project with estimated durations
- **timesheet** — billable hour blocks in a 9-17 window, copy-pasteable into time tracking tools
- **recap** — narrative summary with per-project sections and metrics

Reuses `do-history-insights/scripts/` for session collection. Dispatches a single `@miner` subagent to synthesize task descriptions and estimate durations from session metadata across Claude Code, Codex, and Cursor.

Canonical entry: [`skills/do-history-recap/SKILL.md`](../skills/do-history-recap/SKILL.md).

## Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| `scout` | haiku | Fast codebase reconnaissance, preloads `use-explore` |
| `researcher` | inherit | Deep discovery and evidence gathering, preloads `use-explore` |
| `planner` | inherit | Angle-committed planning, preloads `do-plan` |
| `debater` | inherit | Adversarial Socratic dialogue |
| `inspector` | inherit | Verdict-focused code review, preloads `do-review` |
| `analyst` | inherit | Advisory pattern analysis, preloads `do-review` and `do-polish` |
| `framer` | inherit | Perspective-committed problem framing |
| `verifier` | inherit | Adversarial verification with E3 evidence, preloads `with-testing` |
| `miner` | inherit | Session data analysis and cross-session pattern extraction |
| `worker` | inherit | Read-write implementation for plan-driven code changes |

## Skill Prefix Convention

Prefixes group skills in slash-autocomplete — type `do-`, `with-`, or `use-` to filter to the category you need.

| Prefix | Semantic | When to use |
|--------|----------|-------------|
| `do-` | Workflow commands | Multi-phase execution: planning, implementation, review, debugging, committing |
| `with-` | Domain standards | Applied passively when the task matches — UI, API, or test work |
| `use-` | Active tools | Invoked explicitly to produce artifacts or perform discovery |

**Why prefixes?** Without them, spine's 14 skills get lost among globally installed skills in slash-autocomplete. Typing the first few characters of a prefix immediately narrows the list to the relevant group.

External skills (installed via `npx skills add`) keep their upstream names and do not follow this convention — we don't own those names.
