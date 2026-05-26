# Git Worktrees — User Guide

Run parallel branches without stashing or re-cloning. A git worktree is a second working directory attached to the same repository — its own branch, its own files, the same git history. Spine's `use-worktree` skill creates worktrees that are immediately runnable (local config and dependencies carried over) and that stay connected to the originating Spine session.

## How It Works

Invoke `/use-worktree` from any provider (Claude Code or Codex). It wraps one shared POSIX script with six subcommands:

| Subcommand | Does |
|---|---|
| `create <slug>` | New branch + worktree at `.worktrees/<slug>-<hash>/`, ready to run |
| `list` | Show all worktrees (reads `git worktree list`) |
| `remove` | Remove a worktree directory (branch kept) |
| `prune` | Clear orphaned worktree admin files |
| `sync <name>` | Rebase the worktree branch onto current main (no fetch) |
| `land <name>` | Rebase → merge into main → remove worktree → delete branch |

Worktrees live **inside the repo** at `.worktrees/<slug>-<hash>/` — gitignored, so they never get committed. The `<slug>-<hash>` name matches Spine's `.scratch/` session-folder convention (`openssl rand -hex 2` suffix), so worktrees are easy to spot and correlate.

## Creating a Worktree

```
/use-worktree create fix-session-expiry
```

`create` does five things in order:

1. **Ignore guard** — verifies `.worktrees/` and `.scratch/` are gitignored. Any that aren't get an anchored entry appended to `.git/info/exclude` (not the committed `.gitignore` — no commit needed, and it covers every linked worktree at once).
2. **Branch + worktree** — `git worktree add .worktrees/fix-session-expiry-a1b2/ -b fix-session-expiry`. The branch is created with a real checkout (not detached HEAD).
3. **Session bridge** — symlinks `.scratch/` into the worktree. Every `.scratch/<session>/` path resolves unchanged, so an agent in the worktree reads *and writes* the parent Spine session's plan/design/build artifacts. One coherent session across both directories.
4. **Carry-over** — copy-on-write clones (`cp -cR`, APFS `clonefile`) every gitignored file into the worktree: `.env.local`, `config/*.local`, `node_modules`, build output. Instant, independent, near-zero disk. The worktree app runs without a manual `install`. Skipped: `.worktrees/` (would nest worktrees recursively) and `.scratch/` (symlinked instead).
5. **Reports** the worktree path.

Re-run with `--refresh` to re-copy carried-over files after the main checkout's local state changes.

**Session-bound creation (slug auto-derivation)** — invoking `create` with no slug derives one from the active Spine session. The script inspects `.scratch/*/session.json`, picks the single record with `status: in_progress` and `attention_required: false`, and strips the trailing `-<4hex>` suffix from the `session_id` to recover the slug. So:

```
/use-worktree create
```

inside a session named `phase-loop-build-cd10` creates `.worktrees/phase-loop-build-<hash>/` on branch `phase-loop-build`. The mapping is one-shot: pass `--session=<id>` to disambiguate when multiple sessions are in progress, or supply an explicit slug to bypass the lookup entirely. With zero active sessions or an ambiguous set, the script refuses and prints what it needs. This keeps the slug nomenclature aligned with `.scratch/<session>/` automatically — no manual restating of the session name.

**Extending the carry-over skip-list** — create a `.worktree-skip` file at the repo root to exclude additional paths from carry-over. One path per line; `#` lines are comments.

```
# .worktree-skip — paths to skip during worktree carry-over
large-assets/
secrets-local/
```

## Working in a Worktree

The worktree is an ordinary directory — `cd` into it and run any provider:

```sh
cd .worktrees/fix-session-expiry-a1b2/
claude          # or: codex
```

Spine hooks (TypeScript/Svelte/Biome post-edit checks, AGENTS.md injection) work correctly inside the worktree — the `.git`-as-file detection fix (Slice 1) repairs root resolution for linked worktrees.

Because `.scratch/` is symlinked, the agent in the worktree shares the originating session: it sees the same `session-log.md`, frame/design/build artifacts, and writes back to the same place. No handoff file needed.

## Syncing with main

As main advances, keep the worktree branch up to date with `sync`:

```
/use-worktree sync fix-session-expiry-a1b2
```

`sync` runs `git rebase <main-branch>` inside the worktree — no `git fetch`, because worktree branches are local and share the same object store as main. On success it prints:

```
synced: /path/to/.worktrees/fix-session-expiry-a1b2  (rebased onto main)
```

If the rebase hits a conflict, `sync` stops with **exit code 3**, leaving the rebase in progress — it never guesses a resolution. The agent then resolves the conflict and verifies the result (including running your project's tests) before reporting back; you are pulled in only if that verification fails. See [Conflict resolution](#conflict-resolution) below.

## Viewing Changes in Zed

> **Terminology trap:** Zed calls *every* root folder it opens a "worktree" — its file-indexing unit, unrelated to git. This guide says **"git worktree"** for the Spine concept and **"Zed project folder"** for Zed's. Never trust a bare "worktree" in Zed docs without checking which is meant.

### Open the worktree as its own window

```sh
zed .worktrees/fix-session-expiry-a1b2/
```

This is the **recommended** way. Zed follows the `.git`-file pointer to the shared object store, scopes the whole git integration to the worktree's branch, and shows the branch name in the title bar. Each worktree gets its own correctly-scoped git panel.

Avoid `workspace: add folder to project` (adding the worktree as a *second* folder in the main window) when you need accurate git status — Zed's multi-root git panel shows only **one** active repository at a time.

### See what changed

| View | Open with | Shows |
|---|---|---|
| **Git panel** | `Ctrl-G` or panel icon | Every changed file, staged + unstaged, vs the worktree branch's HEAD |
| **Gutter markers** | automatic | Per-line add/modify/delete bars; click to expand the hunk |
| **Project Diff** | `Ctrl-G D` or `git: diff` | All changes in one scrollable multibuffer — editable, stageable, split or unified |

The diff base is the **HEAD of the worktree's branch** — not `main`, not the main checkout's HEAD. CLI changes show up immediately (file watcher). This is exactly the "work-in-progress on this branch" view you want.

### Compare against main

Zed's `git: branch diff` command (command palette) does a merge-base comparison — equivalent to `git diff main...HEAD`, showing only commits unique to the branch. **Limitations:** it auto-detects the base branch (you cannot pick an arbitrary ref), and there is no file-list panel to navigate. For precise comparison, use the terminal:

```sh
git diff main...HEAD              # all changes since branching
git diff --name-only main...HEAD  # just the file list
git log main..HEAD --oneline      # commits on the branch
```

### One-time Zed setup

Add to the **main repo's** `.zed/settings.json` (applies to everyone opening the project):

```json
{
  "project_panel": { "hide_gitignore": true },
  "file_scan_exclusions": [
    "**/.git", "**/.svn", "**/.hg", "**/.jj", "**/CVS",
    "**/.DS_Store", "**/Thumbs.db", "**/.classpath", "**/.settings",
    "**/.scratch"
  ]
}
```

- `hide_gitignore: true` — keeps `.worktrees/` (and all gitignored paths) out of the project panel. `Cmd-P` and project search already exclude gitignored files by default.
- `.scratch` in `file_scan_exclusions` — stops Zed from watching the `.scratch` *symlink* inside worktrees, avoiding a known symlink file-watching edge case. **Re-list all defaults** as shown — Zed *replaces* the default list entirely when you set this key; omitting `**/.git` would make `.git` directories appear in the panel.

### Zed gotchas

- **Update Zed.** Worktree git-panel accuracy (correct branch name, no cross-contamination) was buggy through 2025 and fixed across early-2026 stable releases. On an old version the panel may show `(no branch)` or garbled status — update first.
- **Trust each worktree.** Each new directory opens in Restricted Mode; click the trust modal or LSPs won't start.
- **One LSP set per window.** Each worktree window starts its own language servers — heavy ones (rust-analyzer, TypeScript) do not share across windows. With 1–2 worktrees open this is a non-issue.
- **Don't set `git.worktree_directory`.** It only controls where Zed's *own* picker creates worktrees; it doesn't affect Spine-created ones and can confuse the picker.

## Landing a worktree

When a feature is complete and ready to merge, `land` handles the full sequence in one step:

```
/use-worktree land fix-session-expiry-a1b2
```

`land` runs four operations in fixed order, halting on the first failure:

1. **Rebase** — rebases the worktree branch onto current main (same as `sync`). On a conflict, `land` stops here with **exit code 3** — main, the worktree directory, and the branch all untouched — and the agent resolves it (see [Conflict resolution](#conflict-resolution)) before `land` continues.
2. **Fast-forward merge** — runs `git merge --ff-only <branch>` from the main checkout. The fresh rebase guarantees this succeeds. If it somehow fails (e.g. main moved again between rebase and merge), `land` stops with a clear message.
3. **Remove the worktree** — runs a clean-check (`git status --porcelain`, same as `remove`) and then `git worktree remove --force`. A worktree-checked-out branch is locked against deletion until the worktree directory is gone — this step unlocks it.
4. **Delete the branch** — `git branch -d <branch>`. Safe because step 2 already merged it into main.

On success:

```
landed: fix-session-expiry merged into main; worktree and branch removed
```

The worktree directory is gone and the branch is gone — both are intentional and structurally required. If you need the branch back, `git reflog` will show the former tip.

## Conflict resolution

`sync` and `land` rebase the worktree branch onto main. When that rebase hits a conflict, the script stops with **exit code 3** and leaves the rebase in progress — it never resolves a conflict silently or guesses an outcome.

From there the agent takes over automatically:

1. **Hand off to `/run-merge`** — the agent builds a conflict brief and dispatches `/run-merge` (Spine's git conflict resolver). `/run-merge` resolves every conflicted file, drives `git rebase --continue` through every round, and writes a verdict.
2. **Verify** — a verifier checks the result against the resolved worktree: no conflict markers left, the rebase landed cleanly, both sides' intent survived, and your project's test command (if detectable) still passes.
3. **Continue** — if verification passes, work continues without interrupting you: `sync` is done; `land` proceeds through merge → remove → branch-delete. If verification fails, the agent stops and shows you exactly what went wrong.

You are pulled in only when automatic resolution cannot be verified — a clean conflict is handled end to end. The protocol the agent follows is in `skills/use-worktree/references/conflict-resolution.md`.

To abandon a conflicted rebase entirely instead of resolving it:

```sh
git -C <worktree> rebase --abort
```

## Cleaning Up

Worktrees are never auto-deleted. Remove one explicitly:

```
/use-worktree remove fix-session-expiry-a1b2
```

`remove` runs its own clean-check first: `git status --porcelain` empty (only carried-over/ignored artifacts remain) → it removes the worktree; non-empty (real uncommitted tracked work or genuine new untracked files) → it refuses and tells you. The branch is **kept** — `remove` only drops the directory.

`prune` clears orphaned worktree admin files left behind if a directory was deleted manually:

```
/use-worktree prune
```

## Concepts

**Worktree** — a second working directory for the same repo, on its own branch, sharing one git history and object store.

**`<slug>-<hash>`** — the worktree directory name, e.g. `fix-session-expiry-a1b2`. `slug` is yours; `hash` is a 4-char random suffix matching Spine's `.scratch/` session convention.

**Carry-over** — the gitignored working state (`.env.local`, `node_modules`, build output) copy-on-write cloned into a new worktree so it runs immediately. Independent clones, not symlinks — editing them in one branch never touches another.

**Session bridge** — the `.scratch/` symlink that makes a worktree agent share the originating Spine session.

**Coexistence with Claude Code's native worktrees** — Claude Code creates its own worktrees under `.claude/worktrees/` for `Agent isolation: worktree`. Spine's `use-worktree` does not touch those — it adds a parallel, user-driven path at `.worktrees/`. The Slice 1 hook fix repairs *both*.

## Troubleshooting

**Hooks not firing inside a worktree** — the `.git`-file detection fix must be installed (Slice 1). Re-run `install.sh`; confirm `_project.sh` and `inject-agents-md.sh` accept `.git` as a file.

**`remove` refuses** — `git status --porcelain` found real changes. Commit, stash, or discard them, then re-run. If the only changes are carried-over files you don't care about, that is what `remove`'s clean-check is protecting against — inspect before forcing.

**App won't run in a fresh worktree** — a needed local file wasn't carried over (outside the default gitignored set, or in the project skip-list). Re-run `create --refresh`, or copy the file in by hand.

**Worktree branch can't be deleted** — the branch is still checked out in the worktree. Run `remove` first; the branch unlocks once the directory is gone.

**Zed shows the wrong branch or garbled status** — update Zed to the latest stable; worktree git-panel bugs were fixed in early-2026 releases. If it persists, close and reopen the worktree window.
