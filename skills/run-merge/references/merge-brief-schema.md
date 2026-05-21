# merge-brief-schema.md — Merge Brief + Verdict Sidecar

## Merge Brief (`merge-brief.md`)

Written by the caller at `.scratch/<session>/merge-brief.md` before invoking `/run-merge`. Self-contained — caller context is embedded; `/run-merge` must not need to query git beyond what the brief provides.

### YAML Frontmatter

```yaml
---
merge_id: fix-login-bug
source_branch: feature/fix-login-bug
target_branch: main
base_ref: abc1234
verdict_path: /abs/path/.scratch/fix-login-bug/merge-verdict.json
---
```

| Field | Required | Semantics |
|---|---|---|
| `merge_id` | yes | Caller-scoped merge identifier |
| `source_branch` | yes | Branch being merged |
| `target_branch` | yes | Merge target branch |
| `base_ref` | yes | Common ancestor SHA |
| `verdict_path` | yes | Absolute path for `merge-verdict.json`; `/run-merge` must write here |

### Body Format

One section per conflicted file with (A, B, O) triple and commit messages. Caller builds each section from:

```sh
git show "${base_ref}:${file}"       # O — common ancestor
git show "${target_branch}:${file}"  # A — ours
git show "${source_branch}:${file}"  # B — theirs
git log --oneline "${base_ref}..${target_branch}" -- "${file}" | head -5
git log --oneline "${base_ref}..${source_branch}" -- "${file}" | head -5
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

- `/run-merge` must NOT call `git push`, `git reset --hard`, or `git commit --amend`.
- Caller enforces retry and timeout policy.
- `files_resolved` must be non-empty when `verdict=resolved` — an empty list is treated as a vacuous claim and escalates fail-secure.
- `files_resolved` must be a subset of the pre-invocation conflict set — callers verify via set membership (`files_resolved ⊆ conflict_set`), not diff scope (merge commits include auto-merged files).
