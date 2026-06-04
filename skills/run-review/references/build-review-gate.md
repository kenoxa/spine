# Build: Review Gate

## Role

Mainthread gate logic. Read run-review's output and determine ITERATE or ACCEPT verdict for the build correctness loop.

## Input

Run-review produces a findings artifact with severity-bucketed findings:
- `blocking` — E2+ evidence, must fix
- `should_fix` — recommended, blocks unless user defers
- `follow_up` — tracked debt, does not block

## Running the review

- **Format first** when formatting can move line locations, so findings reference stable lines.
- **A long review is not a hang.** A dispatched reviewer/verifier on a large change can run for many minutes; advancing progress (heartbeats, streamed activity) is healthy. Do not abandon or re-dispatch a review that is still making progress — wait it out.

## Gate Logic

1. Read run-review's findings output from `.scratch/<session>/`.
2. Check for blocking findings (any finding with `[B]` prefix or `blocking` severity).
3. Check verifier VERDICT if present: FAIL or PARTIAL → treat as blocking.

| Condition | Verdict |
|-----------|---------|
| No blocking findings, verifier PASS or absent | **ACCEPT** |
| Any blocking finding or verifier FAIL/PARTIAL | **ITERATE** |

## On ITERATE

Extract blocking findings as `fix_context` for the downstream implementer fix dispatch:
- One line per finding: file, finding summary, evidence level
- Omit should_fix and follow_up (those are polish territory)

## Applying findings (fix loop)

Review output is advisory until verified against real code — never apply a finding blind.

1. **Verify before fixing.** Read the real code path and adjacent files for each accepted finding. When the finding depends on external behavior, read the dependency's docs, source, or types. A finding that does not reproduce against current code is rejected, not fixed.
2. **Scope the fix.** Prefer the smallest fix at the right ownership boundary. Reject broad rewrites and fixes that over-complicate the code; no refactor unless it clearly improves the bug class.
3. **Sweep the bug class.** When an accepted finding reveals a repeated pattern, inspect the current partition scope for sibling instances and fix them together — stop at touched surfaces, owner boundaries, and clear follow-up territory.
4. **Re-verify.** If a fix changes code, rerun the focused tests, then re-review per the per-slice loop until verdict ACCEPT or the user explicitly defers a `should_fix`/`follow_up`. Once clean, stop.
5. **Record rejections.** A rejected finding stays visible with a one-line rationale — never silently dropped. Add an inline code comment only when it states a real invariant or ownership decision a future reviewer needs.

## On ACCEPT

Proceed to polish phase. Log should_fix items as polish candidates.

## Budget-aware inline ACCEPT (conditional)

Re-invoking `/run-review` after fix-mode is the default. Inline mainthread
verification is acceptable when ALL conditions hold:

- Prior review round had 0 consensus `[B]` findings AND verifier was PASS
  or PARTIAL-by-design (NOT verifier FAIL).
- All fixes are prose-local within previously-reviewed files
  (no new files, no new attack surface, no structural changes).
- `git status` shows no scope creep beyond the partition_scope.
- Invariants and trust-boundary prose structurally preserved.
- User has explicit budget-sensitivity guidance on file
  (e.g., user memory or SPINE.md workflow note).

When applied, log the inline-ACCEPT decision in session-log.md with the
five conditions checked. Default to the standard re-dispatch protocol
when any condition is uncertain.

## Constraints

- Binary verdict: ITERATE or ACCEPT. No partial states.
- E2+ required for blocking regardless of source.
- Do not re-evaluate findings independently — trust run-review's evidence levels.
