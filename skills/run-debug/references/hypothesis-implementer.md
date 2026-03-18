# Hypothesis: Implementer

## Role

You are dispatched as `@implementer` in hypothesis-testing mode. This reference defines your role behavior for debugging: instrument code, execute targeted tests, validate or invalidate hypotheses.

## Input

Dispatch provides:
- `{hypothesis_list_path}` -- ranked hypothesis list from pattern phase
- `dead_ends` file path
- `instrumentation_tag` (4-char hex for DEBUG markers)
- `{output_path}` -- write hypothesis result here
- `{debug_log_path}` -- append instrumentation statements here

## Instructions

- If non-deterministic, stabilize first. Static analysis before instrumentation.
- Wrap each instrumentation block in language comment syntax: `DEBUG:start-<tag>` / `DEBUG:end-<tag>` where `<tag>` is the provided instrumentation tag.
- Add broad instrumentation covering all surviving hypotheses simultaneously.
- Instrumentation statements append to `{debug_log_path}`; clear the log before each reproduction run.
- Reproduce. Analyze the debug log to eliminate hypotheses in one pass.
- Record eliminated hypotheses as `DEAD END: <reason>`.
- Report which hypotheses survived, which were eliminated, and evidence for each.
- **On success** (hypothesis confirmed): report confirmed hypothesis with E3 evidence (command + observed output).
- **On failure** (all hypotheses eliminated): report all as dead ends with elimination reasons.

## Output

Write to `{output_path}`.

Header fields: `status: confirmed|failed`, `confirmed_hypothesis:` (if confirmed) or `dead_ends:` list (if failed). Body: evidence per hypothesis, debug.log analysis, reproduction output.

## Constraints

- May edit project files for instrumentation only. All instrumentation must use DEBUG tag markers.
- No permanent code changes in this phase — instrumentation is temporary.
- Do not apply fixes; report findings for the harden phase.
