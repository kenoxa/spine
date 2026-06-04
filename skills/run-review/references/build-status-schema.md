# build-status.json — Schema

Machine-readable terminal signal emitted by the build finalize phase. Consumed by future wrappers, session resumers, and optional HTML visualizers. The natural-language completion declaration remains authoritative for humans.

## Path

`.scratch/<session>/build-status.json` — session ID carried forward across workflow phases, or generated at build entry for standalone builds.

## Write Contract

Atomic: write `.tmp`, then `mv` to final path. Mid-build readers must never observe truncated JSON. Overwrite on every terminal outcome within a session — iteration N overwrites iteration N-1's snapshot. Mode 0644.

## Schema v1

```json
{
  "schema_version": "1",
  "status": "complete",
  "exit_reason": "review-accept",
  "session_id": "autonomous-overnight-task-queue-1034",
  "timestamp_utc": "2026-04-24T12:30:00Z",
  "base_rev": "1bdef4a2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8",
  "head_rev": "9abcdef0123456789abcdef0123456789abcdef0",
  "dirty_start": false,
  "dirty_end": false,
  "iteration": 1,
  "commits": [
    { "sha": "9abcdef0", "subject": "feat(session): persist build state" }
  ],
  "files_modified": ["skills/use-session/SKILL.md"],
  "iteration_cost_usd": null
}
```

## Fields

| Field | Type | Semantics |
|-------|------|-----------|
| `schema_version` | string | `"1"`. Bump on breaking change. |
| `status` | enum | `complete` \| `partial` \| `blocked` \| `in_progress`. |
| `exit_reason` | string | Short machine code — see below. Not user-facing. |
| `session_id` | string | Session ID for this build. |
| `timestamp_utc` | RFC 3339 | UTC at emission. `date -u +%Y-%m-%dT%H:%M:%SZ`. |
| `base_rev` | full SHA | `git rev-parse HEAD` at build entry. |
| `head_rev` | full SHA | `git rev-parse HEAD` at finalize. Equals `base_rev` if no commits. |
| `dirty_start` | bool | `git status --porcelain` non-empty at entry. |
| `dirty_end` | bool | `git status --porcelain` non-empty at finalize. A `true` in an autonomous wrapper is a trip-wire. |
| `iteration` | int | 1-indexed iteration in the intra-task loop. `1` for single-shot. |
| `commits` | `[{sha,subject}]` | Commits created in this iteration. `[]` if none. |
| `files_modified` | `[string]` | Repo-relative paths touched this iteration. Sorted, deduplicated. |
| `iteration_cost_usd` | number \| null | API cost, when `--max-budget-usd` was set and cost is observable. |
| `review` | object \| absent | Optional. Records the review-closeout decision — see below. |

## Review block

Optional. Records how the [review-closeout gate](build-finalize.md) was satisfied. Additive-optional — its absence means "not recorded", never "review skipped".

```json
"review": {
  "mode": "branch",
  "depth": "standard",
  "verdict": "ACCEPT",
  "verdict_path": ".scratch/<session>/review-verdict.json",
  "trivial_exception": false,
  "reason": null
}
```

| Subfield | Type | Semantics |
|----------|------|-----------|
| `mode` | enum | Review target: `local` (dirty local) \| `branch` (branch vs base) \| `commit` (single commit). |
| `depth` | enum | `focused` \| `standard` \| `deep`. |
| `verdict` | enum | Mirror of `review-verdict.json` (`ACCEPT`/`ITERATE`/`REJECT`) — the verdict sidecar stays authoritative. |
| `verdict_path` | string | Path to the authoritative `review-verdict.json`. |
| `trivial_exception` | bool | `true` when the lightweight (`focused`) path was taken for trivial/docs/no-code work. |
| `reason` | string \| null | Required string when `trivial_exception` is `true`: the trivial classification justification. |

## Status → consumer action

| Value | Meaning | Consumer action |
|-------|---------|-------------------|
| `complete` | Review ACCEPT, gates met, question-answered `yes` | Mark task done; proceed to dependents. |
| `partial` | ACCEPT, question-answered `partially` or `no` | Done, flagged for human review. |
| `blocked` | Iterate cap, gate fail, interrupt, or budget exceeded | Failed; transitive dependents → `blocked`. |
| `in_progress` | Transient sentinel inside a running iteration | Never terminal. Observing it at per-task check = premature read or bug. |

## Exit reasons

Short codes. Match on prefix; consumers fallback to `status` on unknown values.

| Code | Cause | Status |
|------|-------|--------|
| `review-accept` | Review gate returned ACCEPT | `complete` |
| `review-iterate-cap` | Review loop hit 5-iteration cap | `blocked` |
| `question-answered-partially` | Intent partially met | `partial` |
| `question-answered-no` | Intent not met | `partial` |
| `gate-failed-builds` | `Builds/parses` gate failed | `blocked` |
| `polish-iterate-cap` | Polish loop hit 3-iteration cap | `partial` |
| `supervisor-interrupt` | SIGTERM/SIGINT from an external wrapper | `blocked` |
| `budget-exceeded` | `--max-budget-usd` tripped | `blocked` |

## Compatibility

- New optional fields: additive; no version bump. Consumers MUST ignore unknown fields.
- New `status` / `exit_reason` values: additive. Consumers SHOULD fallback (unknown `status` → `blocked`; unknown `exit_reason` → opaque).
- Field rename, type change, or required→optional: bump to `"2"`. Consumers MUST refuse `schema_version` higher than they understand.
