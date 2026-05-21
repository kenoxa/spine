---
name: run-merge
description: >-
  Git conflict resolver for prepared merge briefs. Use when a merge, sync, or
  land operation has conflicts and the caller provides a self-contained brief.
argument-hint: "<brief-path>"
---

**Empirical constraint**: agentic conflict resolution success rate is below 60% even for frontier models (Merge-Bench). Every resolution is provisional — the caller must run its own focused review or verification after a successful resolution. Do not treat a clean merge as correct.

**Execution context**: all git commands run against `repo_path` from the brief (`git -C "$repo_path" ...`); `repo_path` defaults to CWD when omitted. Do not call `git push`, `git reset --hard`, `git commit --amend`, or write outside the repo. `git rebase --continue` and `git rebase --skip` are allowed — they complete an operation the caller started.

## Phase 1 — Load Brief

Read the brief file at the path given in the argument. The brief is a markdown file with YAML frontmatter. Load [merge-brief-schema.md](references/merge-brief-schema.md) for the full schema.

Required frontmatter fields:
- `operation` — `merge` or `rebase`
- `merge_id` — caller-scoped identifier for this attempt
- `repo_path` — (optional) absolute path to the repo or worktree; defaults to CWD
- `source_branch` — branch being merged / rebased (required for `merge`; advisory for `rebase`)
- `target_branch` — merge target / rebase-onto branch (required for `merge`; advisory for `rebase`)
- `base_ref` — common ancestor SHA (required for `merge`; omit for `rebase` — a rebase replays N commits, each with its own base)
- `verdict_path` — absolute path where `merge-verdict.json` must be written

If the brief is missing or unreadable, write `verdict: aborted` immediately and stop.

Normalize optional fields before any git command:
```sh
repo_path="${repo_path:-.}"
```

Migration note: older merge-only briefs without `operation` must be treated as invalid. Callers using the old format must add `operation: merge`; do not infer it silently.

## Phase 2 — Assess Conflicts

Verify the working tree is in a conflict state:
```sh
git -C "$repo_path" diff --name-only --diff-filter=U
```
If no unmerged files, write `verdict: aborted` (nothing to resolve) and stop.

Read the conflicted files. For `operation: merge`, the brief body contains `(A, B, O)` triples and commit messages for each conflict region — use these as primary context. For `operation: rebase`, the brief may carry no triples — reconstruct A/B/O from git stage refs per file:
```sh
git -C "$repo_path" show :1:<file>   # O — base/ancestor
git -C "$repo_path" show :2:<file>   # A — ours (upstream/onto branch, e.g. main)
git -C "$repo_path" show :3:<file>   # B — theirs (replayed worktree commit)
git -C "$repo_path" log --oneline -5 # in-progress commit context
```

Note: `git rebase` swaps the sides relative to a merge — stage 2 (`ours`) is the upstream/onto branch, stage 3 (`theirs`) is the branch's commit being replayed; for the worktree flow, the change to preserve as the task intent is `:3`.

Classify each conflict:
- **Resolvable**: clear semantic intent from A/B/O + commit messages; the correct merge can be determined
- **Ambiguous**: multiple valid resolutions exist; cannot determine correct semantic outcome with confidence
- **Structural**: conflicting changes to the same function/class signature or incompatible refactors

If any conflict is **structural** or the full set cannot be resolved with confidence, write `verdict: failed` immediately. Do not attempt partial resolution — a half-resolved conflict leaves the branch in a worse state than a clean abort.

## Phase 3 — Resolve

For each resolvable conflict file:
1. Edit the file to remove conflict markers and produce the correct merge result
2. Stage the resolved file: `git -C "$repo_path" add <file>`

Do not use `git merge --strategy` or `git checkout --ours/--theirs` as the sole resolution — these discard one side entirely and are almost never semantically correct.

## Phase 4 — Complete the Operation

Detect the in-progress operation:
```sh
rebase_merge=$(git -C "$repo_path" rev-parse --path-format=absolute --git-path rebase-merge)
rebase_apply=$(git -C "$repo_path" rev-parse --path-format=absolute --git-path rebase-apply)
merge_head=$(git -C "$repo_path" rev-parse --path-format=absolute --git-path MERGE_HEAD)
```

**If `MERGE_HEAD` file exists** (`operation: merge`):
```sh
git -C "$repo_path" commit --no-edit
```

**If `rebase-merge` or `rebase-apply` directory exists** (`operation: rebase`): loop —
1. `GIT_EDITOR=true git -C "$repo_path" rebase --continue` — reuses commit messages non-interactively.
2. If `--continue` exits non-zero, treat it as an empty replayed commit only when all of these are true: a rebase dir still exists, `git -C "$repo_path" diff --name-only --diff-filter=U` is empty, `git -C "$repo_path" diff --cached --quiet` exits 0, and `git -C "$repo_path" diff --quiet` exits 0. Then run `git -C "$repo_path" rebase --skip`. If any condition is false, write `verdict: failed`.
3. Re-check `git -C "$repo_path" diff --name-only --diff-filter=U`. Non-empty → the next replayed commit conflicted → return to Phase 2/3 for that new conflict set.
4. Repeat until neither `rebase-merge` nor `rebase-apply` directory remains. Cap at 20 rounds; if exceeded write `verdict: failed` — fail-safe against a non-terminating loop.

**Verification (both operations)**:

Check no unmerged files remain:
```sh
git -C "$repo_path" diff --name-only --diff-filter=U
```
This must return empty. If not, write `verdict: failed`.

Scan for residual conflict markers in resolved working-tree files — `grep -nE '^(<<<<<<< |>>>>>>> )'` against each `$repo_path/<file>`. Any match → write `verdict: failed`. Verification is semantic and set-based: do not require byte-identical output to either side; require no markers, a completed operation, and `files_resolved` membership rules from the schema.

Note: do **not** use `git diff HEAD^ HEAD` for rebase verification — a rebase rewrites multiple commits and `HEAD^..HEAD` covers only the last one.

## Phase 5 — Write Verdict

Write `merge-verdict.json` atomically to the `verdict_path` from the brief frontmatter. For `operation: rebase`, `files_resolved` is the **union of every round's** unmerged set — not just the first round.

```sh
# Atomic write: tmp → mv (never write directly to verdict_path)
tmp=$(mktemp "$(dirname "$verdict_path")/.merge-verdict.XXXXXX.json")
cat > "$tmp" << 'EOF'
{ ... }
EOF
mv "$tmp" "$verdict_path"
```

Schema: see [merge-brief-schema.md](references/merge-brief-schema.md) § Verdict Sidecar.

**On any unrecoverable error**: write `verdict: aborted` to `verdict_path` and exit cleanly. Never exit without writing the verdict — a missing verdict is a harder failure for the caller than an explicit `failed`.
