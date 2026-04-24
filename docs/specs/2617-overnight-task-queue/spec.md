---
id: 2617-overnight-task-queue
status: draft
updated: 2026-04-24
frame_artifact: .scratch/autonomous-overnight-task-queue-1034/frame-artifact.md
session_id: autonomous-overnight-task-queue-1034
---

# Overnight Autonomous Task Queue

## Goal

Add a Spine-native primitive that executes N pre-staged work packages sequentially overnight in fresh Claude Code processes, respecting a declared DAG of dependencies, surfacing morning-ready outcomes, and enforcing safety boundaries that prevent 3 AM rogue actions.

## Why

User currently manually orchestrates multi-session workflows: stages `handoff-<slug>.md` files in `.scratch/` in the afternoon, dispatches each to a fresh Claude Code session, tracks state as Phase Trace rows in a mainthread orchestrator session-log (e.g. `identity-scribe` `wave2-wave3-easy-items-dabf` — 42 rows, 100 KB). Work serializes because git worktree overhead is rejected. Result: user is a human queue runner during the day, nights idle.

External pattern (Ralph, Geoffrey Huntley 2025) proves the fresh-process-per-task model but ships with known failure modes: the Anthropic plugin OOMs at ~8 h (in-session stop-hook context accumulation), handmade bash loops lack dependency graphs / failure policy / rate-limit handling / safety rails. Spine fills the gap by composing session-log + handoff + do-build primitives into an autonomous pipeline with a machine-verifiable terminal check.

## Scope

### In (v1)

- Project-local queue at `.scratch/queue/`.
- Task unit = `handoff-<slug>.md` with queue frontmatter (`task_id`, `depends_on`, `max_iterations`, `on_failure`, `terminal_check`, `scope_files`, optional `entry_skill`).
- Inter-task execution: one fresh `claude -p` per task boundary.
- Intra-task execution: loop `claude -p` invocations until terminal check passes or `max_iterations` (default 10) reached.
- Terminal check: default artifact-based (`terminal_artifact: .scratch/<task-session>/build-status.json` from extended `do-build` finalize); escape hatch shell-expression.
- DAG dependency model; transitive dependents of failed tasks blocked; independent branches continue.
- Failure policy: stop-failing-subgraph default; `Build complete (partial)` = conditional pass; per-task `on_failure: stop|skip|retry_once` override.
- Rate-limit resilience: reuse envoy's `is_fast_failure()` pattern; exponential backoff, retry same provider.
- Permission profile: enforced via `claude -p --allowed-tools` / `--disallowed-tools` / `--permission-mode`. Blocked = destructive git, remote writes, out-of-project writes, package installs.
- Trip-wires → `.scratch/queue/WOKE-ME-UP.md` stopping the queue.
- Enqueue-time lint (static validation) refuses invalid queues before spawning any process.
- Streaming observability: every iteration runs with `--verbose --output-format stream-json | jq` teed to a real-time view and `.scratch/<task-session>/iterations/<N>.jsonl` (Matt Pocock / aihero.dev pattern).
- Morning `queue-report.md` at queue root with per-task status + links to JSONL transcripts for failed/partial tasks.
- Idempotent resume: re-running a completed queue skips succeeded tasks.

### Out (v2 or later)

- Cross-provider support (OpenCode, Codex, Cursor headless).
- Cron / systemd trigger.
- HTML visualizer dashboard for morning review.
- Cross-project global queue.
- Pre-flight dry-run execution.
- Hook-triggered loop control (rejected: reproduces Anthropic plugin failure mode).

## Key design constraints (from frame)

Full table in the frame artifact. Load-bearing ones:

| # | type | constraint |
|---|------|------------|
| C3 | hard | Fresh `claude -p` per task boundary. Rejects in-session stop-hook loops (Ralph plugin OOM evidence, E1). |
| C4 | hard | Intra-task looping — one task may span N fresh `claude -p` invocations. |
| C5 | hard | Terminal check: default `terminal_artifact`, escape hatch shell expression. |
| C6 | hard | `max_iterations` per task (default 10); over-budget = terminal failure. |
| C7 | hard | DAG dependency model; zero-config default = depends on previous task. |
| C9 | hard | Rate-limit handling reuses `is_fast_failure()` (`skills/use-envoy/scripts/_common.sh:81-84`, E2). |
| C10 | hard | Restricted permission profile via `claude -p` flags (E2 via `claude --help`). |
| C11 | hard | Trip-wires write `WOKE-ME-UP.md` and halt queue. |
| C12 | hard | Enqueue-time lint (static, not dry-run). |
| C17/C18 | hard | Streaming observability as first-class primitive; JSONL per iteration. |

## Success criteria (EARS)

1. **SC1** — queue runs on valid queue file, honors DAG order.
2. **SC2** — terminal check pass OR `max_iterations` stops intra-task loop.
3. **SC3** — failure blocks transitive dependents; independent branches continue.
4. **SC4** — trip-wire writes `WOKE-ME-UP.md` and halts.
5. **SC5** — rate-limit signal → exponential backoff → retry same provider.
6. **SC6** — enqueue lint refuses invalid queue, state unchanged.
7. **SC7** — on completion, `queue-report.md` with per-task status + artifact links.
8. **SC8** — mid-run queue state observable from filesystem.
9. **SC9** — idempotent resume skips completed tasks.
10. **SC10** — real-time stream + captured JSONL per iteration.

## Open questions (design phase)

1. Trigger mechanism (manual kick command v1; cron/systemd v2).
2. Queue-runner implementation language (POSIX shell matches `use-envoy` precedent; claude-code-sdk Node alternative).
3. Relationship to existing `loop` skill (likely new `run-queue` skill; `loop` stays in-session).
4. Hook-vs-flag split for trip-wire defense-in-depth (A2 disputed).
5. Backoff policy exact shape (exponential 2/4/8/16/32 min capped at 2h proposed).
6. JSONL retention policy (prune succeeded-task transcripts after N days?).
7. Morning-report format (markdown default; HTML visualizer v2).

## Rejected

- **Stop-hook-driven intra-session looping** — reproduces Anthropic Ralph plugin failure mode (E1 aihero.dev critique, gh issues #125 #216 #394).
- **Pre-flight dry-run execution** — doubles cost, low signal given model non-determinism.
- **Cross-project global queue** — conflicts with Spine's project-local session model.
- **Waking the user for ordinary task boundaries** — only trip-wires wake.
- **Natural-language-grep terminal detection** — fragile (column variance in session-log); superseded by structured `build-status.json`.

## References

- `frame-artifact.md` — full frame with all 21 constraints, 10 success criteria, blast radius
- `.scratch/autonomous-overnight-task-queue-1034/discuss-artifact.md` — propose-and-refine log
- `.scratch/autonomous-overnight-task-queue-1034/explore-navigator-ralph.md` — Ralph external research
- `skills/use-envoy/scripts/_common.sh:81-84` — `is_fast_failure()` pattern reuse
- `skills/do-build/references/build-finalize.md` — finalize phase to extend with `build-status.json`
- Ralph pattern: https://ghuntley.com/ralph/
- Streaming pattern: https://www.aihero.dev/heres-how-to-stream-claude-code-with-afk-ralph
- Plugin failure mode: https://www.aihero.dev/why-the-anthropic-ralph-plugin-sucks

## Progress

See `progress.md` (created by `/do-design` when delivery slices are defined).
