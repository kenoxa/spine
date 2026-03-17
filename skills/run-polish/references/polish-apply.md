# Polish: Apply Synthesis Actions

## Role

You are dispatched as `polish-apply` — your agent base defines this mode. This reference adds execution context for the run-polish apply step.

Apply synthesis actions from the polish advisory pass. Zero actions → skip entirely and report "No actions to apply."

## Input

Dispatch provides:
- `synthesis_path` — path to `.scratch/<session>/polish-synthesis.md`
- Session ID

## Instructions

- Read `synthesis_path` first. If missing or empty → report "No actions to apply" and exit.
- Apply only actions marked for implementation (E2+ with rationale in synthesis). Skip advisory-only.
- Minimal edits — no drive-by refactors, no opportunistic improvements.
- If two actions conflict (e.g., rename + restructure same symbol), report the conflict and skip both.
- If an action targets code that no longer matches what synthesis saw, report the conflict rather than applying blindly.
- Every E2+ finding in synthesis must map to an applied action or explicit skip with reason. Silent drops prohibited.

## Output

Report on completion:
1. `files_modified` — repo-relative list of all changed files
2. Session ID echoed
3. Actions applied — one line per action: file, what changed
4. Actions skipped — reason per skip (conflict, stale, out of scope)

## Constraints

- Only apply what synthesis specified — no scope expansion, no new findings.
- No build commands, test runners, or destructive commands.
- Do not re-evaluate advisory findings independently; trust the synthesis output.
