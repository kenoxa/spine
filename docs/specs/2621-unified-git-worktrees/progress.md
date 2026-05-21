# Progress — 2621 Unified Git Worktrees

Session: `unified-git-worktree-approach-spine-c565`

## Delivery slices

| Slice | Description | Status |
|-------|-------------|--------|
| 1 | Hook root-detection fix for linked worktrees + bats regression test | done |
| 2 | `use-worktree` skill — `create`/`list`/`remove`/`prune` POSIX script + `docs/worktree-guide.md` | done |
| 3 | `sync` / `land` subcommands + agent-driven rebase-conflict resolution | done |

## Slice 1 — Hook correctness fix

- **Scope:** `hooks/_project.sh`, `hooks/inject-agents-md.sh`, `hooks/tests/worktree-root.bats`.
- **Change:** marker fix `[ -d .git ] || [ -f .git ]` on both root checks; new bats test creates a real linked worktree and asserts root resolution + no parent AGENTS.md leak.
- **Exit:** new bats test passes; existing `hooks/tests/` suite green; editing a `.ts` file inside a real worktree triggers the TypeScript checker.

## Slice 2 — Worktree lifecycle skill

- **Scope:** `skills/use-worktree/{SKILL.md, scripts/worktree.sh, tests/worktree.bats}`, `docs/worktree-guide.md`, `AGENTS.md` (Project Knowledge index line).
- **Change:** new `use-worktree` skill. `worktree.sh` — POSIX `sh` (`#!/bin/sh`, `set -eu`), 4 subcommands `create`/`list`/`remove`/`prune`. Worktrees live in-project at `.worktrees/<slug>-<hash>/`. The ignore guard writes anchored `/.worktrees/` and `/.scratch` entries to the common git dir's `info/exclude` (covers main + all linked worktrees live, no commit). Session bridge: `.scratch` symlink into the worktree. Carry-over: `cp -cR` (APFS copy-on-write clone) of gitignored top-level entries minus a built-in + project-extendable skip set (`.worktree-skip`).
- **Exit:** 12-test self-contained bats suite green (each test in its own `mktemp` repo, zero live-repo pollution); `shellcheck -s sh` clean; design `spine:managed` marker dropped (verified false — install.sh shebang-rewrite touches only `~/.config/spine/hooks/*`); `token-counts.yaml` updated.
- **Review:** 3 do-build review iterations to ACCEPT (cap 5). Iteration 1 — 15 findings (4 blocking) all resolved + a mainthread-found test-7 anchor defect (`/.scratch/` directory-only pattern never matches the `.scratch` symlink → trailing slash dropped). Iteration 2 — 3 findings (`_ensure_excluded` `check-ignore` early-return skipped the symlink-safe anchor; `core.quotePath=false` does not suppress quoting of space-named paths; dead comment) all resolved + 2 regression tests added. Iteration 3 — ACCEPT.

### Slice 2 follow-up debt (tracked — does not block)

- **Carry-over breaks on gitignored top-level names containing a literal tab, double-quote, backslash, or newline.** Git wraps such paths in `"..."` in `--porcelain` output *and* C-escapes the inner bytes (`\t`, `\"`, `\\`, `\n`); `core.quotePath=false` does not suppress this. The carry-over quote-unwrap (`worktree.sh:162-164`) strips only the outer `"..."` pair, so the escaped inner bytes survive and `cp -cR` targets a nonexistent path — `create` aborts with `cp failed:` and a non-zero exit. Classified follow_up: fails loud and fail-closed (no corruption, no write outside the worktree), the trigger class is pathological (real projects do not have such filenames). A complete fix needs a non-trivial POSIX-`sh` C-string unescaper (`printf '%b'` does not decode `\"`). **Workaround:** add the offending path to `.worktree-skip`, or rename it.

## Slice 3 — sync / land

- **Scope:** `skills/use-worktree/{SKILL.md, scripts/worktree.sh, tests/worktree.bats, references/conflict-resolution.md}`, `skills/run-merge/{SKILL.md, references/merge-brief-schema.md}`, `token-counts.yaml`.
- **Change:** Added `sync` and `land` subcommands to `worktree.sh`. `sync` rebases the worktree branch onto current main; `land` runs a fixed 4-step sequence — rebase → `merge --ff-only` into main → clean-check + force-remove worktree → delete branch, one guard per step. Rebase conflicts exit with a distinct status `3` (`CONFLICT_EXIT`) leaving the rebase IN PROGRESS so an agent can resolve and continue (`_conflict_exit` emitter + `_rebase_in_progress` detector). New `references/conflict-resolution.md` documents the exit-3 protocol: build a run-merge brief → invoke `/run-merge` to resolve every rebase round → re-verify with `@verifier` → continue. `/run-merge` (generalized upstream into a general merge resolver) is the conflict resolver; its rebase stage-ref labels were corrected — `git rebase` swaps the sides relative to a merge: `:2` = upstream/onto branch, `:3` = the replayed worktree commit.
- **Exit:** 20-test self-contained bats suite green (grew from 12; tests 13–20 cover sync/land happy paths, exit-3 conflict, exit-1 non-conflict failure, ff-merge, step-3 clean-check, main-worktree guard, detached-HEAD guard); `shellcheck -s sh` clean; `token-counts.yaml` updated. `make_repo` pins `rebase.autostash false` repo-locally so dirty-tree negative tests are deterministic regardless of the developer's global git config.
- **Review:** 3 do-build review iterations to ACCEPT (cap 5). Iteration 1 — findings resolved. Iteration 2 — verdict FAIL: B1 (bats suite inherited the user's global `rebase.autostash=true`, making test 14b non-deterministic — autostash let a rebase that should refuse instead complete), B2 (`/run-merge` rebase stage labels inverted — `:2`/`:3` swapped the wrong way), S1 (`worktree.sh` step-3 clean-check `die` message weaker than its sibling guards). Iteration 3 — ACCEPT; all 4 iteration-2 findings closed; verifier bats 20/20 under the user's real global config and under a forced-hostile `GIT_CONFIG_GLOBAL`.
- **Polish:** 1 iteration (cap 3). 2 actions applied — rename `conflict_exit` → `_conflict_exit` (private-helper prefix consistency with `_rebase_in_progress`); reword two test comments that leaked the run-review `S1` severity-bucket label. 4 complexity/duplication findings rejected → follow-up debt (below the third-use extraction bar / refactor-vs-feature separation).

### Slice 3 follow-up debt (2026-05-21 follow-up)

Resolved:

- **F1** — `/run-merge` now states that old merge-only briefs must add `operation: merge`; the skill must not infer a missing operation silently.
- **F2** — merge verification is now documented as semantic/set-based, not byte-identical; resolved files must have no conflict markers, completed git state, and valid `files_resolved` membership.
- **F3** — the rebase loop now specifies empty-commit handling: after a non-zero `rebase --continue`, skip only when a rebase dir still exists, no unmerged paths remain, and both cached and working-tree diffs are empty.
- **F4** — `worktree.bats` now probes `land "$repo"`, `land "$repo/"`, and `land .` for the main-worktree guard.
- **F6** — `repo_path` default is explicit in both `/run-merge` Phase 1 (`repo_path="${repo_path:-.}"`) and the schema's merge example/table.
- **F-r3-1** — `make_repo` now pins `rebase.backend=merge`, `merge.conflictStyle=merge`, and `rerere.enabled=false`; a hostile-global-config Bats case proves global `rebase.backend=apply` and `merge.conflictStyle=diff3` do not change the expected conflict shape.
- **R3 / R4** — repeated Bats `created:` parsing and `.worktrees/<slug>-*` non-empty guards are centralized in `created_worktree_dir` and `spine_worktree_dir`.
- **N1** — land guard/failure-path comments now use sequential test labels instead of `SF6a/b/c`.
- **`merge-brief-schema.md` token budget** — reference trimmed from 1448 tokens to 781 tokens via `scripts/token-counts.sh --update`, under the 250–800 target without splitting the run-merge loading path.

Still deferred:

- **R1** — `cmd_land` remains above the nominal complexity bar, but extraction is still deferred until a third production use appears; only `sync` and `land` share this flow today, and changing production command structure would exceed debt-cleanup scope.
- **R2** — `cmd_sync`/`cmd_land` name-resolution + branch-detection extraction remains deferred for the same third-use reason; no third production subcommand exists.

## Notes

- OpenCode parity descoped at the design gate — later verification, not a redesign.
- `inject-agents-md.sh` walk-up has a separate git-native rewrite (`git rev-parse`) tracked as a follow-up — out of scope for Slice 1, which applies the marker fix only.
- Envoy OpenCode lane (kimi-k2.6, deepseek-v4-pro, glm-5.1) timed out across Slice 2 and Slice 3 review iterations — recurring infrastructure flakiness; Codex + Cursor lanes delivered, internal verifier + risk-reviewer gave full E3 coverage.
