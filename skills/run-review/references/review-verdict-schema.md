# review-verdict.json — Schema

Machine-readable verdict emitted by `/run-review` Phase 4. `review-findings.md` is authoritative for humans; this sidecar is authoritative for machines.

> **Note**: `review-findings.md` frontmatter field names are inconsistent across files. Machine consumers MUST NOT parse frontmatter for the verdict — use this sidecar.

## Path

`.scratch/<session>/review-verdict.json` — `/run-review` session id, generated at Phase 1 Scope.

## Write Contract

Write to `.scratch/<session>/review-verdict.json.tmp`, then `mv` to final path (atomic). Emit on every terminal outcome. Missing artifact = ITERATE-equivalent fail-secure. Mode 0644. Mirrors `build-status-schema.md` atomicity contract.

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
| `schema_version` | string | `"1"`. Bump on breaking change. Consumers MUST refuse unknown versions. |
| `verdict` | enum | `"ACCEPT"` \| `"ITERATE"` \| `"REJECT"` |
| `severity_counts` | object | `blocking`, `should_fix`, `follow_up` counts (int each). |
| `findings_path` | string | Path to `review-findings.md`; `""` when not written (focused depth). |
| `session_id` | string | `/run-review` session id matching `<session>` in `findings_path`. |
| `depth` | enum | `"focused"` \| `"standard"` \| `"deep"`. |
| `risk_level` | enum | `"low"` \| `"medium"` \| `"high"`. |

## Verdict Values

| Value | Criterion | Consumer action |
|-------|-----------|-------------------|
| `"ACCEPT"` | Zero `blocking` findings | Treat review gate as passed. |
| `"ITERATE"` | ≥1 `blocking` finding, considered fixable | Treat review gate as failed but fixable. |
| `"REJECT"` | Irrecoverable or scope mismatch (e.g., wrong target branch, wrong artifact entirely) | Treat review gate as failed and do not retry automatically. |

Gate: any `blocking` finding stops merge. `should_fix`/`follow_up` do not block (morning triage).

## Depth Behavior

`focused`: sidecar always written; `review-findings.md` may be absent (`findings_path = ""`). `standard`/`deep`: `review-findings.md` always written; `findings_path` non-empty.

## Error Cases

| Condition | Consumer action |
|-----------|----------------|
| Missing artifact | ITERATE-equivalent fail-secure; flag for human triage. |
| Malformed JSON | ITERATE-equivalent fail-secure; log parse error. |
| `schema_version` > `"1"` | MUST refuse; treat as ITERATE-equivalent fail-secure. |
| `findings_path` unresolvable | Proceed with `verdict` field; note the missing findings artifact. |

## Compatibility

- New optional fields: additive; no version bump. Consumers MUST ignore unknown fields.
- New `verdict` values: additive. Consumers SHOULD treat unknown `verdict` as `"ITERATE"` (fail-secure).
- Field rename, type change, or required→optional: bump `schema_version` to `"2"`.

## Cross-References

- **Emission**: [`review-output.md`](review-output.md) — Phase 4 Output Assembly section.
- **Sibling pattern**: [`build-status-schema.md`](build-status-schema.md) — `build-status.json` follows the same atomicity and version contract.
- **Atomicity pattern**: [`docs/machine-verifiable-terminal-contracts.md`](../../../docs/machine-verifiable-terminal-contracts.md).
