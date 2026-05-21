# Merge Brief + Verdict Sidecar

## Merge Brief

Markdown with YAML frontmatter. Caller context is embedded; `/run-merge` queries
git only in `repo_path`.

Migration: `operation` is now required. Old merge-only callers must add
`operation: merge`; `/run-merge` must not infer it silently.

`repo_path` default: if omitted, `/run-merge` sets `repo_path="."`; every git
command runs as `git -C "$repo_path" ...`.

### Examples

Merge:

```yaml
---
operation: merge
merge_id: fix-login-bug
repo_path: .
source_branch: feature/fix-login-bug
target_branch: main
base_ref: abc1234
verdict_path: /abs/.scratch/<session>/<merge_id>/merge-verdict.json
---
```

Rebase:

```yaml
---
operation: rebase
merge_id: worktree-sync-feat
repo_path: /abs/.worktrees/feat-a1b2
source_branch: feat
target_branch: main
verdict_path: /abs/.worktrees/feat-a1b2/.scratch/worktree-merge-<name>/merge-verdict.json
---
```

| Field | Required | Meaning |
|---|---|---|
| `operation` | yes | `merge` or `rebase` |
| `merge_id` | yes | Caller attempt id |
| `repo_path` | no | Conflict repo/worktree; default `.` |
| `verdict_path` | yes | Absolute verdict path in a session/attempt scratch dir |
| `source_branch` | merge required; rebase advisory | Branch merged/replayed |
| `target_branch` | merge required; rebase advisory | Target/onto branch |
| `base_ref` | merge required; rebase omitted | Merge ancestor SHA |

### Body

For `merge`, include per-conflict context, current content, and `(A, B, O)`:
`O=base_ref:file`, `A=target_branch:file`, `B=source_branch:file`.

For `rebase`, body context is freeform. Conflict sets change per round; stages
are `:1` = `O` base, `:2` = `A` ours/upstream, `:3` = `B` theirs/replayed
worktree commit. Worktree task intent lives in `:3`.

## Verdict Sidecar

Atomically write temp then `mv` to `verdict_path`. Always write a verdict.

```json
{ "schema_version": "1", "verdict": "resolved", "files_resolved": ["src/auth/session.ts"] }
```

| Field | Semantics |
|---|---|
| `schema_version` | `"1"`; reject unknown versions |
| `verdict` | `"resolved"`, `"failed"`, or `"aborted"` |
| `files_resolved` | Paths staged by `/run-merge`; non-empty on `resolved` |

`resolved` requires caller verification. `failed`, `aborted`, missing,
malformed, wrong schema, or empty `files_resolved` all fail secure.

## Invariants

- No `git push`, `git reset --hard`, or `git commit --amend`. `rebase --continue`
  and `rebase --skip` are allowed only to finish the caller-started operation.
- Verification is semantic/set-based, not byte-identical: no conflict markers,
  completed operation, and `files_resolved` membership.
- For `merge`, `files_resolved` must be within the pre-invocation conflict set.
  For `rebase`, it is the union of every round's unmerged set; round 1 is not
  enough.
