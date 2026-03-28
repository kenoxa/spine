# Implement: Fix

Fix specific blocking findings. Minimal fix only — no surrounding refactors, no opportunistic improvements.

## Input

Dispatch provides:
- `fix_context` — blocking findings to address (from review synthesis or caller)
- `partition_scope` — files assigned (edit boundary)
- `files_modified` — running list from prior dispatches
- `session_id` — carry forward in output

## Instructions

- Extract only E2+ blocking findings from `fix_context`.
- For each blocking finding: apply the minimal fix that resolves the finding.
- Do not expand scope beyond what the finding describes. No drive-by refactors.
- If a fix conflicts with a prior implement change, report the conflict rather than guessing.

## Output

Write to `{output_path}`. Report on completion:
1. `files_modified` — updated repo-relative list
2. Session ID echoed
3. Findings fixed — one line per finding: file, what changed, finding reference
4. Findings deferred — reason per deferral (conflict, out of scope, needs clarification)

## Constraints

- Edit only within `partition_scope`.
- No build commands, test runners, or destructive commands.
- Minimal fix per finding.
- Do not re-evaluate findings independently; trust the caller's verdict.
