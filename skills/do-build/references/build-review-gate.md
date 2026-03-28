# Build: Review Gate

## Role

Mainthread gate logic. Read run-review's output and determine ITERATE or ACCEPT verdict for do-build's correctness loop.

## Input

Run-review produces a findings artifact with severity-bucketed findings:
- `blocking` — E2+ evidence, must fix
- `should_fix` — recommended, blocks unless user defers
- `follow_up` — tracked debt, does not block

## Gate Logic

1. Read run-review's findings output from `.scratch/<session>/`.
2. Check for blocking findings (any finding with `[B]` prefix or `blocking` severity).
3. Check verifier VERDICT if present: FAIL or PARTIAL → treat as blocking.

| Condition | Verdict |
|-----------|---------|
| No blocking findings, verifier PASS or absent | **ACCEPT** |
| Any blocking finding or verifier FAIL/PARTIAL | **ITERATE** |

## On ITERATE

Extract blocking findings as `fix_context` for `/run-implement` fix mode:
- One line per finding: file, finding summary, evidence level
- Omit should_fix and follow_up (those are polish territory)

## On ACCEPT

Proceed to polish phase. Log should_fix items as polish candidates.

## Constraints

- Binary verdict: ITERATE or ACCEPT. No partial states.
- E2+ required for blocking regardless of source.
- Do not re-evaluate findings independently — trust run-review's evidence levels.
