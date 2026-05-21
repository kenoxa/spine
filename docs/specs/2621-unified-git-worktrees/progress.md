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

### Slice 3 follow-up debt (tracked — does not block)

- **F1** — run-merge's `merge-brief` `operation` field is newly required by the general-resolver generalization; no migration note for pre-existing brief callers.
- **F2** — run-merge merge-verification wording ("byte-identical") stricter than intended.
- **F3** — run-merge rebase-loop empty-commit detection under-specified.
- **F4** — no bats probe for the path-form argument (`land .` / `land "$repo/"`).
- **F6** — `merge-brief` `repo_path` default documented in prose only.
- **F-r3-1** — `make_repo` pins only `rebase.autostash`; other rebase/merge-affecting global git config (`rebase.backend`, `merge.conflictStyle`) is still inherited. Latent — no current test asserts on conflict-marker content or rebase backend.
- **R1** — `cmd_land` cyclomatic complexity ~13 vs the ≤8 bar; pre-flight extraction warranted only when a third subcommand is added (third-use rule).
- **R2** — `cmd_sync`/`cmd_land` share a 12-line name-resolution + branch-detection block (2 uses); extract on the next subcommand addition.
- **R3 / R4** — `worktree.bats` `wt_dir` extraction pipeline and guard block now at 12 uses each (escalation of Slice 2 [F2]/[F3]); a 12-test refactor, out of polish scope.
- **N1** — `worktree.bats` SF6 section uses alphabetic sub-labels (`SF6a/b/c`) instead of sequential numbering; cosmetic.
- **`merge-brief-schema.md` token budget** — at 1448 tokens it exceeds the 250–800 reference-file target and the >1000 flag; growth is predominantly from the upstream run-merge general-resolver generalization. Candidate: trim or split the schema reference.

## Notes

- OpenCode parity descoped at the design gate — later verification, not a redesign.
- `inject-agents-md.sh` walk-up has a separate git-native rewrite (`git rev-parse`) tracked as a follow-up — out of scope for Slice 1, which applies the marker fix only.
- Envoy OpenCode lane (kimi-k2.6, deepseek-v4-pro, glm-5.1) timed out across Slice 2 and Slice 3 review iterations — recurring infrastructure flakiness; Codex + Cursor lanes delivered, internal verifier + risk-reviewer gave full E3 coverage.
