# merge-brief-schema.md — Merge Brief + Verdict Sidecar

## Merge Brief (`merge-brief.md`)

Written by the queue supervisor at `.scratch/<task-session>/merge-brief.md` before spawning `/run-merge`. Self-contained — supervisor context is embedded; `/run-merge` must not need to query git beyond what the brief provides.

### YAML Frontmatter

```yaml
---
task_id: fix-login-bug
branch: queue/overnight-2026-04-25-a1b2/fix-login-bug
integration_branch: queue/overnight-2026-04-25-a1b2/result
base_ref: abc1234
verdict_path: /abs/path/.scratch/queue-run-fix-login-bug/merge-verdict.json
---
```

| Field | Required | Semantics |
|---|---|---|
| `task_id` | yes | Queue task identifier |
| `branch` | yes | Task branch being merged |
| `integration_branch` | yes | Merge target (`queue/<run_id>/result`) |
| `base_ref` | yes | Common ancestor SHA |
| `verdict_path` | yes | Absolute path for `merge-verdict.json`; `/run-merge` must write here |

### Body Format

One section per conflicted file with (A, B, O) triple and commit messages. Supervisor builds each section from:

```sh
git show "${base_ref}:${file}"            # O — common ancestor
git show "${integration_branch}:${file}"  # A — ours
git show "${branch}:${file}"              # B — theirs
git log --oneline "${base_ref}..${integration_branch}" -- "${file}" | head -5
git log --oneline "${base_ref}..${branch}" -- "${file}" | head -5
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

| Verdict | Supervisor action |
|---|---|
| `resolved` | Post-verify → re-review at `depth=focused` → fast-forward integration or escalate |
| `resolved` + empty `files_resolved` | `merge-resolve-failed` fail-secure (vacuous claim) |
| `failed` | `status=blocked`, `exit_reason=merge-resolve-failed`; branch retained |
| `aborted` | Same as `failed`; indicates unrecoverable error before resolution attempt |
| missing/malformed/wrong schema | `merge-resolve-failed` fail-secure |

## Invariants

- `/run-merge` must NOT call `git push`, `git reset --hard`, or `git commit --amend`. Guard hook (`SPINE_QUEUE_STAGE=merge`) denies these.
- Supervisor enforces a 1-attempt cap — `/run-merge` spawned at most once per task.
- Timeout: `SPINE_QUEUE_MERGE_TIMEOUT` (default 1800s).
- `files_resolved` must be non-empty when `verdict=resolved` — an empty list is treated as a vacuous claim and escalates fail-secure.
- `files_resolved` must be a subset of the pre-spawn conflict set — supervisor verifies via set membership (`files_resolved ⊆ conflict_set`), not diff scope (merge commits include auto-merged files).
