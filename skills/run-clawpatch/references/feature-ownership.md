# Feature Ownership

Manual `.clawpatch/features/*_manual.json` files (`source: manual-*`) are the **source of truth** for what gets reviewed. Before a scoped review, reconcile the changed surface against manual feature ownership. `review --since` selects candidates; it does **not** prove coverage — review every *affected manual feature* explicitly.

## Reconcile changed paths → manual features

1. Load every `.clawpatch/features/*_manual.json` and read its `ownedFiles`.
2. **Normalize `ownedFiles`** — entries may be objects (`{ "path": "src/x.ts", ... }`) or bare strings (`"src/x.ts"`). Treat the path as `entry.path ?? entry`. Compare resolved paths, not raw strings.
3. For each changed path, find the manual feature(s) that own it.

Outcomes per changed path:

| Case | Action |
|---|---|
| Owned by exactly one manual feature | nothing to add; that feature is in scope for review |
| Owned by no feature, but clearly belongs to one coherent surface | add the path to that feature's `ownedFiles` |
| Owned by no feature and forms a new coherent surface | create a new `*_manual.json` (`source: manual-<area>`, `status: pending`, `ownedFiles` for the surface) |
| **Ambiguous** — could belong to several, or no coherent owner | **halt** — surface the path and candidate owners; do not guess |

## Manual features are sacrosanct

Never auto-prune or status-flip a `source: manual-*` feature during reconciliation. If reconciliation appears to require removing a manual feature or flipping its status to `skipped`, that is a **halt**, not an edit — manual state is owned by humans.

- A feature owning **both** real paths and scratch/derived paths is **not** purely derived — do not prune it.
- A manual feature that appears to own a scratch/derived path means your scope is too broad — **refine the scope, do not touch the feature**.
- Stable statuses are `pending`, `reviewed`, `needs-fix`, `fixed`, `revalidated`, `skipped`, `error`. New manual features start `pending`.

These rules mirror the mixed-scratch recovery hardening in the upstream runbook: fail-secure and stop rather than mutate manual features on ambiguous ownership.

## Never re-seed to "fix" ownership

Do **not** run `clawpatch map`, `init --force`, or any re-seed to repair ownership — these flip existing manual statuses and flood the map with scratch/worktree-derived features. Reconcile by hand-editing manual JSON only.

## Validate + checkpoint

- After editing/creating feature JSON, confirm it parses and uses a stable `status`. If the project ships a feature-map validator (e.g. a `check-*-feature-map` script), run it; otherwise validate JSON shape with `jq`.
- Commit the feature-ownership change as its own checkpoint **before** any code fixes (see `worktree-session.md`).

## Anti-Patterns

- Trusting `review --since` as coverage proof instead of reconciling each affected manual feature.
- Comparing raw `ownedFiles` strings without normalizing object/string form.
- Auto-pruning or flipping a manual feature on ambiguous or mixed ownership — halt instead.
- Running `clawpatch map`/`init --force` to repair ownership.
- Inventing a feature owner for a path with no coherent surface — halt and ask.
