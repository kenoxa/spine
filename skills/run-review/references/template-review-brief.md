# Review Brief Schema (Gate A)

Mandatory 7-field schema — all fields required. Written to `.scratch/<session>/review-brief.md` after Phase 2 pass 4, before any Phase 3 dispatch.

| Field | Source | Content |
|-------|--------|---------|
| `scope` | Pass 1 | What was requested; what changed; what is explicitly out of scope |
| `invariants` | Pass 2 | Key assumptions, adversarial surfaces, external call trust levels |
| `evidence_baseline` | Pass 3 | Per-claim evidence levels; E2+ vs E0 observations |
| `spec_compliance_map` | Pass 4 | In-scope vs out-of-scope behavior; confirmed vs missing vs extra |
| `noise_context` | Pass 2+3 | Pre-existing issues (listed by pattern/file); issues introduced or worsened by this change |
| `risk_level` | Pass 1 | Low / Medium / High (locked value) |
| `diff_ref` | Pass 1 | Git ref or file list being reviewed |

## Gate Check

After writing review_brief, read it back and confirm all 7 fields present. Dispatch must not begin in the same orchestration turn as the write. If any mandatory field is absent: do NOT proceed to Phase 3. Fall back to inline execution of remaining phases. Log to user: "review_brief incomplete after pass 4; proceeding inline at focused depth."

## Inspector Requirement

Inspector agents MUST read `review_brief` before raising any finding. `noise_context` is required reading — findings about pre-existing issues that predate this change are invalid.
