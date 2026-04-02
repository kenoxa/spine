# Skills Reference

> Detailed descriptions of spine's workflow skills, subagents, and naming conventions. For a quick overview, see the [README](../README.md#workflow).

## Workflow Skills

### do (orchestrator)

Single entry point that chains `do-frame` → `do-design` → `do-build`. Stateful coordinator using redirect model — suggests next phase skill, tracks state in session-log.md. Supports skip validation (skip analyze if problem is clear, skip consult if direction is clear). Catch-all for features, bugs, issues, ideas, questions.

Canonical entry: [`skills/do/SKILL.md`](../skills/do/SKILL.md).

### do-frame

Socratic WHAT-focused dialogue composing `run-explore`. Phases: orient (invoke `/run-explore`) → clarify (mainthread + `/run-explore` on demand) → investigate (invoke `/run-explore`) → handoff. Produces `frame_artifact` with problem statement, constraints, blast radius, success criteria, key unknowns. Forbidden from prescribing HOW. WHAT/HOW escape hatch redirects to `/do-design` when feasibility knowledge is needed.

Canonical entry: [`skills/do-frame/SKILL.md`](../skills/do-frame/SKILL.md).

### do-design

Multi-model HOW direction composing `run-advise`. Thin orchestrator: intake (mainthread) → invoke `/run-advise` (batch dispatch + synthesis) → user decision gate. Disagreement-as-signal. User decision gate: approve → `/do-build`, push back → re-dispatch, reject → `/do-frame`. Cap 3 re-dispatch rounds.

Canonical entry: [`skills/do-design/SKILL.md`](../skills/do-design/SKILL.md).

### do-build

Automated build-review-polish loop composing `run-implement`, `run-review`, `run-polish`. Scope → `/run-implement` → `/run-review` ↔ `/run-implement` (fix) → `/run-polish` → finalize. Correctness loop (implement↔review, cap 3) then maintainability loop (polish until no E2+ findings, cap 3). Prototype completion gates (no mandatory test/doc gates).

Canonical entry: [`skills/do-build/SKILL.md`](../skills/do-build/SKILL.md).

### run-review

Structured code review with severity-bucketed findings and evidence-level gating. Four phases:

1. **Scope + Context** — classify depth, build understanding, emit review brief (Gate A); recommended Gate A2 writes `review-change-evidence.md` (diff/patch) for shared evidence with envoy.
2. **Inspect** — parallel dispatch: `@verifier` (plan/spec compliance + logic correctness + E3 probes) + `@inspector` (risk lens: security, perf, scale) + cross-provider `@envoy`. Verifier runs at standard and deep depth; focused depth is inline-only. Same `{review_brief_path}` / `{change_evidence_path}` for all roles and synthesis (see `use-envoy` per-phase evidence plane).
3. **Synthesis** — `@synthesizer` merges verifier VERDICT, inspector findings, and envoy output. VERDICT propagation: FAIL/PARTIAL → blocking flag in synthesis header.
4. **Output** — conflict resolution, severity re-sort, user-facing findings, visual diff report.

Findings are bucketed as `blocking` (must fix, E2+ required), `should_fix` (recommended, blocks unless deferred), or `follow_up` (tracked debt). Review is read-only — `@verifier` may run non-destructive commands (build, test, lint) for E3 probes; all other agents are read-only.

Canonical entry: [`skills/run-review/SKILL.md`](../skills/run-review/SKILL.md).

### run-debug

Four-phase root-cause diagnosis:

1. **Observe** — reproduce deterministically. Capture exact error, steps, environment, and variance.
2. **Pattern** — generate 5–7 falsifiable hypotheses from distinct failure classes. Narrow to 1–2 on static evidence; deprioritize remaining candidates.
3. **Hypothesis** — static analysis first; instrument only when insufficient. Broad instrumentation, one reproduction pass per cycle, eliminate in bulk. Remove all instrumentation before closing.
4. **Harden** — apply the smallest fix that resolves the confirmed root cause. Harden to make the bug class impossible. Verification requires E3 evidence.

Escalation: after 3 failed hypotheses, escalate with concrete evidence. Architectural uncertainty → re-enter planning.

Canonical entry: [`skills/run-debug/SKILL.md`](../skills/run-debug/SKILL.md).

### run-insights

Periodic cross-tool session analysis. Python scripts parse raw session data from Claude Code, Codex, and Cursor (~256 MB) into structured analytics (~100 KB), then subagents mine it for automation opportunities.

1. **Collect** — run parser scripts to extract and normalize session data from all three tools into `analytics.json`.
2. **Analyze** — dispatch source-expert `@miner` subagents in parallel (one per provider with sessions) to identify provider-specific patterns.
3. **Synthesize** — `@synthesizer` merges all expert outputs into recommendations across 7 categories: skills, hooks, MCP servers, plugins, agents, CLAUDE.md rules, and anti-patterns.
4. **Present** — activity stats table and prioritized recommendations in the terminal. HTML dashboard via `@visualizer`.

Every recommendation includes evidence (session counts, specific examples) and a concrete action. Cross-tool patterns — the same workflow repeated across multiple tools — are the highest-value findings.

Requires Python 3.9+ on `PATH`. On supported Homebrew setups, Spine can install Python 3 as part of its installer-managed host CLI tools. Otherwise, provide a compatible interpreter yourself. Run weekly or bi-weekly.

Canonical entry: [`skills/run-insights/SKILL.md`](../skills/run-insights/SKILL.md).

### run-explore

Bounded codebase exploration and architecture mapping. Answers "what's there?" — single-pass reconnaissance. For "what should we do about it?" use `do-frame` instead.

Standalone invocation dispatches role-specific subagents (scout for breadth, researcher for depth, navigator for external research), synthesizes findings, and optionally generates visual recaps via `@visualizer`. Also invoked as a phase skill by `do-frame` (orient, clarify probes, investigate).

Canonical entry: [`skills/run-explore/SKILL.md`](../skills/run-explore/SKILL.md).

### run-research

Compile structured research prompts for external deep research UIs (ChatGPT Deep Research, Claude). Acts as a prompt compiler — auto-gathers project context via gated subagent dispatch (`@scout` for standard depth, `@researcher` for deep), applies security redaction, and outputs a paste-ready prompt optimized for the target UI.

Three-outcome gather gate: zero-dispatch for purely external goals with no codebase dependency, `@scout` (Fast/haiku) for standard breadth-first context, or `@researcher` (Standard/sonnet) for `--depth deep` with call chains and evidence tables. Single adaptive template with inline UI adaptation table handles per-provider formatting differences. Compile-only in v1; paste-back ingest deferred to v2.

Canonical entry: [`skills/run-research/SKILL.md`](../skills/run-research/SKILL.md).

### run-curate

Project knowledge lifecycle management: promote, review, prune, maintain. Thin orchestrator dispatching `@curator` (read-only, sonnet-tier). Two modes: auto-triggered from build-finalize when `knowledge_candidate: yes` items exist, or standalone for full knowledge review. Gathers existing AGENTS.md `## Project Knowledge` entries, dispatches curator for evaluation, presents curation plan, applies on user approval.

Knowledge files live in `docs/` — telegraphic, 250-800 tokens, `updated:` frontmatter. AGENTS.md index uses backticked paths (not markdown links) to prevent auto-loading.

Canonical entry: [`skills/run-curate/SKILL.md`](../skills/run-curate/SKILL.md).

### run-implement

Scoped code implementation with partition-parallel dispatch. Works standalone ("implement this") and as an embedded phase in `do-build`. Three phases: scope (mainthread) → implement (`@implementer` per partition) → report (mainthread). Fix mode: when invoked with `fix_context`, applies minimal fixes to blocking findings instead of full implementation.

Canonical entry: [`skills/run-implement/SKILL.md`](../skills/run-implement/SKILL.md).

### run-advise

Multi-model perspective gathering with synthesis. Works standalone ("advise on this approach") and as an embedded phase in `do-design`. Dispatches `@consultant` (rigorous + creative angles) + `@navigator` + `@envoy` → `@synthesizer`. Produces `advise_artifact` with convergence/divergence map, tradeoffs, falsification risks. Standalone: thin input gets grounding question; embedded: dispatches directly from `frame_artifact`. Orchestration passes `{source_artifact_path}` so the synthesizer and envoy share the same authoritative on-disk artifact as the decision object (see `references/advise-synthesis.md`).

Canonical entry: [`skills/run-advise/SKILL.md`](../skills/run-advise/SKILL.md).

### run-polish

Advisory code polish with 2-3 conditional lenses: conventions + complexity default; performance-sensitive scopes swap conventions for efficiency (hot-path loops, async/concurrency, N+1, explicit perf requirements). All 3 lenses at deep depth.

Canonical entry: [`skills/run-polish/SKILL.md`](../skills/run-polish/SKILL.md).

### commit

Scoped staging with conventional commits.

Canonical entry: [`skills/commit/SKILL.md`](../skills/commit/SKILL.md).

### handoff

Distill session context into a structured prompt for a fresh session.

Canonical entry: [`skills/handoff/SKILL.md`](../skills/handoff/SKILL.md).

### catchup

Reconstruct working state from persisted session artifacts after `/clear` or auto-compaction. Reads `.scratch/<session>/session-log.md`, `handoff-*.md`, and `plan.md` to rebuild the state inventory.

Canonical entry: [`skills/catchup/SKILL.md`](../skills/catchup/SKILL.md).

### run-recap

Summarize work done across AI agent sessions for standups, timesheets, and activity reports. Three output formats:

- **standup** — bullet points grouped by project with estimated durations
- **timesheet** — billable hour blocks in a 9-17 window, copy-pasteable into time tracking tools
- **recap** — narrative summary with per-project sections and metrics

Reuses `run-insights/scripts/` for session collection. Two phases: a single `@miner` dispatch collects session data and formats the report per template, then mainthread presents the output with optional `@visualizer` HTML dashboard.

Requires Python 3.9+ on `PATH`. On supported Homebrew setups, Spine can install Python 3 as part of its installer-managed host CLI tools. Otherwise, provide a compatible interpreter yourself.

Canonical entry: [`skills/run-recap/SKILL.md`](../skills/run-recap/SKILL.md).

## Subagents

| Agent | Tier | Model | Effort | Purpose |
|-------|------|-------|--------|---------|
| `scout` | Fast | haiku | medium | Fast codebase reconnaissance |
| `researcher` | Standard | sonnet | high | Deep discovery and evidence gathering; local-depth first, may do bounded plan-specific upstream lookup |
| `navigator` | Standard | sonnet | high | External-first research specialist for broad, ambiguous, comparative, or current external work |
| `consultant` | Standard | sonnet | high | Perspective-committed recommendation for `do-design` |
| `curator` | Standard | sonnet | high | Knowledge curation — promote, review, prune knowledge files |
| `debater` | Frontier | opus | high | Multi-perspective Socratic dialogue |
| `inspector` | Frontier | opus | high | Verdict-focused code review, preloads `run-review` |
| `analyst` | Standard | sonnet | high | Advisory pattern analysis, preloads `run-review` and `run-polish` |
| `verifier` | Frontier | opus | high | Correctness, spec compliance, and E3 verification probes in quality phase and standalone run-review; preloads `with-testing` (test boundary decisions + mock strategy) |
| `miner` | Fast | haiku | medium | Session data analysis and cross-session pattern extraction |
| `visualizer` | Standard | sonnet | high | HTML visualization via visual-explainer commands, preloads `visual-explainer` |
| `implementer` | Standard | sonnet | high | Read-write implementation for plan-driven code changes |
| `envoy` | Standard | sonnet | high | Cross-provider CLI invocation for independent perspectives |
| `synthesizer` | Frontier | opus | high | Merge subagent outputs — thin-orchestrator firewall step |

See [model-selection.md](model-selection.md) for provider mappings and tier details.

## Skill Prefix Convention

Prefixes group skills in slash-autocomplete — type `do-`, `run-`, `with-`, or `use-` to filter to the category you need.

| Prefix | Semantic | When to use |
|--------|----------|-------------|
| `do-` | Primary flow | The workflow chain: frame → design → build |
| `run-` | Utilities | Standalone actions invoked any time: debug, review, polish, insights, recap |
| `with-` | Domain constraints | Applied passively when the task matches a specific domain — backend, frontend, terminology, testing |
| `use-` | Operational tools | Invoked explicitly — utilities, conventions, and cross-provider tooling |

**Plain names** (`commit`, `handoff`, `catchup`): invoked by name — no prefix because they're used directly, not discovered by category.

**Why prefixes?** Without them, spine's skills get lost among globally installed skills in slash-autocomplete. Typing the first few characters of a prefix immediately narrows the list to the relevant group.

External skills keep their upstream names and do not follow this convention — we don't own those names. Public install examples intentionally use `npx skills add` to match [`skills.sh`](https://skills.sh/); the installer may bootstrap the same CLI through another launcher.
