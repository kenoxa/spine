---
name: run-merge
description: >-
  Git conflict resolver for run-queue.
argument-hint: "<brief-path>"
---

**Empirical constraint**: agentic conflict resolution success rate is below 60% even for frontier models (Merge-Bench). Every resolution is provisional — the queue supervisor always re-runs `/run-review` at `depth=focused` after a successful resolution. Do not treat a clean merge as correct; the re-review is the empirical gate.

**Execution context**: running inside `claude -p` as a queue child. `SPINE_QUEUE=1`, `SPINE_QUEUE_STAGE=merge`. Guard hook denies `git push`, `git reset --hard`, `git commit --amend`, and out-of-repo writes. Do not attempt those operations.

## Phase 1 — Load Brief

Read the brief file at the path given in the argument. The brief is a markdown file with YAML frontmatter. Load [merge-brief-schema.md](references/merge-brief-schema.md) for the full schema.

Required frontmatter fields:
- `task_id` — the queue task being resolved
- `integration_branch` — the branch this task was being merged into
- `base_ref` — common ancestor SHA
- `verdict_path` — absolute path where `merge-verdict.json` must be written

If the brief is missing or unreadable, write `verdict: aborted` immediately and stop.

## Phase 2 — Assess Conflicts

Verify the working tree is in a merge-conflict state:
```sh
git diff --name-only --diff-filter=U
```
If no unmerged files, write `verdict: aborted` (nothing to resolve) and stop.

Read the conflicted files. The brief body contains `(A, B, O)` triples and commit messages for each conflict region. Use these as the primary context for semantic intent — they are more reliable than heuristic pattern matching.

Classify each conflict:
- **Resolvable**: clear semantic intent from A/B/O + commit messages; the correct merge can be determined
- **Ambiguous**: multiple valid resolutions exist; cannot determine correct semantic outcome with confidence
- **Structural**: conflicting changes to the same function/class signature or incompatible refactors

If any conflict is **structural** or the full set cannot be resolved with confidence, write `verdict: failed` immediately. Do not attempt partial resolution — a half-resolved merge leaves the branch in a worse state than a clean abort.

## Phase 3 — Resolve

For each resolvable conflict file:
1. Edit the file to remove conflict markers and produce the correct merge result
2. Stage the resolved file: `git add <file>`

Do not use `git merge --strategy` or `git checkout --ours/--theirs` as the sole resolution — these discard one side entirely and are almost never semantically correct.

## Phase 4 — Complete Merge

After all files are staged:
```sh
git commit --no-edit
```

Verify the merge completed cleanly:
```sh
git diff --name-only --diff-filter=U
```
This must return empty. If not, write `verdict: failed`.

Scan for residual conflict markers in resolved files:
```sh
git diff HEAD^ HEAD -- <files_resolved> | grep -c '^+<<<<<<< '
```
If any marker remains, write `verdict: failed`.

## Phase 5 — Write Verdict

Write `merge-verdict.json` atomically to the `verdict_path` from the brief frontmatter.

```sh
# Atomic write: tmp → mv (never write directly to verdict_path)
tmp=$(mktemp "$(dirname "$verdict_path")/.merge-verdict.XXXXXX.json")
cat > "$tmp" << 'EOF'
{ ... }
EOF
mv "$tmp" "$verdict_path"
```

Schema: see [merge-brief-schema.md](references/merge-brief-schema.md) § Verdict Sidecar.

**On any unrecoverable error**: write `verdict: aborted` to `verdict_path` and exit cleanly. Never exit without writing the verdict — a missing verdict is a harder failure for the supervisor than an explicit `failed`.
