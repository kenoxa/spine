---
spec: 2622-catalog-audit
session: spine-goal-compiler-followon-bundle-cd10
updated: 2026-05-26
status: audit
scope: skills/run-* + skills/use-*
verdict_execution: out-of-scope
---

# Catalog audit — `run-*` + `use-*`

Verdict-only audit. Execution (file moves, deletions, AGENTS.md rewrites) is
**out of scope** per the bundle frame artifact. Outputs feed a later
consolidation slice if/when DELETE evidence ripens.

## 1. Methodology

Heuristic (frame artifact Decision Q5): **structural-role + capability uniqueness + 30d invocation evidence**.

| Verdict | Criterion |
|---------|-----------|
| **RETAIN** | Structurally unique role AND/OR observed invocations ≥1 in window AND/OR invoked by another in-tree skill |
| **FOLD** | Substantial role overlap with a peer skill, no orthogonal capability, no in-tree caller |
| **DEFER-DELETE** | No observed invocations in window AND not called by another skill — but pre-repair telemetry undercounts model-side Skill tool calls, so DELETE is blocked until post-repair data accumulates |

**Window:** 2026-05-12 → 2026-05-26 (14d, 104 Claude sessions). Codex sessions excluded — different tool surface; Codex telemetry tracks `update_plan` not Skill calls.

**Telemetry caveat:** the source dataset (`.scratch/goal-vs-workflow-insights-e0c0/claude_sessions.json`) was generated **before** the Slice 0 `parse_claude.py` repair landed. Pre-repair `skills_used` only captures **user `/command-name` slash invocations** — it does NOT capture model-side `Skill` tool calls (which are how `/goal` orchestration dispatches `run-implement`, `run-polish`, `run-review`, `run-curate`, etc.). Consequently:

- A high count is **proof of use** (RETAIN-supporting).
- A zero count is **NOT proof of disuse** — it may be entirely orchestrated invocations invisible to pre-repair telemetry.
- DELETE verdicts therefore DEFER pending ≥30d of post-repair data.

The 30d window in the heuristic relaxes to "available window" for this audit (14d) — same direction, weaker signal.

## 2. Inventory

### 2.1 `run-*` (14 skills)

| Skill | Structural role | Invoked by (in-tree) |
|-------|-----------------|----------------------|
| `run-advise` | Multi-perspective advisory dispatch (parallel lens subagents) on a fresh problem | user (slash); `use-goal-prompt` build/design discipline (model-side) |
| `run-architecture-audit` | Whole-codebase coupling / module-depth / dependency-direction lint | user (slash); typically standalone |
| `run-council` | Lens-based stress-test of an **existing recommendation** (post-`/run-advise` critique) | user (slash); often paired with `run-advise` synthesis |
| `run-curate` | Knowledge-file curation (promote/update/prune `docs/`); also terminal-gate mode (Slice 6) | user (standalone); `use-goal-prompt` build discipline (`--terminal`) |
| `run-debug` | Failure-driven diagnosis (failing tests, regressions, flakes) | user (slash); model-side from `/goal` build-loops on test failure |
| `run-discuss` | Interactive narrowing / clarifying an under-specified problem | user (slash); often pre-frame |
| `run-explore` | Codebase mapping / "how does X work" exploration | user (slash); model-side from frame discipline |
| `run-implement` | Partition-parallel scoped implementation across distinct file partitions | model-side from build discipline |
| `run-insights` | Session telemetry analytics (skills_used, friction, outcome) | user (slash) |
| `run-merge` | Git conflict resolver given a self-contained merge brief | user (slash) |
| `run-polish` | Convention/complexity polish, bounded scope; called between inspector iterations | model-side from build discipline (per `phase-discipline-build.md`) |
| `run-recap` | Time-bucketed reporting (standup / timesheet / recap formats) | user (slash) |
| `run-research` | Compiles a research handoff prompt for ChatGPT/Claude with depth tuning | user (slash) |
| `run-review` | Code/PR review methodology dispatching `@inspector` for gate decisions | model-side from build discipline; user (slash) |

### 2.2 `use-*` (9 skills)

| Skill | Structural role / capability | Invoked by (in-tree) |
|-------|------------------------------|----------------------|
| `use-browser` | Page navigation, form fill, screenshot capability | user (slash); rarely chained |
| `use-envoy` | Cross-provider dispatch (frontier multi-provider) — **NOT standalone** | `run-curate` (Dispatch phase); `run-council` (envoy variant) |
| `use-goal-prompt` | Smart goal-prompt compiler (interrogate → plan → build → harden …) | user (`/goal`, `/use-goal-prompt`); foundational orchestrator |
| `use-js` | JS/TS package ops via `ni` wrapper | user (slash); model-side on any JS task |
| `use-session` | Session state contract (init/attach/update/attention/terminal) + `events.jsonl` substrate | `use-goal-prompt` phase discipline; `use-worktree`; `_task_adapter.sh` |
| `use-shell` | Shell scripting, structural search (`sg`), semantic search (`probe`) | user (slash); model-side on shell tasks |
| `use-skill-craft` | Skill/agent authoring patterns + AGENTS.md curation | user (slash) |
| `use-worktree` | git worktree CRUD + session-slug auto-derivation (G1 from Slice 3) | user (slash) |
| `use-writing` | Docs / changelog / release-notes / artifact authoring | user (slash) |

## 3. Verdicts

### 3.1 RETAIN (all 23)

Every skill earned RETAIN under at least one criterion. Summary by basis:

| Basis | Skills |
|-------|--------|
| **Observed invocations in window** | `use-goal-prompt` (10), `run-advise` (3), `run-merge` (1), `run-insights` (1) |
| **Invoked by another in-tree skill** (callers above) | `run-curate`, `run-implement`, `run-polish`, `run-review`, `run-debug`, `run-explore`, `run-council`, `use-envoy`, `use-session`, `use-shell`, `use-js`, `use-writing` |
| **Structurally unique role** (no peer overlap) | `run-architecture-audit`, `run-discuss`, `run-recap`, `run-research`, `use-browser`, `use-skill-craft`, `use-worktree` |

### 3.2 FOLD (none)

The three closest pairs were inspected for fold candidacy and **rejected**:

| Pair | Apparent overlap | Why distinct |
|------|------------------|--------------|
| `run-advise` vs `run-council` | Both multi-lens, multi-subagent | `run-advise` generates options on a fresh problem; `run-council` stress-tests an **existing recommendation**. Inputs differ (problem vs synthesis), outputs differ (options vs critique). |
| `run-explore` vs `run-architecture-audit` | Both read-only codebase analysis | `run-explore` is question-driven ("how does X work?"); `run-architecture-audit` is structural lint with verdicts (coupling, depth). Different exit criteria. |
| `run-recap` vs `use-writing` | Both produce text artifacts | `run-recap` ingests session telemetry into format-templated reports; `use-writing` is methodology for human-authored docs. Different input substrate. |

### 3.3 DEFER-DELETE (none — telemetry-blocked, not zero-candidates)

No skill qualifies for DELETE under the heuristic at this time. Skills with **zero observed slash invocations** in the 14d window — `run-architecture-audit`, `run-council`, `run-curate` (standalone), `run-debug`, `run-discuss`, `run-explore`, `run-implement`, `run-polish`, `run-research`, `run-review`, `use-browser`, `use-envoy`, `use-js`, `use-session`, `use-shell`, `use-skill-craft`, `use-worktree`, `use-writing` — are **NOT** auto-promoted to DELETE because:

1. **Pre-repair undercount** (see §1 caveat) — many of these are model-side orchestrated.
2. **In-tree callers** — every one above is referenced by another skill or by phase discipline.
3. **Frame Q5 binding** — DELETE criterion requires reliable invocation data, blocked on `parse_claude.py` repair (now landed in Slice 0; needs window to accumulate).

## 4. Invocation evidence (14d, slash only)

Source: `.scratch/goal-vs-workflow-insights-e0c0/claude_sessions.json`, aggregated:

```
41  /goal                      ← compiles to use-goal-prompt
25  /clear                     ← built-in, not a spine skill
10  /use-goal-prompt
 7  /effort                    ← built-in
 3  /catchup                   ← external
 3  /review                    ← maps to run-review when invoked
 3  /run-advise
 2  /model                     ← built-in
 1  /copy
 1  /do-build                  ← deprecated, now folded into /use-goal-prompt
 1  /do-design                 ← deprecated
 1  /run-insights
 1  /run-merge
 1  /spine:run-skill-eval      ← external plugin
```

**Direct `run-*` evidence:** `run-advise=3`, `run-insights=1`, `run-merge=1`. **Direct `use-*` evidence:** `use-goal-prompt=10`. **Indirect:** `/goal=41` invokes `use-goal-prompt` → which dispatches `run-implement`/`run-polish`/`run-review`/`run-curate` orchestrated, invisible to pre-repair telemetry.

## 5. Follow-on

| # | Action | When |
|---|--------|------|
| 1 | Re-aggregate Claude sessions with **post-repair** `parse_claude.py` (Slice 0) | After 30d of post-2026-05-26 sessions accumulate |
| 2 | Re-run this audit with model-side Skill-call data | After (1) |
| 3 | Promote any DEFER-DELETE → DELETE only if **both** zero slash invocations AND zero model-side Skill calls in 30d window | Gated on (2) |
| 4 | Re-examine fold candidates if invocation distributions shift (e.g., `run-advise`/`run-council` both fall to near-zero from same caller pattern) | Gated on (2) |
| 5 | External-sync audit (with-* + claude/, opencode/, cursor/) — explicitly **out of scope** per frame Q5 | Separate spec if/when raised |

## 6. Status

- Verdicts issued: **23 RETAIN, 0 FOLD, 0 DELETE** (per heuristic; DELETE is telemetry-blocked, not "no candidates exist")
- No execution required this slice (out-of-scope per frame).
- No follow-on TODO unless step 1 trigger fires.
