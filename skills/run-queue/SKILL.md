---
name: run-queue
description: >
  Overnight autonomous task queue. Run a pre-staged DAG of handoff tasks in
  fresh `claude -p` processes, one task per branch, with restricted permissions
  and a morning report. Use when: "queue", "overnight run", "batch this", "run
  these handoffs", "autonomous execution", "afk build". Do NOT use for single
  in-session tasks — use do-build instead; and do NOT use for exploration —
  use do-frame or do-design.
argument-hint: "[queue-dir | queue.yaml path]"
---

## Two Surfaces

| Surface | Role | When invoked |
|---------|------|--------------|
| `skills/run-queue/` (this skill) | Human-facing workflow | In a daytime Claude session: assemble the queue, confirm, spawn, monitor, review. |
| `skills/run-queue/scripts/run.sh` | Autonomous POSIX sh executor | Spawned under `tmux`/`nohup` by the Kick phase. Reads queue, runs tasks in fresh `claude -p` children, writes morning report. |

The script NEVER invokes itself recursively via queue spawning — `SPINE_QUEUE=1` recursion guard set at supervisor entry blocks re-entry.

## Phases

The skill walks four phases in order. Each phase has a dedicated reference.

| Phase | What happens | Reference |
|-------|-------------|-----------|
| **Prepare** | Scan for handoff candidates, audit resumption contracts, propose a DAG, materialize queue only after user confirmation. | [references/prepare.md](references/prepare.md) |
| **Kick** | Lint the queue, show queue preview (DAG + tasks + branches + tmux command), confirm with user, spawn the supervisor under tmux. | [references/kick.md](references/kick.md) |
| **Monitor** | Stateless check-in: read `queue-state.json` + `queue-log.md`, surface trip-wire if present, report per-task progress. | [references/monitor.md](references/monitor.md) |
| **Review** | Morning walk-through of `queue-report.md`; propose merge/discard/re-queue per task; merge only after per-task confirmation. | [references/review.md](references/review.md) |

## Queue Shape (v1)

See [queue-schema.md](references/queue-schema.md) for the full `queue.yaml` + handoff frontmatter schema, lint rules, exit reasons, and iteration artifacts.

## Prerequisites

Requires GNU `coreutils` — provides `grealpath` / `gstdbuf` on macOS via Homebrew (`brew install coreutils`); system `realpath` / `stdbuf` on Linux already cover this. Supervisor preflight refuses to start if absent.

## Entry Point

```sh
SPINE_QUEUE=1 sh skills/run-queue/scripts/run.sh <queue-dir>
```

Reads `<queue-dir>/queue.yaml`; validates via `queue-lint.sh`; resolves topological order via `tsort`; spawns one fresh `claude -p` per task on a dedicated `queue/<run_id>/<task_id>` local branch; merges parent branches for DAG-child tasks; writes `queue-report.md` at completion.

Daytime use goes through the Kick phase, which runs lint + preview + confirm before spawning — rather than invoking `run.sh` by hand.

## Trust Boundary

Inherits whatever permission posture your `~/.claude/settings.json` already provides; the supervisor does **not** pass `--settings` and does **not** build a parallel permission stack. A narrow queue-specific overlay adds only what makes sense for overnight autonomous runs (not for interactive sessions):

- Deny **all** `git push` (interactive sessions routinely push; overnight runs should never publish).
- Deny writes outside the queue's repo root.
- Deny `git -C /path` sidesteps.
- On any deny → write `<queue-dir>/WOKE-ME-UP.md` and halt the queue.

Mechanism: the skill bundles its own hook at `skills/run-queue/scripts/guard-queue-shell.sh` and a settings-overlay template at `skills/run-queue/settings-overlay.tmpl.json`. The supervisor renders the overlay with absolute paths into `<queue-dir>/.run-queue-settings.json` and passes `claude -p --settings <that-file>` at each child spawn — additive on top of your global `~/.claude/settings.json`, not a replacement. The hook fires only for queue runs (because only they pass the overlay) AND env-gates on `SPINE_QUEUE=1` as defense-in-depth. Optional `<queue-dir>/profile.json` adds per-run extra deny patterns or out-of-repo allowances.

Fail-secure: missing or non-executable bundled assets → supervisor refuses to start. Full story: [permission-profile.md](references/permission-profile.md).

## Ralph Pattern — Known Pitfalls Rejected

The Anthropic Ralph plugin OOMs at ~8 h due to stop-hook context accumulation. `run-queue` rejects stop-hook-driven looping entirely — every task boundary is a fresh process. Intra-task looping (Slice C) also uses fresh `claude -p` invocations with a resumption prompt, not in-session loops.

- **Intra-task loop + rate-limit backoff (Slice C):** the supervisor re-invokes `claude -p` per task until `build-status.json.status` is terminal (`complete` or `blocked`) or `max_iterations` (default 10) is reached; on rate-limit signals the supervisor sleeps exponentially (120 s → 2 h cap) and retries the same iteration.

## References

- [prepare.md](references/prepare.md) — Prepare phase: discovery, handoff-contract audit, DAG proposal, materialization gate
- [kick.md](references/kick.md) — Kick phase: lint, queue preview, confirmation gate, spawn mechanism
- [monitor.md](references/monitor.md) — Monitor phase: stateless file-reading, trip-wire, rule-of-thumb
- [review.md](references/review.md) — Review phase: per-status action table, merge gates, iteration artifacts
- [queue-schema.md](references/queue-schema.md) — `queue.yaml` + handoff frontmatter schema
- [permission-profile.md](references/permission-profile.md) — two-layer trust model + `profile.json` format
- `scripts/run.sh` — supervisor entry point
- `scripts/queue-lint.sh` — enqueue-time static validation
- Design: `docs/specs/2617-overnight-task-queue/spec.md`
