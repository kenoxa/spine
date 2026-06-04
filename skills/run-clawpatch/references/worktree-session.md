# Worktree + Session

An autonomous review/fix campaign accumulates feature-map edits, review-state changes, and fixes. Those belong on a **dedicated review branch**, not as a growing dirty patch on `main`. Set up isolation **before the first `.clawpatch/` state change** (feature JSON edit, `review`, `fix`, `triage`, `revalidate`).

## Required setup (campaign mode)

1. **Worktree** — `/use-worktree create <slug>` (e.g. a clawpatch-campaign slug). Work inside `.worktrees/<slug>-<hash>/`; the script bridges `.scratch/` so the session is shared.
2. **Session attach** — `/use-session attach` against the bridged session. Do **not** fork a second `.scratch/<session>/`. Append `session.attach`; set `active_writer.branch`/`worktree_path` to the worktree. If the parent writer is still active → `writer_conflict`, stop.
3. **Confirm off `main`** — after setup, verify the working branch is the worktree branch. **Still on `main` → halt** (emit the final report, stop). Never make campaign state changes on `main`; `main` is read-only input.

## Commits

- Commit only on the worktree branch, only after green validation/revalidation.
- Small, scoped commits: commit a feature-ownership checkpoint before code fixes; commit each verified fix group separately when practical.
- Leave the branch and its commits as the human-review artifact. Do **not** push, open a PR, sync, land, merge, delete, or clean up the worktree/branch unless the user explicitly asks.

## Dirty tree

A dirty worktree with unrelated changes is a **stop** — do not stash, reset, checkout, clean, or overwrite unrelated work. Resolve scope only over intended changes. Include uncommitted work **only** when `--include-dirty` is passed and that work is explicitly in scope (then pass `--include-dirty` to `clawpatch review`/`revalidate`).

## Local-only escape hatch

`--local-only` / `--no-commit` skips this whole phase: preflight, status, dry-run, and bounded local edits with no worktree and no commits. Use it only when the caller explicitly wants local-only/no-commit work. Everything else (a real campaign) requires the worktree + attached session above.

## Anti-Patterns

- Editing feature JSON, running `review`/`fix`, or committing on `main`.
- Forking a new session inside the worktree when `.scratch` is already bridged.
- Stashing/resetting/cleaning unrelated dirt to "make room" for the campaign.
- Pushing/PR/land/merge/delete/cleanup of the branch without an explicit request.
