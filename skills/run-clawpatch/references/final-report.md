# Final Report

The campaign's DONE/STOP evidence. Run a final sweep, then write one report artifact that a human can act on without replaying the session.

## Final sweep

Before writing the report, revalidate everything still open:

```sh
clawpatch revalidate --all --status open      # or the scoped equivalent: --since <ref> --status open
```

Record the run id and exit for the sweep. If you cannot run it, state why in the report.

## Report contents

Write to the session dir (e.g. `.scratch/<session>/clawpatch-report.md`) and reference it from the terminal status. Cover:

- **Scope** — resolved ref (or "unscoped"), and the selector used.
- **Location** — worktree branch + path, and session path. State the branch is left **unpushed/unmerged for human review** unless the user explicitly requested merge/land.
- **Review** — commands run; open-finding totals **start → end**.
- **Ownership** — manual feature JSON changed/created; any unowned or uncertain paths (with the halt reason if applicable).
- **Findings** — per finding: id, bucket (fixed / triaged / left-open), reason, and revalidation status (run id + exit for fixes; evidence note for triage; reason for open).
- **Changes** — changed paths, commit hashes + messages, latest `.clawpatch/reports/*` path.
- **Final status** — `done` (last review 0 new open, or all open items have stop reasons) or `halted` with the halt signal and which stop rule fired.

## DONE vs HALTED

- **done** — last review yields 0 new open findings, or every remaining open item has a recorded stop reason; every changed path owned or documented uncertain; every fix green-revalidated; every triage evidenced.
- **halted** — a halt signal fired (still on `main`, ambiguous ownership, dirty tree, 5 consecutive revalidation failures, missing scope metadata, preflight failure). Record the signal and the current state; under `/goal` this is emit-artifact-and-halt — do not auto-relaunch.

## Anti-Patterns

- Declaring done without the final sweep (or without stating why it was skipped).
- Reporting "fixed" without the revalidation run id + exit.
- Omitting the explicit "branch left unpushed for human review" statement.
- Burying the halt reason instead of naming the stop rule that fired.
