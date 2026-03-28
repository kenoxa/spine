# Implement: Dispatch

## Input

Dispatch provides:
- `task` — what to implement (from user input or `scope_artifact.input_excerpt`)
- `partition_scope` — exact files assigned (edit boundary)
- `session_id` — carry forward in output
- `files_modified` — running list from prior dispatches (read-only; do not overlap)

## Instructions

- Read all files in `partition_scope` before making any edits.
- Implement every aspect of `task` that falls within `partition_scope`.
- Do not write to any file listed in `files_modified` from prior dispatches (overlap = conflict).
- No speculative features, extra error handling for impossible cases, or single-use abstractions.
- New symbols: match naming style of the file being edited.
- When task is ambiguous, resolve toward simplest interpretation.

## Output

Write to `{output_path}`. Report on completion:
1. `files_modified` — repo-relative list of all files changed, created, or deleted
2. Session ID echoed
3. Summary — one line per file: what changed and why
4. Follow-ups — unrelated issues found, not fixed

## Constraints

- Edit only within `partition_scope`.
- No build commands, test runners, or destructive commands.
- No backward-compat shims unless task explicitly requires them.
- Favor working code over exhaustive edge-case handling.
