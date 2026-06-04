# Scope Resolution

Resolve the caller's scope selector to a single git ref (or "unscoped"), then collect the changed paths that drive ownership reconciliation. Scope is **selection only** — it decides which surface to look at, not which manual features are covered (that is the ownership phase).

## Selector precedence

Exactly one scope applies. If several are passed, the first present wins:

`--since <ref>` > `--days <n>` > `--last-run` > `--all-open` > (default) `--last-run`.

## Resolving to a ref

Prefer the helper over hand-rolled shell — it removes fragile mtime/date arithmetic and is unit-tested:

```sh
sh <skill-dir>/scripts/resolve-scope.sh <scope-args>   # prints one line: a ref, or UNSCOPED
```

`<skill-dir>` is this skill's install directory (`skills/run-clawpatch/` in-repo, `~/.agents/skills/run-clawpatch/` installed). Run from the project root or worktree; pass the caller's scope args verbatim (unrelated knobs are ignored). Read-only (git + filesystem) — never touches `.clawpatch/` state. What each selector resolves to:

| Selector | Resolution |
|---|---|
| `--since <ref>` | validate `git rev-parse --verify <ref>^{commit}`; use the ref directly |
| `--days <n>` | `git rev-list -1 --before="<n> days ago" HEAD` |
| `--last-run` | newest `.clawpatch/reports/*` mtime → `git rev-list -1 --before="<mtime>" HEAD` |
| `--all-open` | no ref → `UNSCOPED`; selection is by finding status, not timeframe |

**Unresolvable** `--last-run` (no reports yet, or no commit before the report mtime) → `UNSCOPED`. Do not invent a ref. An invalid explicit `--since <ref>` is a **halt** (the caller named something that does not exist) — surface it, do not silently fall back.

## Collecting changed paths

For a resolved ref, the changed surface feeds the ownership phase:

```sh
git diff --name-only <ref>..HEAD
```

- `--all-open` / `UNSCOPED`: skip changed-path collection — operate on existing findings by status, not by diff.
- `--include-dirty`: only when uncommitted work is explicitly in scope. Add `git diff --name-only HEAD` (staged + unstaged) to the changed set and pass `--include-dirty` to `clawpatch review`/`revalidate`. Without the flag, a dirty tree is a **stop** (see `worktree-session.md`), not an auto-include.

## Output of this phase

Record in the session log: the resolved ref (or `UNSCOPED`), the selector used, and the changed-path list (or "n/a — unscoped"). These are inputs to ownership reconciliation; the ref is reused verbatim in `clawpatch review --since <ref>`.

## Anti-Patterns

- Inventing a ref when `--last-run` cannot resolve — go unscoped instead.
- Silently downgrading an invalid explicit `--since <ref>` to unscoped — halt and surface.
- Auto-including a dirty tree without `--include-dirty`.
- Treating the changed-path list as proof of feature coverage — it is the input to reconciliation, not the result.
