---
id: 2617-overnight-task-queue
updated: 2026-04-24
source_session: autonomous-overnight-task-queue-1034
latest_session: slice-b-dag-executor-6f6a
---

# Progress — overnight-task-queue

## Slice A — Foundation

**Status: COMPLETE.** Code, review, polish, live integration test, trip-wire test, `build-status.json` round-trip all landed and verified.

### Delivered (17 commits)

**Original Slice A code-complete (7 commits; prior session)**

| Partition | Files | Commit |
|-----------|-------|--------|
| A1 — build-status.json contract | `skills/do-build/references/build-finalize.md`, `skills/do-build/references/build-status-schema.md` | `bd804bc` |
| A2 — skill skeleton + schema docs | `skills/run-queue/SKILL.md`, `skills/run-queue/references/queue-schema.md`, `skills/run-queue/references/permission-profile.md`, `docs/skills-reference.md` | `d31570b` |
| A3 — supervisor core | `skills/run-queue/scripts/run.sh`, `skills/run-queue/scripts/queue-lint.sh` | `3028e7e` + `7b454a9` (design-revision #1: inherit global settings) |
| A4 — skill-bundled hook + overlay | `skills/run-queue/scripts/guard-queue-shell.sh`, `skills/run-queue/settings-overlay.tmpl.json` | `dc5dcac` |
| A5 — SPINE.md contract | `SPINE.md` | `c07aafc` |
| A6 — progress.md | `docs/specs/2617-overnight-task-queue/progress.md` | `7d17a88` |

**Remediation via do-build review-iterate-polish-finalize (10 commits; this session)**

Triggered by fresh review at handoff re-entry: 5 blocking + 5 should_fix findings at the trust boundary (hook bypasses via `..` traversal, substring misses, unsanitized `sh -c`, missing preflight). Three review iterations produced 8 fix commits; polish phase produced 2 more.

| Iteration | Commit | Scope |
|-----------|--------|-------|
| iter-1 | `abab954` | docs: correct stale hook path + trust-model sentence (S3) |
| iter-1 | `30aab27` | close hook bypasses — tokenized git scan + canonical paths (B1+B2+B3+F4) |
| iter-1 | `84a042b` | lint rejects terminal_check metachars + invalid run_id (B4+S1) |
| iter-1 | `32017af` | supervisor preflight + graceful signal cleanup (B5+S2+S4+S6) |
| iter-3 | `dfe6c70` | revert substring anchor; close shell-wrapper bypasses |
| iter-3 | `274f51b` | add `pushInsteadOf` belt + terminal-prompt hardening (defense-in-depth) |
| iter-3 | `6c68565` | reorder run_id case patterns — diagnostic precision (S1 follow-up) |
| iter-3 | `587f9c9` | signal handler `set +e` + trip-wire task_id reset (B3+F11) |
| polish | `7779136` | hook hygiene — clean deny slugs, cached profile, YAGNI removal |
| polish | `72ca63c` | supervisor readability + atomic `_write_report` + `_run_one_task` extraction |

### Trust-boundary design evolution

- **Initial design** (pre-remediation): PreToolUse hook with substring-match deny patterns = primary gate.
- **After iter-1**: tokenizer added for option-bearing forms (`git --git-dir=X push`).
- **After iter-2 review**: discovered 2 orthogonal bypass classes (shell-grouping + program-token obfuscation). Static pattern-matching against pre-parse shell source has inherent limits.
- **Iter-3 resolution**: revert substring to unbounded + **layered defense**. Subshell-scoped env belt (`GIT_CONFIG_COUNT=2` + `url.disabled:///.pushInsteadOf` for HTTPS and `git@`) neutralizes `git push` at the git-protocol layer regardless of hook bypass. Both layers verified E3.
- **Residual**: fully-obfuscated program tokens (`"git" push`, `$(which git) push`) bypass the hook but hit the git-level belt. Documented in-source at `guard-queue-shell.sh:127-141`.

### E3 verification (live)

- **3-task integration test** (`.scratch/queue-demo-legit/`, 2026-04-24T14:16): supervisor → lint → overlay render → 3× child spawn → per-task terminal-check pass → report. 52 seconds. No trip-wire. All 3 branches created + caller restored to `main`.
- **Trip-wire test** (`.scratch/queue-demo-tripwire/`, 2026-04-24T14:18): child emits `git push origin main` → hook denies (`git-push-blocked`) → `WOKE-ME-UP.md` written → supervisor halts rc=3 → dependent task never starts → report flags trip-wire. 23 seconds.
- **`build-status.json` contract**: first real-world emission via this session's finalize. Schema round-trip validated at `.scratch/autonomous-overnight-task-queue-1034/build-status.json`.

### Preflights (E3, from original session — still valid)

Documented in `.scratch/autonomous-overnight-task-queue-1034/preflight-report.md`:

- **#1 FAIL** — `--disallowed-tools 'Bash(git push*)'` does not reliably block `git push origin main`. Elevated: hook is **primary** trust gate; flag covers tool-category only.
- **#2 PASS** — PreToolUse hook fires in `claude -p --print`; `permissionDecision: deny` blocks the tool call.
- **#3 PASS** — Hook fires for subagent-dispatched Bash calls; envelope carries `agent_id`/`agent_type` for attribution.

### Notes carried forward

- **`yq` IS in `install.sh`** (line 551). The prior progress.md flagged this as missing — corrected.
- **`coreutils` is in `install.sh`** (line 544). Required for `grealpath` (B1/B3 canonicalization) and `gstdbuf` (B5 preflight) on macOS. Consider surfacing in `skills/run-queue/SKILL.md` prerequisites per learning L6.

## Slice B — DAG executor

**Status: COMPLETE.** Code, review (2 iterations), polish (1 iteration), live 5-task integration test, `build-status.json` round-trip all landed and verified.

### Delivered (2 commits)

| Commit | Scope |
|--------|-------|
| `29c65fb` | `feat(run-queue)`: DAG executor + failure propagation + merge-based branching — run.sh (+478/-75) + queue-lint.sh (+3) |
| `60e762b` | `docs(run-queue)`: Slice B schema refresh + coreutils prereq — queue-schema.md (+55/-6) + SKILL.md (+6/-1) |

### Surfaces delivered

- **Topological traversal** via `tsort` (self-edges for roots + real edges for dependents). Belt-and-suspenders cycle detection (BSD-safe stderr-grep pattern mirrored from lint).
- **`_check_parent_states` two-pass**: collects all parent states, then applies explicit precedence `pending_retry_wait > block > skip > run`. Populates `_cps_parent_branches` from complete parents regardless of verdict. CC ≤ 8 via `_resolve_blocked_parent_verdict` helper extraction.
- **`on_failure` enforcement**:
  - `stop` (default) cascades `blocked/transitive-block` to direct dependents; grandchildren cascade per their own `on_failure`.
  - `skip` cascades `skipped/dependency-failed-skip`.
  - `retry_once` defers retry lazily until first dependent; 30s backoff only when no real siblings ran since first fail.
- **`_do_retry` + `_flush_pending_retries` + `_finalize_stale_pending_retries`**: happy-path flush + unconditional pre-report sweep on ALL exit paths (main-loop break, trip-wire, unexpected rc, SIGINT/SIGTERM).
- **Merge-based branch derivation**: `git merge --no-ff` of all `depends_on` parent branches into child branch. Conflicts abort cleanly, mark `blocked/dep-merge-conflict` (retry_once excludes this class — deterministic failure).
- **`attempts` counter per task** in `queue-state.json`. Per-iteration JSONL at `${_attempts}.jsonl`. Report-surfacing deferred to later slice per scope.
- **Exit-reason preservation** in retry path: `_do_retry` preserves `dep-merge-conflict` / `signal-*` / `trip-wire` and only rewrites to `retry-exhausted` for runtime/terminal-check classes.
- **Trust boundary unchanged**: PreToolUse hook + `GIT_CONFIG` `pushInsteadOf` belt from Slice A untouched. Trip-wire halts queue regardless of any `on_failure` policy.

### Review + polish summary

- **Review iter-1**: verifier PARTIAL + inspector 2B/3S/4F + envoy codex 2B/1S (E3) + envoy opencode 1B/4S/2F (cursor gap) → synthesis **3 blocking + 8 should-fix + 8 follow-up + 1 conflict**. Codex envoy caught `_id` global-clobber defect (B1) via E3 temp-repo repro — internal probes missed. Conflict resolved to should-fix (skip-cascade is doc-precision, code is correct).
- **Fix iter-1**: 11 findings applied in single dispatch.
- **Review iter-2**: targeted verifier + inspector. Verifier caught B2-partial (signal path `pending_retry` leak — flush gated on rc==0). Inspector 0B/1S/3F (dep-merge-conflict doc gap, 3 latent follow-ups).
- **Fix iter-2**: B2-partial + S1 doc + F2 bundle applied.
- **Review iter-3**: targeted verifier PASS. All fixes landed, no regressions.
- **Polish**: conventions 5S/2F + complexity 3S/3F → 6 actions applied (dead var removal, prefix hygiene, doc corrections, CC-reduction extraction), 7 deferrals with rationale (Slice C seam protection).

### E3 verification (live)

**Consolidated 5-task DAG integration test** (`.scratch/queue-demo-b/`, 2026-04-24T16:06-16:08):
- Queue: A (retry_once) → B; C (stop/fail) → D; E (independent).
- **Total: 2m43s, 5 spawns (D saved via transitive-block cascade).**
- Report confirms:
  - A: complete, attempts=2 (retry succeeded on sentinel pattern), 2 JSONL iterations captured.
  - B: complete, merged queue/demo-b/A branch.
  - C: blocked/terminal-check-fail, attempts=1.
  - D: blocked/**transitive-block**, branch=null, attempts=0 — **never spawned, scratch dir never created**.
  - E: complete, attempts=1 (independent root).
- Log shows retry-backoff fired with "no siblings ran since first attempt" — S2 fix validated (synthetic cascade marks don't count as sibling progress).
- `pending_retry` correctly resolved to `complete` — no leak to final report.

All 10 Slice B EARS success criteria and the design-artifact §Slice B exit-validation scenarios hit with E3 evidence.

### Key learnings

Captured in `.scratch/slice-b-dag-executor-6f6a/build-learnings.md`:

- **L1**: Multi-perspective review yields defects internal probes miss (codex envoy found B1 via E3 repro; material validation of `docs/multi-model-council-sizing.md`).
- **L2** (knowledge candidate): POSIX sh function-parameter prefix discipline — `_run_one_task` slip showed that every multi-step helper must use a unique scratch-var prefix. **User approval requested** for promoting to sh-craft convention.
- **L4** (weak candidate): Transient-state invariants require enumerating ALL exit paths — happy-path-only enforcement misses signal/abnormal-rc leaks.
- **L6** (weak candidate): Consolidated integration tests cover more state-machine surface at similar cost vs separate narrow tests.

### Open items deferred to Slice C (not blockers)

From polish deferrals + review follow-ups, all tracked:

- **Complexity S2**: `_run_one_task` 146 lines — natural split in Slice C when loop-orchestration work lands (don't pre-extract before the third responsibility materializes).
- **Complexity S3**: `pending_retry_wait` main-loop arm → extract `_flush_pending_retry_parent` — natural composition with `_do_retry`/`_flush_pending_retries` after Slice C rate-limit work.
- **F1 (verifier)**: `attempts` increments before merge-attempt, so persists as 1 on dep-merge-conflict despite no spawn — consider moving to post-merge-success or documenting "setup attempts including conflict aborts."
- **F3 (verifier)**: `task_id` whitespace not validated by lint — pre-existing, amplified by Slice B's `_cps_parent_branches` space-splitting.
- **F6 (inspector)**: `_get_on_failure` re-parses frontmatter per call — cache candidate when Slice C shared-helper extraction lands.
- **F7 (inspector)**: Now mooted by consolidated 5-task test (exercises `pending_retry_wait` mid-loop path that 1-task retry demo would miss).
- **S5 (Slice A)**: pipefail for timeout status — polish candidate if touched.
- **Inspector B4 (Slice A)**: trap-on-EXIT for `_atomic_write` abort orphan — deferred per Slice B scope.
- **GNU tool detection 3rd-use extraction** — Slice C `_rate_limit.sh` is the natural site.
- **`_qlog` / `_qlog_line` naming split** — Slice C.

## Slice C — Intra-task loop + rate-limit backoff (not started)

See `design-artifact.md §Slice C`. Third-use of `is_fast_failure()` extraction — confirmed second use in `_GNU_realpath`/`_stdbuf` detection patterns (iter-1 of this session). Slice C will make it the third site and justify extraction to `skills/run-queue/scripts/_rate_limit.sh` per SPINE.md third-use rule.

## Slice D — Claude skill integration (not started)

Prepare / Kick / Monitor / Review phases. User confirmed mid-Slice-A that strict slice boundaries are fine — Prepare phase stays in Slice D.

## Open items deferred to future slices

From review/polish synthesis, iter-2/iter-3 findings deferred past Slice A:

- **S5 (pipefail for timeout status)** — polish candidate; needs POSIX-portable `pipefail` solution.
- **Inspector B4 (main-path atomic_write abort orphans child)** — needs trap-on-EXIT; Slice B or C.
- **TOCTOU on path canonicalization** (F-level; inherent hook limitation) — acknowledged.
- **GNU tool detection 3rd-use extraction** — Slice C natural site.
- **`_qlog` / `_qlog_line` naming split** — resolve at Slice C shared-helper extraction.
- **`_rc` idiom rewrite** — low signal; polish when touched.
- **`commit_ceiling` schema field enforcement** — Slice B+.

Learnings proposed for project knowledge:
- L1 (layered trust boundaries) + L2 (subshell env-scoped git config) → candidate new doc `docs/layered-trust-boundary-hooks.md` (or addendum to `docs/skill-guardrail-patterns.md`). **User approval required.**
- L6 (`coreutils` prerequisite) → candidate 1-line addition to `skills/run-queue/SKILL.md`. **User approval required.**

## References

- Design: [`.scratch/autonomous-overnight-task-queue-1034/design-artifact.md`](../../../.scratch/autonomous-overnight-task-queue-1034/design-artifact.md)
- Frame: [`.scratch/autonomous-overnight-task-queue-1034/frame-artifact.md`](../../../.scratch/autonomous-overnight-task-queue-1034/frame-artifact.md)
- Preflight E3 report: [`.scratch/autonomous-overnight-task-queue-1034/preflight-report.md`](../../../.scratch/autonomous-overnight-task-queue-1034/preflight-report.md)
- Review synthesis (iter-1): [`.scratch/autonomous-overnight-task-queue-1034/review-synthesis.md`](../../../.scratch/autonomous-overnight-task-queue-1034/review-synthesis.md)
- Iter-3 verification: [`.scratch/autonomous-overnight-task-queue-1034/review-verifier-iter3.md`](../../../.scratch/autonomous-overnight-task-queue-1034/review-verifier-iter3.md)
- Polish synthesis: [`.scratch/autonomous-overnight-task-queue-1034/polish-synthesis.md`](../../../.scratch/autonomous-overnight-task-queue-1034/polish-synthesis.md)
- Build status: [`.scratch/autonomous-overnight-task-queue-1034/build-status.json`](../../../.scratch/autonomous-overnight-task-queue-1034/build-status.json)
- Build learnings: [`.scratch/autonomous-overnight-task-queue-1034/build-learnings.md`](../../../.scratch/autonomous-overnight-task-queue-1034/build-learnings.md)
- Session log: [`.scratch/autonomous-overnight-task-queue-1034/session-log.md`](../../../.scratch/autonomous-overnight-task-queue-1034/session-log.md)
- Integration test evidence: `.scratch/queue-demo-legit/queue-report.md`, `.scratch/queue-demo-tripwire/queue-report.md`, `WOKE-ME-UP.md`
