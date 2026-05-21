# Conflict Resolution Protocol

`worktree.sh sync` and `worktree.sh land` rebase the worktree branch onto
current main. When that rebase hits a conflict the script exits with
**status 3** and leaves the rebase **in progress** — conflict markers in the
files, `rebase-merge`/`rebase-apply` state present. It halts before any
destructive step and never resolves or guesses.

On exit status 3, resolve the conflict autonomously — do not surface the raw
conflict to the user.

## Protocol

**1. Locate.** Read the `worktree-path:` line the script printed on stderr —
the absolute path after it is `<wt>`. (The script emits the resolved path
directly; no name-vs-path guessing is needed.)

**2. Build a run-merge brief.** Write `merge-brief.md` to a scratch dir
(`<wt>/.scratch/worktree-merge-<name>/`, or `mktemp -d` if `.scratch` is
absent):

```yaml
---
operation: rebase
merge_id: worktree-<sync|land>-<name>
repo_path: <wt>
verdict_path: <abs scratch dir>/merge-verdict.json
source_branch: <worktree branch>
target_branch: <main branch>
---
Rebasing <worktree branch> onto <main branch>. Preserve the intent of both sides.
Conflicted commits are replayed worktree commits — reconstruct A/B/O from git stage
refs (git -C <wt> show :1:/:2:/:3:<file>).
```

Schema: `skills/run-merge/references/merge-brief-schema.md`.

**3. Resolve — invoke `/run-merge <brief-path>`.** It detects the in-progress
rebase, resolves every round, runs `git rebase --continue` to completion, and
writes the verdict.

**4. Read the verdict** at `verdict_path`: `resolved` → step 5. `failed` /
`aborted` / missing → STOP, surface to the user (conflicted files + run-merge's
verdict). Do not continue.

**5. Verify** — dispatch `@verifier` scoped to `<wt>` (run-merge's empirical
constraint: agentic resolution succeeds below 60% even for frontier models —
every resolution is provisional, the caller MUST re-verify): no conflict markers
remain; the rebase completed; the branch is based on current main; both sides'
intent survived; run the project test command if detectable — PASS/FAIL with E3
evidence.

**6. Continue:** verifier PASS → continue without interrupting the user (`land`:
re-run `sh worktree.sh land <name>`, rebase is now a no-op → merge → remove →
branch-delete; `sync`: done; report one line). verifier FAIL → STOP, surface to
the user.

## Notes

- Abandon instead of resolving: `git -C <wt> rebase --abort` restores the
  worktree branch untouched.
- Providers without subagent dispatch: invoke `/run-merge` and verify in-thread,
  same order.
- `land` is idempotent after resolution — re-invoking it once the rebase is
  clean is safe.
