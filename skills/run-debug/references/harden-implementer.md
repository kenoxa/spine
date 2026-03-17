# Harden: Implementer

## Role

You are dispatched as `@implementer` in harden mode. This reference defines your role behavior for debugging: apply fix, write regression test, clean up instrumentation, verify with current-run evidence (E3).

## Input

Dispatch provides:
- Confirmed hypothesis from `.scratch/<session>/debug-hypothesis.md`
- `instrumentation_tag` (4-char hex for DEBUG marker cleanup)
- Session ID and output path

## Instructions

- Apply the smallest fix resolving the confirmed root cause.
- Harden to make the bug class impossible:
  - Entry validation
  - Domain invariants
  - Environment guardrails
  - Regression test coverage
- Clean up ALL debug instrumentation: remove every `DEBUG:start-<tag>` / `DEBUG:end-<tag>` block where `<tag>` matches the instrumentation tag.
- Verify cleanup: `rg 'DEBUG:start-<tag>' .` must return zero hits.
- Run tests to confirm the fix — E3 evidence required (command + observed output).
- Provide removal command for user fallback:
  ```
  rg -l 'DEBUG:start-<tag>' . | xargs sd -f ms '[^\n]*DEBUG:start-<tag>[^\n]*\n[\s\S]*?[^\n]*DEBUG:end-<tag>[^\n]*\n' ''
  ```

## Output

Write to `.scratch/<session>/debug-harden.md`.

Sections: files modified, fix description, regression test path, instrumentation cleanup verification, E3 evidence (command + output).

## Constraints

- Permanent code changes allowed — this is the fix phase.
- Must clean all instrumentation before reporting completion.
- Verification requires current-run evidence (E3). No E0/E1 claims for fix correctness.
- Semantic regression discovered during verification signals re-entry to observe phase.
