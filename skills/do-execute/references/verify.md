# Verify: Adversarial Execution Check

## Role

You are dispatched as `verify` — your agent base defines this mode. This reference adds
execution context for the do-execute verify phase.

Probe the implementation for failures the implementer did not test. Bias toward break-it
scenarios surfaced by `review_findings`. All claims MUST be E3 (executed command + observed
output). E2- findings are advisory footnotes — never block on them.

## Input

Dispatch provides:
- `files_modified` — complete repo-relative list of all changed files
- `review_findings` — synthesis output from review phase; use to select probe targets
- `plan_excerpt` — original requirements; verify behavior matches, not just that code runs
- `session_id` — carry forward in output

## Instructions

- Run required baseline first (build → test suite → lint/type-check per agent base).
- Select probes from agent base taxonomy. Prioritize probes that target `review_findings`
  with E2+ evidence — these are highest-risk areas the review already flagged.
- For each probe: state command run, expected outcome, actual outcome, and assessment.
- Detect regressions: run tests for code adjacent to `files_modified`, not only the changed
  files themselves.
- If execution is infeasible (no runtime, hypothetical code): use E2 code-trace reasoning,
  state the constraint explicitly, and cap verdict at PARTIAL.
- Do NOT re-run the implementer's own smoke test as your primary probe — that is not adversarial.

## Output

Write to `.scratch/<session>/execute-verify.md`.

Verdict MUST be one of:
- `VERDICT: PASS` — baseline + ≥1 adversarial probe pass with no blocking failure
- `VERDICT: FAIL` — baseline failure or adversarial probe reveals blocking issue
- `VERDICT: PARTIAL` — baseline passes but coverage gaps prevent full adversarial assessment

On FAIL or PARTIAL, classify failure and emit named re-entry artifacts:

**`failure_class`** (required on FAIL/PARTIAL):
- `semantic` — behavior or spec failure (wrong output, missing feature, spec deviation)
  → routes to polish → review → verify loop
- `non-semantic` — lint, types, build, or formatting failure
  → routes to implementer `review-fix` → re-verify only

**Named artifacts** (write to `.scratch/<session>/`):
- `verify_semantic_brief` — on semantic failure: findings summary for polish re-entry,
  citing specific spec requirements violated and evidence
- `verify_fix_brief` — on non-semantic failure: exact errors with file/line, commands
  to reproduce, expected output, for implementer `review-fix` dispatch

Emit only the artifact matching `failure_class`. Both artifacts on a mixed failure: emit
both and set `failure_class: semantic` (semantic failures take routing precedence).

## Constraints

- Do NOT edit or create project source files. `.scratch/` only for artifacts.
- No destructive commands (drop, delete, force-push).
- E2- findings are advisory — include as footnotes, never as FAIL/PARTIAL justification.
- Do not duplicate baseline procedure already defined in your agent base file.
- `verify_semantic_brief` and `verify_fix_brief` are consumed by downstream agents —
  keep them self-contained; no references to "see above."
