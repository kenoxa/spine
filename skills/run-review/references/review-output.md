# Review: Output

Mainthread-loaded reference for Phases 5-6. Conflict resolution, severity re-sort, output assembly.

## Input

- Synthesis output: `.scratch/<session>/review-synthesis.md`
- Review brief: `.scratch/<session>/review-brief.md`
- Individual agent outputs (fallback): `.scratch/<session>/review-{role}.md`

## Instructions

### [CONFLICT] Resolution

1. **Higher-evidence wins** — E2 over E1 is deterministic. Ambiguous evidence in `[CONFLICT]` tag → read source inspector files to retrieve original levels.
2. **Equal evidence** — higher severity bucket wins. Demotion requires explicit written justification.
3. **Irresolvable** — retain BOTH labeled "(unresolved — user decision required)" at top of severity bucket. Never silently drop.

### Phase 5: Re-sort

Primary sort ALWAYS severity bucket. Evidence level secondary within bucket only.

1. `blocking` (within: E3 > E2 > E1 > E0)
2. `should_fix` (within: E3 > E2 > E1 > E0)
3. `follow_up` (within: E3 > E2 > E1 > E0)

A `follow_up` at E3 comes after a `blocking` at E2. Re-sorting by evidence instead of severity is an error.

### Phase 6: Output

Per finding: severity bucket, target file(s), remediation path, evidence level.

Directional findings: numbered ID with options A/B/C, recommendation first, include "do nothing" when reasonable.

At `standard`/`deep`: intermediate artifacts in `.scratch/<session>/`. User-facing findings always assembled by main thread.

**Visual diff report**: dispatch `@visualizer` — diff review with key findings. Output `.scratch/<session>/diff-review.html`. Non-blocking.

**Findings table**: write `.scratch/<session>/review-findings.md` as severity-bucketed table. Non-blocking, after user output.

### Deferral

Any finding deferrable with explicit user approval. Deferred findings remain visible — never silently removed.

### Completion

- All resolved: "Review complete. No unresolved findings."
- Remaining: "Review complete. Unresolved findings remain" + list.

## Constraints

- Re-sorting by evidence instead of severity is an error.
- Silent [CONFLICT] resolution is an error — present both or apply tiebreaker rules explicitly.
- Read-only except review artifacts in `.scratch/<session>/`.
