---
updated: 2026-04-24
paths:
  - skills/do-build/references/build-status-schema.md
  - skills/do-build/references/build-finalize.md
  - skills/run-queue/scripts/run.sh
---

# Machine-Verifiable Terminal Contracts

Skills that complete autonomously (overnight queue, long-running builds) need
machine-readable terminal signals. Natural-language "Build complete." is
insufficient when the consumer is another process, not a human.

## Pattern

Emit a small JSON artifact at a well-known path on every terminal outcome.
Consumers read it to determine success / failure / iteration state. Atomicity
contract: write `.tmp`, then `mv` to final path — readers must never observe
truncated JSON.

The natural-language completion declaration remains authoritative for humans.
The JSON artifact is additive — existing stdout / session-log consumers keep
working unchanged.

## Schema skeleton

Exemplar: `build-status.json` emitted by `do-build` finalize. Key fields:

| Field | Purpose |
|-------|---------|
| `schema_version` | Bump on breaking change; consumers refuse higher versions |
| `status` | enum — `complete` \| `partial` \| `blocked` \| `in_progress` |
| `exit_reason` | Short machine code (e.g. `review-accept`, `review-iterate-cap`, `budget-exceeded`) |
| `session_id` | Carries from do-frame → do-design → do-build |
| `timestamp_utc` | RFC 3339 |
| `base_rev` / `head_rev` | Full SHAs at entry / finalize |
| `iteration` | 1-indexed; `1` for single-shot |
| `commits` | `[{sha, subject}]` created this iteration |
| `files_modified` | Repo-relative, sorted, deduplicated |

New optional fields are additive; consumers MUST ignore unknown fields.

## Status → consumer action

| `status` | Meaning | Consumer action |
|----------|---------|-----------------|
| `complete` | ACCEPT, gates met, question-answered yes | Proceed to dependents |
| `partial` | ACCEPT, question-answered partially / no | Done, flagged for review |
| `blocked` | Iterate cap, gate fail, interrupt, budget | Failed; transitive dependents blocked |
| `in_progress` | Transient sentinel inside a running iteration | Never terminal; observing at check = premature read or bug |

## When to use

- Skill completes autonomously (no human watching final output).
- A downstream process (queue supervisor, CI runner, wrapper) needs to poll
  completion state.
- Iteration state matters (intra-task loop, per-iteration snapshots).

## When NOT to use

- Interactive skills where a human interprets output. Natural-language
  declaration sufficient.
- Skills without a clean "terminal" moment (advisory, continuous monitors).

## Reference implementations

- **`do-build` finalize** (`skills/do-build/references/build-finalize.md:70-84`)
  writes `.scratch/<session>/build-status.json` atomically on every terminal
  outcome (ACCEPT, cap-reached, partial, question-answered=no).
  [E2: finalize ref; E3: first real-world emission at
  `.scratch/autonomous-overnight-task-queue-1034/build-status.json`, 2026-04-24]

- **`run-queue` supervisor** (`skills/run-queue/scripts/run.sh:362-396`,
  `_classify_terminal_status`) treats `terminal_artifact: build-status.json` as
  the default task completion signal; reads `.status`, propagates per the
  action table above. Integration-test verified with 3-task linear queue
  (`.scratch/queue-demo-legit/queue-report.md`).
  [E2: run.sh:362-396; E3: queue-demo-legit/queue-report.md]

## Anti-patterns

- **Conditional emission.** Always emit — a missing artifact is a bug, not a
  silent skip. Downstream consumers treat absence as `in_progress` and may
  stall. Guard: `do-build` finalize contract `build-finalize.md:84` states
  "Always emit `build-status.json`."
- **Non-atomic write.** `> final` leaves a window where a reader sees partial
  JSON. Always `.tmp + mv`.
- **Schema drift without version bump.** Rename, type change, or
  required→optional → bump `schema_version`. Additive fields are safe.
