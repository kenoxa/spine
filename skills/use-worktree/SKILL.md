---
name: use-worktree
description: >-
  Use when: 'create a worktree', 'git worktree', 'parallel branch'.
argument-hint: "[create <slug> | list | remove <name> | prune | sync <name> | land <name>]"
---

Manual git-worktree lifecycle; wraps one POSIX script all providers invoke.

## Invocation

```sh
sh <skill-base-dir>/scripts/worktree.sh <subcommand>
```

Run from within the target project directory. `<skill-base-dir>` is the directory containing this file.

## Subcommands

| Subcommand | Does |
|---|---|
| `create [<slug>] [--session=<id>] [--refresh]` | New branch + worktree at `.worktrees/<slug>-<hash>/`, carry-over gitignored files. Omit `<slug>` to derive from the active session |
| `list` | Show all worktrees annotated with `[spine]` for ones under `.worktrees/` |
| `remove <name>` | Clean-check then remove worktree directory (branch kept) |
| `prune` | Clear orphaned worktree admin files |
| `sync <name>` | Rebase the worktree branch onto current main (no fetch — shared object store) |
| `land <name>` | Rebase → fast-forward merge into main → remove worktree → delete branch |

`<name>` for `remove`/`sync`/`land` resolves any of: a path, the `.worktrees/` directory name (`<slug>-<hash>`), or the bare branch/slug — so `land my-feature` works without the hash suffix.

## Key Behaviors

- **Ignore guard** — writes anchored entries (`/.worktrees/`, `/.scratch`) to the common git dir's `info/exclude` before planting; idempotent; never touches committed `.gitignore`. The `.scratch` anchor omits the trailing slash so it also matches the bridge symlink inside a worktree.
- **Session bridge** — `.scratch/` is symlinked into the worktree so agents share one coherent Spine session (same `session.json`, `events.jsonl`, `session-log.md`, frame/design/build artifacts).
- **Session attach** — when a bridged session exists, run `/use-session attach` and continue that session. Do not silently create a second `.scratch/<session>/`; writer conflicts or contradictory branch/worktree state mark `attention_required` and stop.
- **Slug auto-derivation (G1)** — `create` with no slug picks the single `status: in_progress` session under `.scratch/*/session.json` (with `attention_required: false`) and strips the trailing `-<4hex>` from its `session_id` to recover the slug. Precedence: explicit `<slug>` > `--session=<id>` > sole active session. Refuses on zero or ambiguous active sessions. Keeps worktree slug and session name aligned without manual restatement.
- **Carry-over** — gitignored working state (`.env.local`, `node_modules`, build output) is copy-on-write cloned (`cp -cR`, APFS `clonefile`); `--refresh` re-copies after main state changes. Skip-list: built-in `.worktrees` + `.scratch`, plus project-specific entries in `.worktree-skip` (one path per line, `#` comments).
- **Clean-check on remove** — `git status --porcelain` (no `--ignored`) so carried artifacts + `.scratch` symlink are invisible; real tracked edits or genuine untracked files → refuse with detail.
- **sync / land** — `sync` rebases the worktree branch onto the current main branch (no `git fetch` — branches are local-only, shared object store). `land` runs rebase → `--ff-only` merge into main → worktree remove → branch delete, in fixed order; halts before any destructive step (exit code 3) if the rebase produces a conflict, leaving main, the worktree, and the branch all untouched.
- **Conflict resolution** — on a rebase conflict (`sync`/`land` exit 3, rebase left in progress) the agent delegates resolution to `/run-merge`, then `@verifier` re-verifies; the user is interrupted only if verification fails. Per `references/conflict-resolution.md`.
- **Location** — worktrees at `.worktrees/<slug>-<hash>/`; coexists with Claude Code's `.claude/worktrees/`, never overrides.

## Further Reading

`docs/worktree-guide.md` — full how-to: creating, working in, Zed editor setup, cleaning up, troubleshooting.

## Anti-Patterns

- Hand-maintaining a worktree manifest instead of `git worktree list`.
- Forking a new session inside a worktree when `.scratch` is already bridged.
- Symlinking secrets or `node_modules` (carry-over copies them — independent, not shared).
- Using `rm -rf` on a worktree dir instead of `remove` (orphans git admin files).
- Committing `.worktrees/` (it must stay gitignored; the ignore guard enforces this).
