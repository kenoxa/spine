---
spec: 2622-phase-loop
updated: 2026-05-26
session: spine-goal-compiler-followon-bundle-cd10
status: design
slices: [A (#2 phase self-transition), B (#4 task-tool adapter), C (#5 run-curate terminal gate)]
includes_section: worktree-session-invariants (folded from frame Item #3 per A3)
---

# Phase Loop — Design Spec

## 1. Problem

The workflow-consolidation (commits `6507c18`+`bdb4824`) collapsed `do-frame`/`do-design`/`do-build` into a `/use-goal-prompt` smart-compiler. The compiler now emits a single `/goal` prompt per phase, and a user manually invokes `/goal` again to advance. This spec formalizes the autonomous-`/goal` lifecycle the consolidation enabled but did not specify:

- **#2** — phase self-transition (Slice A): how does an autonomous run advance from `frame → design → build` without requiring user re-launch?
- **#4** — task-tool integration (Slice B): how does the workflow emit task-tracker events at phase boundaries across provider differences?
- **#5** — run-curate terminal gate (Slice C): how does an autonomous run land its session learnings before terminal-artifact emission?

These three concerns share a single substrate (the phase-boundary event), and so live in one spec / three build slices.

Frame §5 Item #3 (worktree+session) folds in as §6 "Worktree-Session Invariants" per assumption A3 — the invariants describe session-state semantics that the phase-loop relies on.

## 2. Phase-Boundary Event (shared contract)

The phase-boundary event is the **single integration point** between Slices A/B/C. All three slices read or write events of this shape.

**Event name:** `phase.boundary`
**Storage:** appended to `.scratch/<session>/events.jsonl` by the mainthread agent
**Shape:**

```json
{
  "seq": <monotonic integer>,
  "ts": "<ISO8601 UTC>",
  "type": "phase.boundary",
  "actor": "mainthread",
  "session_id": "<slug>-<hash>",
  "from_phase": "frame" | "design" | "build" | null,
  "to_phase":   "design" | "build" | "complete",
  "artifact_path": ".scratch/<session>/<artifact>.md",
  "trigger": "auto" | "user" | "halt",
  "branch": "<current branch>",
  "worktree": "<absolute path>"
}
```

**Emission rules:**
- Mainthread emits `phase.boundary` immediately after writing the phase's artifact (frame-artifact.md, design-artifact.md) or just before emitting `build-status.json`.
- `from_phase=null` is reserved for the initial boundary (Classify→Compose start), not produced by every flow.
- `to_phase="complete"` marks the terminal boundary; Slice C runs `/run-curate` just before this event is emitted.
- `trigger="user"` indicates the user manually advanced; `auto` indicates the system self-transitioned; `halt` indicates a stop signal (review cap, divergence, blocking unknown) interrupted the loop.

**Phase Trace correspondence:** every `phase.boundary` event has a matching row in `session-log.md` (the human-readable Phase Trace). Both must agree on `from_phase`/`to_phase`/`trigger`.

## 3. Slice A — Phase Self-Transition (#2)

### 3.1 Options considered

| ID | Mechanism | Provider coverage | Cost |
|----|-----------|------------------|------|
| (a) | Stop-hook detects phase-complete + **user re-launches** `/goal` | Claude Code only (Stop hook); Codex: N/A; Cursor: limited | Lowest — keeps user in loop |
| (b) | **Autonomous re-launch** — mainthread emits `phase.boundary` and composes the next phase's prompt in the same conversation, continuing without user intervention | Claude Code (Stop-hook-aware), Codex (single-prompt continuation by STOP RULES), Cursor (Stop-equivalent) | Medium — requires phase-aware mainthread, but reuses existing artifact-emission flow |
| (c) | **Multi-phase super-prompt** — `/use-goal-prompt` compiles ALL phases into a single mega-prompt at compose time | Provider-uniform | High — blows 4000-char cap; phase boundaries become soft (no `phase.boundary` event per phase) |

### 3.2 Chosen: **(b) autonomous re-launch**

**Rationale:**
- **(a) defeats autonomous mode.** The whole point of `/goal` is user-out-of-loop until terminal. Adding mandatory user re-launch between phases is a regression.
- **(c) breaks the 4000-char cap** (SPINE.md K1 invariant). Inlining frame+design+build phase content into one prompt would push past the limit on every non-trivial task. Phase boundaries also become unrecoverable: there is no per-phase artifact to halt on, no per-phase Phase Trace, no per-phase rollback authority.
- **(b) is the natural extension of how `/goal` already works in Claude Code.** A session-scoped Stop hook today already blocks termination until a condition holds; adding a phase-aware composer to mainthread (read frame-artifact → compose design prompt → continue) is incremental, not architectural. Codex sessions handle phase chaining via STOP RULES already (the goal-prompt's STOP RULES section lists the full arc); Slice A just makes the same chaining work for interactive `/goal` flows on Claude Code.

### 3.3 Contract

**Mainthread responsibilities at each phase boundary:**

1. Write the phase artifact (frame-artifact.md, design-artifact.md, or build-status.json) atomically.
2. Append `phase.boundary` event to `events.jsonl` with the field shape from §2.
3. Append a corresponding row to `session-log.md` Phase Trace.
4. If `to_phase != "complete"` and `trigger == "auto"`:
   a. Read the next phase's template (`skills/use-goal-prompt/references/template-{next-intent}.md`).
   b. Read the next phase's discipline reference (`references/phase-discipline-{next}.md`).
   c. Compose the next phase prompt with the same session context.
   d. Continue executing in the same conversation.
5. If `to_phase == "complete"`: invoke `/run-curate` (Slice C) BEFORE writing build-status.json terminal.
6. If `trigger == "halt"`: emit artifact + halt; do not self-transition.

**Stop hook responsibility (Claude Code only):**
- The session-scoped Stop hook reads `events.jsonl` and blocks termination until either:
  - A `phase.boundary` event with `to_phase == "complete"` AND `trigger != "halt"` is present, OR
  - A `phase.boundary` event with `trigger == "halt"` is present (terminal halt — emit and stop)
- The Stop hook does NOT trigger phase transitions; mainthread does. The hook is a guardrail, not a driver.

**Codex contract:**
- Codex sessions are batch-executor; the goal-prompt's STOP RULES already enumerate the multi-phase arc. Slice A on Codex is satisfied if mainthread emits the `phase.boundary` events at the same points as Claude Code. No additional infrastructure required.
- Cursor / OpenCode: same as Codex (use the prompt's STOP RULES; mainthread emits events).

### 3.4 Recovery on failure

If composing the next phase fails (template missing, discipline ref unreadable):
- Emit `phase.boundary` with `trigger="halt"`, `to_phase=<intended>`, plus a `reason` field describing the composition failure.
- Write `build-status.json` with `status=blocked`, `reason="phase-transition-failure"`, include the missing path.
- User picks up via the standard blocked-session recovery flow.

### 3.5 E3 exit gate

- Construct a small fixture: a goal-prompt that triggers frame → design transition.
- Run autonomously; observe (a) `phase.boundary` event with `from_phase=frame, to_phase=design, trigger=auto` in events.jsonl, (b) corresponding Phase Trace row in session-log.md, (c) design-phase artifact present at end.

## 4. Slice B — Provider-Aware Task-Tool Adapter (#4)

### 4.1 Problem

Each provider exposes a different task tracker:
- Claude Code: `TaskCreate` / `TaskUpdate` / `TaskList` (built-in).
- Codex: `update_plan` (built-in plan tracker).
- Cursor: no built-in task tracker; rules + scratchpad.
- OpenCode: TBD per provider's tooling.

The phase-loop needs to surface phase transitions in the provider's task surface so the user can see progress at a glance.

### 4.2 Adapter contract

A **provider-aware task adapter** lives in each provider's plugin/integration layer. It listens for `phase.boundary` events and fires the provider's task-tracker API:

| Provider | On `phase.boundary` (auto-transition) | On `phase.boundary` (halt) |
|----------|---------------------------------------|---------------------------|
| Claude Code | `TaskUpdate` previous phase → completed; `TaskCreate` for next phase | `TaskUpdate` current → blocked or completed |
| Codex | `update_plan` move current step → completed; advance next step → in_progress | `update_plan` mark current → in_progress with note |
| Cursor | Append to session-log.md only (no native tracker) | Same — log-only |
| OpenCode | TBD via `opencode/spine-hooks.ts` | TBD |

### 4.3 Wiring

The adapter is invoked from mainthread immediately after `phase.boundary` event emission (step 2 in §3.3). Mainthread does not directly call provider APIs — it calls a thin shim (`hooks/_task_adapter.sh` for shell-side, or an inline helper script depending on provider). The shim dispatches based on detected provider:

```
provider detected via: $CLAUDE_CODE / $CODEX_ENV / $CURSOR / fallback to "unknown"
```

For "unknown" provider, the adapter is a no-op (the workflow still works; only the task-tracker UX is missing).

### 4.4 E3 exit gate

- Autonomous `/goal` run on Claude Code shows `TaskCreate` events at phase boundaries (E3 via TaskList output or events.jsonl correlation).
- Same run replayed on Codex shows `update_plan` calls with phase-aligned step transitions.

## 5. Slice C — `/run-curate` Terminal Gate (#5)

### 5.1 Contract

Immediately before mainthread writes the terminal `build-status.json` (i.e., the `phase.boundary` event with `to_phase="complete"`), mainthread invokes `/run-curate` as a discipline atom.

`/run-curate` reads the session's `session-log.md`, `frame-artifact.md`, `design-artifact.md`, and build-status candidate to produce a curate report at `.scratch/<session>/curate-report.md`. The terminal `build-status.json` includes a reference to this curate report in its `learnings` field.

### 5.2 Invocation

```
mainthread → /run-curate --session=<session-id> --terminal
```

The `--terminal` flag signals that curate runs in terminal-gate mode (read-only on session artifacts, write curate-report.md only). It does NOT trigger a full project-knowledge promotion pass — that remains user-initiated.

### 5.3 Failure mode

If `/run-curate` fails or times out (>60s):
- Mainthread writes the terminal `build-status.json` with `learnings: { curate_status: "failed", curate_error: "<message>" }`.
- The workflow still terminates cleanly; the curate report is optional, not blocking.

### 5.4 E3 exit gate

- Autonomous `/goal` run reaches terminal; `.scratch/<session>/curate-report.md` exists.
- `build-status.json` references `curate-report.md` path in its learnings field.

## 6. Worktree-Session Invariants (folded from Item #3 per A3)

The phase-loop assumes a stable session-and-worktree pairing. These invariants codify the existing partially-implemented model in `use-worktree` + `use-session`.

| ID | Invariant | Source / Enforcement |
|----|-----------|---------------------|
| **C1** | **1:1:1 hierarchy** — one `/goal` invocation owns exactly one session directory and at most one worktree. | mainthread; verified by session.json's `session_id` field |
| **C2** | **Sub-agent layout** — sub-agents dispatched within a goal share the parent session and worktree. Sub-agents NEVER fork a new worktree or new session. | SPINE.md "Subagents" §; `use-session` SKILL.md directive 3 |
| **C3** | **Multi-writer contract** — only mainthread writes `session.json`, `events.jsonl`, `session-log.md`. Sub-agents write their own assigned artifact paths only. | `use-session` SKILL.md directive 3 |
| **C4** | **Attach-not-fork** — an agent entering a bridged worktree attaches to the existing session (`/use-session attach`), never creates `.scratch/<new-session>/`. | `use-session` SKILL.md directive 7 |
| **C5** | **≤6 sub-agents per dispatch** — a single Agent-tool turn may dispatch up to 6 sub-agents (SPINE.md K5). | SPINE.md "Subagents" cap |
| **C6** | **Cross-goal isolation** — different `/goal` invocations use different sessions AND different worktrees. No artifact bleed between goals. | mainthread; one session = one `.scratch/<slug>-<hash>/` |
| **C7** | **Solo-dev model** — single user, no multi-writer locking, no concurrent session ownership. If conflict detected (different branch / different writer), `use-session` fails closed with `attention_required`. | SPINE.md K3; `use-session` SKILL.md directive 4 |

**Implementation gap G1 (in-scope for Slice 3 build):** session-slug auto-passthrough — `worktree.sh create` should derive its slug from the active session when not explicitly provided, so the worktree-session pairing is set up without manual re-typing of the same identifier. Detail in Slice 3 build deliverable (`use-worktree`).

**Out of scope (deferred per frame §5 Item #3):**
- G2 — parallel-agent merge primitive (cross-worktree merge orchestration).
- G3 — multi-worktree-per-goal merge invariant (the hypothetical "multiple worktrees serve one goal" case; solo-dev single-worktree model holds for now).
- Multi-user locking semantics for `events.jsonl`.

## 7. Slice ordering

Per frame §6, Slices A → B || C (B and C may run in parallel after A lands the boundary contract). Slice 3 worktree-session implementation (G1 + C1-C7 documentation) runs parallel to design per frame §6.

## 8. Non-goals

| # | Non-goal |
|---|----------|
| 1 | Redesigning `/run-curate` internals (only the terminal-gate invocation surface). |
| 2 | Renaming `/use-goal-prompt` (rejected per frame §4). |
| 3 | Inlining phase-discipline content into goal-prompt (cap-bound K1). |
| 4 | Cross-provider `phase.boundary` event broadcasting beyond session-local `events.jsonl`. |
| 5 | Polling / watch integrations (decline branch per use-goal-prompt SKILL.md). |
| 6 | Multi-worktree-per-goal merge semantics (G2/G3 deferred). |

## 9. Success criteria

| Slice | Criterion | E-level |
|-------|-----------|---------|
| A | `phase.boundary` event shape implemented; autonomous frame→design transition observed in events.jsonl | E3 (fixture run + jq query) |
| B | At least one provider-aware adapter implementation present; phase.boundary triggers task-tracker call observable in tool_counts (Claude Code) or update_plan (Codex) | E3 (instrumented run + log diff) |
| C | `/run-curate` invocation present in mainthread's terminal path; curate-report.md exists in test session; build-status.json references it | E3 (artifact present + reference resolves) |
| Worktree-Session (folded) | C1-C7 written to docs; G1 implemented in `worktree.sh`; worktree creation without slug uses active session's slug | E3 (test: active session exists, `worktree.sh create` succeeds without arg, slug matches) |

## 10. Open risks

| ID | Risk | Mitigation |
|----|------|-----------|
| R1 | Mainthread phase-composer drift — composing the next phase requires the goal context survives in conversation; long sessions risk context compaction dropping the original goal. | Persist original goal-prompt + frame-artifact paths in `session.json`; mainthread re-reads at each composition step. |
| R2 | Stop hook + auto-transition race — Stop hook fires before mainthread emits `phase.boundary`. | Mainthread emits event FIRST, then writes artifact, then proceeds. Stop hook polls `events.jsonl` (read-only). |
| R3 | Provider adapter brittleness — Claude Code's TaskCreate API may change. | Adapter is a thin shim; provider API changes are localized. |
| R4 | `/run-curate` slow path stalls terminal emission. | 60s timeout + fail-soft (curate_status: failed in learnings). |
| R5 | Session.json single-writer race when sub-agent finishes near phase boundary. | C3 (multi-writer contract) — sub-agent never writes session.json; mainthread serializes. |
