---
id: 2621-unified-git-worktrees
status: in-progress
updated: 2026-05-21
frame_artifact: .scratch/unified-git-worktree-approach-spine-c565/frame-artifact.md
design_artifact: .scratch/unified-git-worktree-approach-spine-c565/design-artifact.md
session_id: unified-git-worktree-approach-spine-c565
---

# Unified Git Worktree Approach

## Goal

A manual, user-driven git-worktree mechanism for Spine that behaves identically under Claude Code and Codex, keeps a worktree connected to its originating Spine session, and integrates cleanly with the Zed editor. The user drives worktrees by hand; Spine supplies one skill and a set of conventions — no `run-queue` or `do-build` autowiring.

## Why

Spine has zero worktree orchestration today. Claude Code creates native worktrees under `.claude/worktrees/` for `Agent isolation: worktree`; Codex has none; `run-queue` isolates tasks with in-place branch checkout, not worktrees. Three concrete gaps block manual worktree use:

1. **Hooks break in worktrees.** `_project.sh:17` and `inject-agents-md.sh:41` test `[ -d .git ]`. In a linked worktree `.git` is a *file* (`gitdir:` pointer), so root detection fails — `check-on-edit.sh` then fails open silently, leaving TypeScript/Svelte/Biome post-edit checks dead inside every worktree.
2. **Session context is lost.** `.scratch/<session>/` is the workflow spine (session-log, frame/design/build artifacts) and is gitignored — `git worktree add` does not carry it, so an agent in a worktree loses planning context.
3. **Local working state is lost.** `.env.local`, `config/*.local`, `node_modules`, build output are all gitignored — a fresh worktree cannot run without a manual reinstall.

## Scope

### In

- **Slice 1** — fix hook root-detection for linked worktrees; bats regression coverage.
- **Slice 2** — `use-worktree` skill: one shared POSIX script with `create` / `list` / `remove` / `prune`; ships `docs/worktree-guide.md`.
- **Slice 3** — `sync` / `land` subcommands for bidirectional main↔worktree integration.

### Out

- `run-queue` / `do-build` / `Agent isolation` autowiring — scope is manual only.
- Overriding or relocating Claude Code's native `.claude/worktrees/` — Spine coexists, never overrides.
- OpenCode parity — descoped at the design gate. The shared script stays POSIX-portable; OpenCode is a later verification, not a redesign.
- Non-macOS carry-over — APFS copy-on-write (`cp -cR`) is assumed; macOS-only environment.

## Key design decisions

| Decision | Resolution |
|---|---|
| Placement | In-project `.worktrees/<slug>-<hash>/`, ignored via `.git/info/exclude`. |
| Naming | `<slug>-<hash>`, `openssl rand -hex 2` — matches the `.scratch/` session-folder convention. |
| Hook `.git` detection | Marker fix `[ -d .git ] \|\| [ -f .git ]` in `_project.sh` + `inject-agents-md.sh`. Not a refactor. |
| Session bridge | Symlink the whole `.scratch/` directory into the worktree (one absolute symlink). Every `.scratch/<session>/` path resolves unchanged; `use-session attach` reuses the existing machine/log state instead of forking a new session. Gitignored, so never committed; `git worktree remove` drops it. |
| Carry-over | CoW-copy (`cp -cR`) every gitignored file into the worktree. Built-in skip set: `.worktrees/` (mandatory — prevents recursive nesting) and `.scratch/` (symlinked instead). Project-extendable skip-list. `--refresh` re-copies. |
| Ignore guard | `create` runs `git check-ignore` on `.worktrees/` and `.scratch/`, appends an anchored entry to `.git/info/exclude` (common git dir, no commit, covers every linked worktree) for any not already ignored. |
| Parity mechanism | One shared POSIX script all CLIs invoke — a runnable contract, not LLM-interpreted prose. |
| Registry | `git worktree list --porcelain` — never a hand-maintained manifest. |
| Cleanup | Manual, never auto-delete. `remove` runs its own clean-check (`git status --porcelain` empty → `git worktree remove --force`; non-empty → refuse). `prune` clears orphaned admin files. |
| `sync` / `land` | Branches local-only. `sync` = rebase the worktree branch onto current `main` (no fetch — shared object store). `land` = rebase → `git merge --ff-only` into `main` → `remove` worktree → `git branch -d`, in that fixed order. |
| Skill prefix | `use-worktree` — tool-wrapper family (`use-shell`, `use-js`). |
| User guide | `docs/worktree-guide.md` ships with Slice 2 — lifecycle how-to plus a Zed editor section. `.zed/settings.json` setup is documented, not skill-automated (keeps the cross-provider skill editor-agnostic). |

## Success criteria (EARS)

1. **SC1** — When a hook resolves project root from a path inside a linked worktree (`.git` is a file), it shall return the worktree root, not the main checkout.
2. **SC2** — When a `.ts` file is edited inside a worktree, the TypeScript post-edit checker shall run.
3. **SC3** — When `create <slug>` runs, it shall produce a runnable worktree at `.worktrees/<slug>-<hash>/` with gitignored local state carried over as independent CoW clones.
4. **SC4** — An agent inside a worktree shall read and write the originating session's `.scratch/<session>/` artifacts through the symlink.
5. **SC5** — `create` shall ensure `.worktrees/` and `.scratch/` are gitignored before planting any worktree directory or symlink.
6. **SC6** — `remove` shall remove a worktree carrying only carried-over artifacts, and shall refuse when real uncommitted tracked work or genuine untracked files are present.
7. **SC7** — `sync` shall rebase the worktree branch onto current `main`; `land` shall round-trip merge → remove → branch-delete in order, halting before any destructive step on a rebase conflict.
8. **SC8** — The skill shall behave identically under Claude Code and Codex, enforced by the single shared script.
9. **SC9** — `docs/worktree-guide.md` shall ship with the `use-worktree` skill and be linked from the docs index.

## Rejected

- **`cow` / `grove` / `treebeard`** as the worktree mechanism — they produce independent repos and break no-fetch sync. `cp -cR` (the CoW primitive) is kept only for carry-over.
- **Classified carry-over manifest** (council's 3-mechanism taxonomy) — APFS CoW removes the cost rationale for a taxonomy; blanket copy-by-default flips the failure mode so a forgotten file is present, not silently missing.
- **`--git-common-dir` resolution** for the session bridge — a whole-directory absolute symlink needs zero skill or SPINE.md changes and collapses a slice.
- **Editing committed `.gitignore`** for the ignore guard — it would need a commit and would not reach a worktree (which checks out `.gitignore` from HEAD). `.git/info/exclude` covers all worktrees live.
- **Symlinking secrets or `node_modules`** — a shared mutable file across branches; breaks pnpm/peer-dep/native-addon resolution. Carry-over CoW-copies them instead.
- **Leaning on `git worktree remove`'s bare refuse-on-dirty** as the safety net — `create` deliberately plants ignored artifacts, so plain `remove` always refuses; `remove` runs its own clean-check then `--force`.
- **Queue-style orchestration** for `sync`/`land` — worktree operations remain manual. Rebase conflicts may delegate to the now-generic `run-merge` brief flow, but no queue runner or supervisor is recreated.

## Delivery slices

See `progress.md` for per-slice status. Slice 2 is gated on Slice 1 merged plus a mandatory cross-provider preflight (a real `git worktree add`, both fixed hooks executed inside it, the `create` script executed once in a Codex batch context) — this lifts the "shared script delivers cross-provider parity" claim from E0 to E3.

## References

- `design-artifact.md` — full resolved-decisions table, delivery slices, constraints
- `frame-artifact.md` — frame with constraints and success criteria
- `advise-synthesis.md`, `council-synthesis.md` — advisory + council inputs
- `research-zed-worktrees.md` — Zed editor + git worktree findings (feeds the user guide)
- `worktree-guide-draft.md` — draft of `docs/worktree-guide.md`
- obra/superpowers `using-git-worktrees`, NeoLabHQ/context-engineering-kit `git-worktrees` — external reference skills
