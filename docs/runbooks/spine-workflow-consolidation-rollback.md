---
updated: 2026-05-26
session: spine-workflow-consolidation-214f
spec: docs/specs/<followon>/spec.md
---

# Spine Workflow Consolidation — Rollback Runbook

If the autonomous-first consolidation lands broken on `main` and needs to be reverted, here is what to undo and in what order.

## When to use this runbook

Run if any of the following are observed within 72 hours of merge:

- Autonomous `/goal` sessions emit `goal-prompt.md` that does NOT load phase-discipline references (MANDATORY-load stub silently skipped).
- Rendered `goal-prompt.md` exceeds 4000 chars on a template that previously fit (cap-breaking regression).
- `bash skills/run-curate/references/lint-no-run-cycles.sh` exits non-zero on `main` HEAD (regression).
- Cross-provider divergence (Claude/Codex/Cursor/OpenCode) on the same synthetic test that passed pre-merge.
- Routing failure: user input matching former do-* trigger phrases ("frame this", "design", "implement and review") does NOT activate `/use-goal-prompt`.

## What survives a revert

Slice 5 deliverables (this runbook + telemetry classification) are write-only docs. They can stay on `main` after a revert; they document a moment in time and have no production dependencies.

## Revert procedure

**Single-PR rollback** is the canonical path — the consolidation landed as one merge per atomic-landing constraint M5. Reverting the merge commit restores prior state in one operation:

```bash
git revert -m 1 <merge-commit-sha>
```

This restores the four `skills/do*` directories, the `differential-review` registry entries in `install.sh` / `skill-overrides.yaml` / `CONTRIBUTING.md`, the prior `/use-goal-prompt` SKILL.md, all 7 templates without phase-discipline stubs, and the prior `SPINE.md` (without the No-run-cycles invariant).

Do NOT cherry-pick partial reverts. The atomic-landing constraint means partial revert produces a half-migrated state worse than either endpoint.

## Provider-cache clearing

After the revert, harness caches may still index the deleted skills. Clear per provider:

| Provider | Action |
|----------|--------|
| Claude Code | Restart Claude Code (skill index rebuilt on session start). Verify via `/help` listing. |
| Codex | No persistent index — next `/goal` invocation reads SPINE.md fresh. |
| Cursor | Restart Cursor. Cursor reads `~/.cursor/rules` on session start; the prior SPINE.md content restores via `install.sh`. |
| OpenCode | Restart OpenCode CLI. `opencode/spine-hooks.ts` is recompiled from source on next run. |

## Re-sync ~/.config/spine/

The project SPINE.md and `~/.config/spine/SPINE.md` are NOT symlinked — the installer copies. After revert, re-sync:

```bash
bash install.sh
```

Verify with:

```bash
diff SPINE.md ~/.config/spine/SPINE.md
```

Expected: no diff (or only `updated:` frontmatter timestamp).

## Restoring external-sync skills

`install.sh` pulls `differential-review` from `trailofbits/skills`. Post-revert, re-run:

```bash
bash install.sh
```

This restores `differential-review` to `~/.claude/skills/` (or the active provider's skill dir).

## Verification (post-revert E3 checks)

Run each and confirm:

```bash
ls skills/do skills/do-frame skills/do-design skills/do-build   # all four dirs present
grep -l 'differential-review' install.sh CONTRIBUTING.md docs/global-skills.md   # all three return matches
bash skills/run-curate/references/lint-no-run-cycles.sh   # may FAIL — invariant didn't exist pre-merge; acceptable
ls skills/use-goal-prompt/references/phase-discipline-*.md 2>/dev/null   # should return nothing (compiler-upgrade reverted)
```

## Escalation

If revert + re-sync does not restore working state, escalate to a fresh `/use-goal-prompt` invocation with template `interrogate` against the question "why did the consolidation revert fail to restore prior working state?". That triggers frame-phase discipline against the failure mode.

## Telemetry follow-up

Capture the failure mode in `.scratch/<new-session>/post-mortem.md` with E2+ evidence. Reference this runbook + the original `design-artifact.md` at `.scratch/spine-workflow-consolidation-214f/design-artifact.md` so the next attempt has full context.
