# Finalize

## Role

Sole completion authority (mainthread-only). Checks content gates, manages spec status, declares outcome.

## Input

- `verification_result` — PASS, FAIL, or PARTIAL with specifics (from verify phase)
- `files_modified` — repo-relative list of all changed files
- `plan.md` — approved plan (check for spec reference line)
- `scope_artifact` — depth, `docs_impact`, behavior-change flag

## Instructions

### 1. Check Content Gates

**Precondition**: Phase Trace has 6 rows (scope through verify); expected artifacts exist for each dispatched phase.

Gate applies on PASS only. On FAIL/PARTIAL, skip to completion declaration.

| Gate | Condition | Required evidence |
|------|-----------|-------------------|
| Tests | behavior-changing work | E3 — test run output showing coverage |
| Edge/failure coverage | risk-bearing work | E3 — tests for edge and failure paths |
| Docs | `docs_impact` ≠ `none` | updated docs; changelog when `customer-facing` or `both` |

Any unmet gate on a PASS path = incomplete. Surface as gap, not advisory.

### 2. Learnings

Identify patterns worth preserving (skill updates, memory entries, rule changes).
Propose only — never auto-apply. User must approve each update before it is written.

### 3. Spec Status Update (conditional)

Skip entirely when plan.md contains no `> Spec: <path> | Phase N of <total>` line.

When reference line present:
1. Parse phase number N and spec path from the line.
2. Spec file missing at parsed path → warn and skip.
3. Phase already `[x] done` → skip with note.
4. Otherwise propose: "Phase N complete. Update spec status to `[x] done`?"
5. User confirms → edit the phase's Status table row in the spec (`[~] in-progress` or
   `[ ] pending` → `[x] done`).
6. User declines → note it, proceed.
7. After status update (or user decline), append to progress.md in the spec directory:
   ```
   | YYYY-MM-DD | Phase N | completed | <1-line phase summary> |
   ```
8. If execution diverged from spec, append additional row:
   ```
   | YYYY-MM-DD | Phase N | divergence | <what diverged and why> |
   ```
9. progress.md missing at spec directory → warn and skip (do not create).
10. After update: if all phases are `[x] done` → note "Spec is complete."

Gate this entire step on PASS. On FAIL/PARTIAL: skip spec update.

### 4. Completion Declaration

- **PASS + all content gates met**: `Implementation complete.`
- **PASS + content gates unmet**: `Implementation NOT complete` — list each unmet gate with specifics.
- **FAIL or PARTIAL**: `Implementation NOT complete` — list specific gaps from `verification_result`.

### 5. Session Log

Append: completion declaration, final `files_modified`, open items if any.

## Output

- Completion declaration (exact phrase per above)
- Unmet gates or gaps listed when incomplete
- Spec update outcome (updated / declined / skipped — with reason)
- Learnings proposals (if any)

## Constraints

- Never declare `Implementation complete.` without checking content gates.
- Never auto-apply learnings — proposal only, user approval required.
- Never update spec status without explicit user confirmation.
- Never skip spec status update when reference line exists in plan.md.
- Never create progress.md if missing — warn and skip only.
- Gate all success-side-effects (spec update, learnings, completion declaration) on PASS.
