# Skills Reference

> Detailed descriptions of spine's workflow skills, subagents, and naming conventions. For a quick overview, see the [README](../README.md#workflow).

## Workflow Skills

### use-goal-prompt

Read-only goal-prompt compiler with phase classification. Takes an intent template (`interrogate`, `plan`, `build`, `refactor`, `consolidate`, `harden`, `migrate`), classifies it into a workflow phase (frame / design / build), injects the matching phase-discipline block, and emits a structured 9-section goal prompt under a 4000-character hard cap. Overflows to a sibling `goal-brief.md` when needed. Use `--enrich` flag or let size-bound auto-enable kick in for richer prompts. Feed the emitted prompt to `/goal` for autonomous execution, or paste into your provider's chat.

Trigger phrases absorbed from the legacy do-* skills: "frame this", "scope this", "design", "plan the approach", "implement and review", "just ship it", "fix this", "add this".

Canonical entry: [`skills/use-goal-prompt/SKILL.md`](../skills/use-goal-prompt/SKILL.md).

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

Bounded codebase exploration and architecture mapping. Answers "what's there?" — single-pass reconnaissance. For "what should we do about it?" use `/use-goal-prompt interrogate` instead.

Standalone invocation dispatches role-specific subagents (scout for breadth, researcher for depth, navigator for external research), synthesizes findings, and optionally generates visual recaps via `@visualizer`. Also invoked as a phase skill by the frame phase of `/use-goal-prompt` (orient, clarify probes, investigate).

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

Scoped code implementation with partition-parallel dispatch. Works standalone ("implement this") and as an embedded phase in the build workflow. Three phases: scope (mainthread) → implement (`@implementer` per partition) → report (mainthread). Fix mode: when invoked with `fix_context`, applies minimal fixes to blocking findings instead of full implementation.

Canonical entry: [`skills/run-implement/SKILL.md`](../skills/run-implement/SKILL.md).

### run-advise

Multi-model perspective gathering with synthesis. Works standalone ("advise on this approach") and as an embedded phase in the design workflow. Dispatches `@consultant` (rigorous + creative angles) + `@navigator` + `@envoy` → `@synthesizer`. Produces `advise_artifact` with convergence/divergence map, tradeoffs, falsification risks. Standalone: thin input gets grounding question; embedded: dispatches directly from `frame_artifact`. Orchestration passes `{source_artifact_path}` so the synthesizer and envoy share the same authoritative on-disk artifact as the decision object (see `references/advise-synthesis.md`).

Canonical entry: [`skills/run-advise/SKILL.md`](../skills/run-advise/SKILL.md).

### run-council

Thinking-lens stress-test that sequences after `run-advise` at the design phase Phase 2. Dispatches 5 committed-perspective advisors (Contrarian, First Principles, Expansionist, Outsider, Executor) each reading only their own lens definition — no cross-lens visibility. Advisor outputs are anonymized (A–E, randomized order) and re-dispatched to the same 5 advisors for peer critique under anonymity. Chairman (`@synthesizer` + `council-synthesis.md` ref) ingests both advisor batch and peer reviews, then resolves conflicts and emits a single directional recommendation with Convergence Zones, Genuine Disagreements, Collective Blind Spots, and Falsification risks. Skip condition at Intake: when advise-synthesis has no divergence tags and `blast_radius.transitive` is empty, emits a ratified result without dispatching advisors.

Canonical entry: [`skills/run-council/SKILL.md`](../skills/run-council/SKILL.md).

### run-polish

Advisory code polish with 2-3 conditional lenses: conventions + complexity default; performance-sensitive scopes swap conventions for efficiency (hot-path loops, async/concurrency, N+1, explicit perf requirements). All 3 lenses at deep depth.

Canonical entry: [`skills/run-polish/SKILL.md`](../skills/run-polish/SKILL.md).

### run-merge

Brief-driven Git conflict resolver for merge, sync, or land operations. Consumes a self-contained merge brief, resolves only conflicts with clear semantic intent, writes an atomic `merge-verdict.json`, and requires caller-owned focused verification before landing.

Canonical entry: [`skills/run-merge/SKILL.md`](../skills/run-merge/SKILL.md).

### run-clawpatch

Async Clawpatch **review → classify → fix → revalidate** campaign driven over the external `clawpatch` CLI (0.4.0+). Explicit and stateful — it activates only on clawpatch-specific intent, never automatically. The mainthread orchestrates the CLI loop directly (clawpatch holds `.clawpatch/` locks, so findings are worked one at a time, not fanned out). Makes no provider/model/feature assumptions — those live in the project's own `clawpatch.config.json`.

- **Direct preflight** — `/run-clawpatch status` (or `--local-only`) runs `doctor`/`status`/dry-run, read-only, no worktree.
- **Recommended campaign** — `/goal /run-clawpatch --since <ref>`; `/goal` installs the Stop hook so the agent works the whole loop autonomously, and user-STOP gates become emit-artifact-and-halt signals.

Tiny scope surface (`--since` / `--days` / `--last-run` / `--all-open`, default `--last-run`), resolved by `scripts/resolve-scope.sh`. Five references cover scope resolution, worktree+session isolation, manual-feature ownership reconciliation (manual `*_manual.json` is source of truth; `review --since` is selection, not coverage proof), the per-finding fix→revalidate guardrail, and the final report. No `/run-*` calls (composition lives in `/goal`).

Canonical entry: [`skills/run-clawpatch/SKILL.md`](../skills/run-clawpatch/SKILL.md).

### commit

Scoped staging with conventional commits.

Canonical entry: [`skills/commit/SKILL.md`](../skills/commit/SKILL.md).

### handoff

Distill session context into a structured prompt for a fresh session.

Canonical entry: [`skills/handoff/SKILL.md`](../skills/handoff/SKILL.md).

### catchup

Reconstruct working state from persisted session artifacts after `/clear` or auto-compaction. Reads `session.json` and recent `events.jsonl` when present, falls back to `.scratch/<session>/session-log.md`, and reports contradictions without choosing a winner.

Canonical entry: [`skills/catchup/SKILL.md`](../skills/catchup/SKILL.md).

### run-recap

Summarize work done across AI agent sessions for standups, timesheets, and activity reports. Three output formats:

- **standup** — bullet points grouped by project with estimated durations
- **timesheet** — billable hour blocks in a 9-17 window, copy-pasteable into time tracking tools
- **recap** — narrative summary with per-project sections and metrics

Reuses `run-insights/scripts/` for session collection. Two phases: a single `@miner` dispatch collects session data and formats the report per template, then mainthread presents the output with optional `@visualizer` HTML dashboard.

Requires Python 3.9+ on `PATH`. On supported Homebrew setups, Spine can install Python 3 as part of its installer-managed host CLI tools. Otherwise, provide a compatible interpreter yourself.

Canonical entry: [`skills/run-recap/SKILL.md`](../skills/run-recap/SKILL.md).

## Operational Skills

### use-session

Workflow continuity contract for `.scratch/<session>/`. Maintains `session.json`, `events.jsonl`, and `session-log.md`; enforces one active writer; marks stale, contradictory, writer-conflicted, or missing-terminal state as attention-required instead of silently resolving it.

Canonical entry: [`skills/use-session/SKILL.md`](../skills/use-session/SKILL.md).

### use-worktree

Manual git-worktree lifecycle: create/list/remove/prune/sync/land. Worktrees live under `.worktrees/`, carry over gitignored local state, and attach to the existing bridged `.scratch` session rather than forking it.

Canonical entry: [`skills/use-worktree/SKILL.md`](../skills/use-worktree/SKILL.md).

## Subagents

| Agent | Tier | Model | Effort | Purpose |
|-------|------|-------|--------|---------|
| `scout` | Fast | haiku | medium | Fast codebase reconnaissance |
| `researcher` | Standard | sonnet | high | Deep discovery and evidence gathering; local-depth first, may do bounded plan-specific upstream lookup |
| `navigator` | Standard | sonnet | high | External-first research specialist for broad, ambiguous, comparative, or current external work |
| `consultant` | Frontier | opus | xhigh | Perspective-committed recommendation for the design phase |
| `curator` | Standard | sonnet | high | Knowledge curation — promote, review, prune knowledge files |
| `debater` | Frontier | opus | xhigh | Multi-perspective Socratic dialogue |
| `inspector` | Frontier | opus | xhigh | Verdict-focused code review, preloads `run-review` |
| `analyst` | Standard | sonnet | high | Advisory pattern analysis, preloads `run-review` and `run-polish` |
| `verifier` | Frontier | opus | xhigh | Correctness, spec compliance, and E3 verification probes in quality phase and standalone run-review; preloads `with-testing` (test boundary decisions + mock strategy) |
| `miner` | Fast | haiku | medium | Session data analysis and cross-session pattern extraction |
| `visualizer` | Standard | sonnet | high | HTML visualization via visual-explainer commands, preloads `visual-explainer` |
| `implementer` | Standard | sonnet | high | Read-write implementation for plan-driven code changes |
| `envoy` | Standard | sonnet | high | Cross-provider CLI invocation for independent perspectives |
| `synthesizer` | Frontier | opus | xhigh | Merge subagent outputs — thin-orchestrator firewall step |

See [model-selection.md](model-selection.md) for provider mappings and tier details.

## Skill Prefix Convention

Prefixes group skills in slash-autocomplete — type `run-`, `with-`, or `use-` to filter to the category you need.

| Prefix | Semantic | When to use |
|--------|----------|-------------|
| `run-` | Utilities | Standalone actions invoked any time: debug, review, polish, insights, recap |
| `with-` | Domain constraints | Applied passively when the task matches a specific domain — backend, frontend, terminology, testing |
| `use-` | Operational tools | Invoked explicitly — utilities, conventions, and cross-provider tooling |

**Plain names** (`commit`, `handoff`, `catchup`): invoked by name — no prefix because they're used directly, not discovered by category.

**Why prefixes?** Without them, spine's skills get lost among globally installed skills in slash-autocomplete. Typing the first few characters of a prefix immediately narrows the list to the relevant group.

External skills keep their upstream names and do not follow this convention — we don't own those names. Public install examples intentionally use `npx skills add` to match [`skills.sh`](https://skills.sh/); the installer may bootstrap the same CLI through another launcher.
