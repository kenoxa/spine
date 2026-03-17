# Synthesize + Re-sort + Output (Phases 4-6)

## Role

Synthesis, conflict resolution, re-sort, and output assembly for standalone review. Merge inspector findings, resolve conflicts, sort by severity, produce user-facing output.

## Input

- Non-empty inspector output paths from Phase 3 (`.scratch/<session>/review-{role}.md`)
- Envoy output (`.scratch/<session>/review-inspect-envoy.md`) if it exists and is not a skip advisory
- Review brief at `.scratch/<session>/review-brief.md`

## Instructions

### Phase 4: Synthesize (mandatory dispatch)

Dispatch `@synthesizer` with all non-empty inspector output paths. Include envoy output if it exists and is not a skip advisory. Output: `.scratch/<session>/review-synthesis.md`.

Synthesizer: use-envoy `standard` variant. Tail: "After merging findings, include a correctness assessment (`correct` or `issues found`) with categorical confidence (high/med/low) and 1-2 sentence justification. When envoy assessment exists, note agreement or disagreement."

**Gate C:** If synthesis output empty or missing: read individual agent output files directly; merge manually by severity bucket; apply deduplication; apply severity re-sort. Log to user: "Synthesis output absent — falling back to individual agent outputs."

### [CONFLICT] Resolution

Main thread, after Phase 4. Orchestrator has full pass 1-4 context. Apply:

1. **Higher-evidence claim wins** when evidence levels differ (E2 over E1 is deterministic). If evidence levels in a [CONFLICT] tag are ambiguous or summarized, read source inspector files (`.scratch/<session>/review-{role}.md`) to retrieve original levels.
2. **Equal evidence** — higher severity bucket wins. Severity demotion requires explicit written justification.
3. **Irresolvable** — retain BOTH findings labeled "(unresolved — user decision required)" at top of their severity bucket.

Never silently drop a [CONFLICT] entry.

### Phase 5: Re-sort (main thread)

Re-sort all findings after [CONFLICT] resolution, before user presentation:

1. `blocking` (within bucket: E3 > E2 > E1 > E0)
2. `should_fix` (within bucket: E3 > E2 > E1 > E0)
3. `follow_up` (within bucket: E3 > E2 > E1 > E0)

**Primary sort is ALWAYS severity bucket.** Evidence level is secondary within bucket only. A `follow_up` at E3 is presented after a `blocking` at E2.

### Phase 6: Output

Main thread (all depths). Return findings using severity buckets.

Per finding: severity bucket, target file(s), remediation path, evidence level.

Directional findings: numbered issue ID with options (A/B/C), recommendation first, include "do nothing" when reasonable. Tradeoff rationale per option.

At `standard`/`deep` depth: intermediate artifacts in `.scratch/<session>/` (review-brief.md, review-{role}.md, review-synthesis.md). User-facing findings always assembled by main thread.

#### Visual diff report

After findings, dispatch `@visualizer` subagent: diff review for <git-ref>. Findings: <key blocking/should_fix>. Output: `.scratch/<session>/diff-review.html` (standalone: `.scratch/<slug>-<hash>.html`).

Non-blocking — if dispatch fails, log and continue; review findings are the primary deliverable.

Write `.scratch/<session>/review-findings.md` as severity-bucketed table: severity | file | finding | evidence level | status. Non-blocking; write after user output.

### Deferral Policy

- Any finding deferrable with explicit user approval. Deferred findings remain visible — never silently removed.
- Deferral is an exception path, not the default.

### Completion Declaration

When all resolved or deferred: `Review complete. No unresolved findings.` or `Review complete. Unresolved findings remain` + list.

## Output

- `.scratch/<session>/review-findings.md` — severity-bucketed findings table
- `.scratch/<session>/diff-review.html` — visual diff report (non-blocking)
- User-facing review summary with all findings

## Constraints

- Re-sorting by evidence level instead of severity bucket before user presentation is an error.
- Resolving [CONFLICT] by silently picking one side is an error — present both or apply tiebreaker rules explicitly.
- Read-only — no file writes except review artifacts, no test execution.
