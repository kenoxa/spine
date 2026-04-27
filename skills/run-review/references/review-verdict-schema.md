# review-verdict.json — Schema

Machine-readable verdict emitted by `/run-review` Phase 4. Consumed by `skills/run-queue/` supervisor (review-gate check per task). The human-readable `review-findings.md` remains authoritative for humans; the JSON sidecar is authoritative for machine consumers.

> **Note on `review-findings.md` frontmatter**: frontmatter fields on `review-findings.md` are a convention family, not a schema — 5-file audit found 3 distinct verdict field names and 2 files with no frontmatter at all. Machine consumers MUST NOT parse frontmatter for the verdict; use this sidecar instead.

## Path

`.scratch/<session>/review-verdict.json` — `/run-review` session id, generated at Phase 1 Scope.

## Write Contract

Atomic: write to `.scratch/<session>/review-verdict.json.tmp`, then `mv` to final path. Mid-run readers must never observe truncated JSON. Emit on every terminal outcome (ACCEPT, ITERATE, REJECT). A missing artifact is a bug, not a silent skip — treat absence as ITERATE-equivalent fail-secure. Mode 0644.

Mirrors the atomicity contract in `docs/machine-verifiable-terminal-contracts.md` and `build-status-schema.md`.

## Schema v1

```json
{
  "schema_version": "1",
  "verdict": "ACCEPT",
  "severity_counts": {
    "blocking": 0,
    "should_fix": 2,
    "follow_up": 1
  },
  "findings_path": ".scratch/<session>/review-findings.md",
  "session_id": "<run-review session id>",
  "depth": "standard",
  "risk_level": "medium"
}
```

## Fields

| Field | Type | Semantics |
|-------|------|-----------|
| `schema_version` | string | `"1"`. Bump on breaking change. Consumers MUST refuse versions higher than they understand. |
| `verdict` | enum | `"ACCEPT"` \| `"ITERATE"` \| `"REJECT"` — see verdict values below. |
| `severity_counts` | object | Counts of findings per severity bucket: `blocking` (int), `should_fix` (int), `follow_up` (int). |
| `findings_path` | string | Repo-relative or `.scratch`-relative path to `review-findings.md`. Empty string `""` when no artifact was written (may occur at `focused` depth — see below). |
| `session_id` | string | `/run-review` session id matching `<session>` in `findings_path`. |
| `depth` | enum | `"focused"` \| `"standard"` \| `"deep"`. Matches Phase 1 depth classification. |
| `risk_level` | enum | `"low"` \| `"medium"` \| `"high"`. Derived from risk scaling in Shared Rules. |

## Verdict Values

| Value | Criterion | Supervisor action |
|-------|-----------|-------------------|
| `"ACCEPT"` | Zero `blocking` findings | Proceed to merge stage. |
| `"ITERATE"` | ≥1 `blocking` finding, considered fixable | Block merge; retain branch; mark task `blocked-by-review`. |
| `"REJECT"` | Irrecoverable or scope mismatch (e.g., wrong target branch, wrong artifact entirely) | Block merge; retain branch; mark task `blocked-by-review`. Do not retry. |

Verdict gate criterion: any `blocking` finding stops merge for that task. `should_fix` and `follow_up` do not block merge (user reviews at morning triage). Per-task threshold override deferred to a future slice.

## Worked Examples

### ACCEPT — zero blocking findings

```json
{
  "schema_version": "1",
  "verdict": "ACCEPT",
  "severity_counts": { "blocking": 0, "should_fix": 2, "follow_up": 1 },
  "findings_path": ".scratch/my-feature-abc1/review-findings.md",
  "session_id": "my-feature-abc1",
  "depth": "standard",
  "risk_level": "medium"
}
```

### ITERATE — one or more blocking findings, fixable

```json
{
  "schema_version": "1",
  "verdict": "ITERATE",
  "severity_counts": { "blocking": 1, "should_fix": 0, "follow_up": 3 },
  "findings_path": ".scratch/my-feature-abc1/review-findings.md",
  "session_id": "my-feature-abc1",
  "depth": "deep",
  "risk_level": "high"
}
```

### REJECT — scope mismatch or irrecoverable

```json
{
  "schema_version": "1",
  "verdict": "REJECT",
  "severity_counts": { "blocking": 2, "should_fix": 0, "follow_up": 0 },
  "findings_path": ".scratch/my-feature-abc1/review-findings.md",
  "session_id": "my-feature-abc1",
  "depth": "standard",
  "risk_level": "high"
}
```

## Depth Behavior

At `focused` depth: the sidecar is still written (mandatory). `review-findings.md` may not be produced; in that case `findings_path` is `""`. `session_id` may be ephemeral but path resolution still works — the `.tmp`+`mv` write contract applies regardless of depth.

At `standard`/`deep` depth: `review-findings.md` is always written; `findings_path` is non-empty.

## Error Cases

**Missing artifact** — consumer treats a missing `review-verdict.json` as ITERATE-equivalent fail-secure (i.e., assume at least one blocking finding; block the merge stage and flag for morning triage).

**Malformed JSON** — consumer treats unreadable or non-object JSON as ITERATE-equivalent fail-secure; log the parse error for morning triage visibility.

**`schema_version` mismatch** — consumer MUST refuse any `schema_version` value higher than `"1"`. On refusal, treat as ITERATE-equivalent fail-secure.

**`findings_path` unresolvable** — consumer proceeds with verdict from `verdict` field; notes path resolution failure in queue-report. Does not override the verdict.

## Compatibility

- New optional fields: additive; no version bump. Consumers MUST ignore unknown fields.
- New `verdict` values: additive. Consumers SHOULD treat unknown `verdict` as `"ITERATE"` (fail-secure).
- Field rename, type change, or required→optional: bump `schema_version` to `"2"`.

## Cross-References

- **Emission**: [`review-output.md`](review-output.md) — Phase 4 Output Assembly section.
- **Sibling pattern**: [`skills/do-build/references/build-status-schema.md`](../../do-build/references/build-status-schema.md) — `build-status.json` follows the same atomicity and version contract.
- **Atomicity pattern**: [`docs/machine-verifiable-terminal-contracts.md`](../../../docs/machine-verifiable-terminal-contracts.md).
- **Verdict gate**: `skills/run-queue/scripts/run.sh` — supervisor reads `verdict` field; any `blocking` > 0 triggers `blocked-by-review`.
