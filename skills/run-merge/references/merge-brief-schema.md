# merge-brief-schema.md — Merge Brief + Verdict Sidecar

## Merge Brief (`merge-brief.md`)

Written by the caller at `.scratch/<session>/merge-brief.md` before invoking `/run-merge`. Self-contained — caller context is embedded; `/run-merge` must not need to query git beyond what the brief provides.

### YAML Frontmatter

`operation: merge` example (existing callers — `repo_path` omitted → defaults to CWD):

```yaml
---
operation: merge
merge_id: fix-login-bug
source_branch: feature/fix-login-bug
target_branch: main
base_ref: abc1234
verdict_path: /abs/path/.scratch/fix-login-bug/merge-verdict.json
---
```

`operation: rebase` example (worktree conflict caller):

```yaml
---
operation: rebase
merge_id: worktree-sync-fix-login-bug
repo_path: /abs/path/.worktrees/fix-login-bug-a1b2
source_branch: fix-login-bug
target_branch: main
verdict_path: /abs/path/.worktrees/fix-login-bug-a1b2/.scratch/worktree-merge-fix-login-bug/merge-verdict.json
---
```

| Field | Required | Semantics |
|---|---|---|
| `operation` | **required** | `merge` \| `rebase` |
| `merge_id` | required | Caller-scoped identifier for this attempt |
| `repo_path` | optional | Absolute path to the repo or worktree where the conflict is in progress. `/run-merge` runs **every** git command as `git -C "$repo_path"`. Default when omitted: CWD (preserves existing queue callers) |
| `verdict_path` | required | Absolute path for `merge-verdict.json`; `/run-merge` must write here |
| `source_branch` | required for `merge`; advisory for `rebase` | Branch being merged / rebased |
| `target_branch` | required for `merge`; advisory for `rebase` | Merge target / rebase-onto branch |
| `base_ref` | required for `merge`; **omit for `rebase`** | Common ancestor SHA. A rebase replays N commits — each has its own base — so there is no single `base_ref` |

### Body Format

**`merge` operation**: one section per conflicted file with (A, B, O) triple and commit messages. Caller builds each section from:

```sh
git -C "$repo_path" show "${base_ref}:${file}"       # O — common ancestor
git -C "$repo_path" show "${target_branch}:${file}"  # A — ours
git -C "$repo_path" show "${source_branch}:${file}"  # B — theirs
git -C "$repo_path" log --oneline "${base_ref}..${target_branch}" -- "${file}" | head -5
git -C "$repo_path" log --oneline "${base_ref}..${source_branch}" -- "${file}" | head -5
```

Section template:

```markdown
## Conflict: src/auth/session.ts

### Commit Context
**Integration side (A)**: "refactor: extract session store"
**Task side (B)**: "fix: extend session TTL for active users"

### (A, B, O) Triple
**O — common ancestor**: ```<content>```
**A — integration branch (ours)**: ```<content>```
**B — task branch (theirs)**: ```<content>```

### Conflict Markers (in-tree)
```<conflicted file content>```
```

**`rebase` operation**: `(A, B, O)` triples are **optional**. The conflict set changes every rebase round and cannot be pre-enumerated by the caller. The body is freeform intent/context (what the rebase is for, branch descriptions, commit-message summaries). `/run-merge` reconstructs A/B/O per round from git stage refs (`git -C "$repo_path" show :1:<file>` = O/base, `:2:<file>` = A/ours = the upstream/onto side (e.g. `main`), `:3:<file>` = B/theirs = the worktree commit being replayed). Note: `git rebase` swaps the sides relative to a merge — stage 2 (`ours`) is the upstream/onto branch, stage 3 (`theirs`) is the branch's commit being replayed; the worktree's task intent lives in `:3`.

## Verdict Sidecar (`merge-verdict.json`)

Written atomically (`.tmp` → `mv`) by `/run-merge` to `verdict_path` from the brief. Always written — even on `failed`/`aborted`. Missing = `failed` fail-secure.

### Schema v1

```json
{ "schema_version": "1", "verdict": "resolved", "files_resolved": ["src/auth/session.ts"] }
```

| Field | Semantics |
|---|---|
| `schema_version` | `"1"`. Consumers MUST refuse unknown versions. |
| `verdict` | `"resolved"` \| `"failed"` \| `"aborted"` |
| `files_resolved` | Paths staged as part of resolution. Non-empty on `resolved`; empty on `failed`/`aborted`. |

| Verdict | Caller action |
|---|---|
| `resolved` | Post-verify → focused review or domain checks → land or escalate |
| `resolved` + empty `files_resolved` | Treat as failed fail-secure (vacuous claim) |
| `failed` | Mark merge attempt blocked; retain branch/worktree |
| `aborted` | Same as `failed`; indicates unrecoverable error before resolution attempt |
| missing/malformed/wrong schema | Treat as failed fail-secure |

## Invariants

- `/run-merge` must NOT call `git push`, `git reset --hard`, or `git commit --amend`. `git rebase --continue` and `git rebase --skip` are allowed — they complete an operation the caller started.
- Caller enforces retry and timeout policy.
- `files_resolved` must be non-empty when `verdict=resolved` — an empty list is treated as a vacuous claim and escalates fail-secure.
- `files_resolved` must be a subset of the pre-invocation conflict set. For `operation: merge`, callers verify via set membership (`files_resolved ⊆ conflict_set`). For `operation: rebase`, `files_resolved` is the union of every round's unmerged set; the caller's pre-invocation conflict set is only round 1, so membership is checked against that union across all rounds.
