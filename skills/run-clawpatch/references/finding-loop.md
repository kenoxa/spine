# Finding Loop

Review the in-scope surface, then work findings one at a time: classify → act → **revalidate before the next finding**. Act only on real, medium-or-higher risk: correctness, security, data-loss, concurrency, API, build.

## Review

- **Scoped** (a ref from scope resolution): for each affected manual feature, `clawpatch review --feature <id> --since <ref> --jobs <n>`.
- **Unscoped** (`--all-open`): bounded `clawpatch review --jobs <n> --limit <n>` over pending features.
- Pin `--jobs` (default 3) for bounded local batches — omitting it uses ~half the CPU cores. Add `--rate-limit <n>` (or `CLAWPATCH_RPM=<n>`) under provider budget/quota pressure.
- `clawpatch status` shows the open-finding count and dirty flag; `clawpatch report` writes a report under `.clawpatch/reports/`.
- Recover stale locks from a crashed run with `clawpatch clean-locks` (never hand-delete lock files).

## Per-finding loop

```sh
clawpatch next                    # select the next open finding
clawpatch show --finding <id>     # read the full finding
```

Classify into exactly one bucket:

| Bucket | Test | Action |
|---|---|---|
| **real + narrow** | genuine medium+ risk, a contained fix | fix → revalidate (below) |
| **weak / covered** | speculative, low-value, or already covered by tests | `clawpatch triage --finding <id> --status false-positive --note "<evidence>"` |
| **real + broad/risky** | genuine but wide blast radius or architectural | leave open with a recorded reason — do not fix unsupervised |

## Fix → revalidate (the guardrail)

```sh
clawpatch fix --finding <id>          # local edits only; runs feature-specific validation, rolls back on failure
clawpatch revalidate --finding <id>   # MUST go green before the next finding
```

- `clawpatch fix` (or a narrow hand-applied fix) makes **local edits only** — it does not commit, push, open PRs, or land. A failed validation rolls the patch back.
- **No green `revalidate` run means the finding is not fixed.** Record the run id and exit code for each revalidation (E3 evidence).
- Commit each verified fix group separately on the worktree branch when practical (see `worktree-session.md`).
- Do **not** use `clawpatch open-pr` unless the caller explicitly asked for a PR workflow.

## Stop rules inside the loop

- **5 consecutive revalidation failures → halt** (emit the final report, stop).
- **Unclear single failed revalidation** → leave the fix in place, mark the finding needs-attention with a reason, and continue to the next finding.
- A `clawpatch fix` that keeps rolling back is a real+broad signal — stop fixing it, leave it open with a reason.

## Anti-Patterns

- Advancing to the next finding before the current fix revalidates green.
- Fixing real+broad/risky findings unsupervised instead of leaving them open with a reason.
- Triaging a finding false-positive without an evidence note.
- Bundling unrelated fixes into one commit, or fixing across many subsystems at once.
- Omitting the run id / exit code from revalidation evidence.
- Using `open-pr` or committing on `main`.
