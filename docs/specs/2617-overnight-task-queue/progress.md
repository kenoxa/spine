---
id: 2617-overnight-task-queue
updated: 2026-04-24
source_session: autonomous-overnight-task-queue-1034
latest_session: slice-c-intra-task-loop-32e7
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

## Slice C — Intra-task loop + rate-limit backoff

**Status: COMPLETE (code-level).** Review (2 iterations) ACCEPT; polish applied; POSIX parse + envoy bats 45/45 regression green. Live `claude -p` integration demos (loop demo + rate-limit demo) deferred to user-triggered run — see build-status.json §deferred_exit_validation.

### Delivered (uncommitted — 6 files)

| File | Change |
|------|--------|
| `skills/use-envoy/scripts/_rate_limit.sh` | NEW — shared `is_fast_failure()` helper sourced by both use-envoy and run-queue |
| `skills/use-envoy/scripts/_common.sh` | Refactored — sources `_rate_limit.sh`; function body removed |
| `skills/use-envoy/tests/test_helper.bash` | Exports `_script_dir=$SCRIPTS_DIR`; copies `_rate_limit.sh` into fixture tmpdir (B1 fix — bats regressed 45/45→1/45 without this) |
| `skills/run-queue/scripts/run.sh` | Intra-task loop (`_rot_iterate`) + rate-limit retry (`_rot_rate_limit_retry`) + trip-wire halt helper (`_rot_halt_trip_wire`) + backoff schedule (`_rot_compute_backoff`) + resumption prompt builder (`_rot_build_prompt`); artifact-status schema gate; `backoff_cap_ms` + `SPINE_QUEUE_RL_BASE_SEC` validators; `_rot_rc=0` reset; `max-iterations-exceeded` / `invalid-terminal-status` exit reasons |
| `skills/run-queue/scripts/queue-lint.sh` | task_id whitespace rejection (F3 from Slice B) |
| `skills/run-queue/references/queue-schema.md` | New sections: Iteration artifacts (JSONL grid), Intra-task loop (decision table), Rate-limit backoff (schedule + test override); split missing-vs-invalid artifact rows; exit-reasons table additions; `backoff_cap_ms` default reconciled 1800000 → 7200000 ms |
| `skills/run-queue/SKILL.md` | Intra-task loop + rate-limit behavior bullet |

### Surfaces delivered

- **Intra-task loop** — `_rot_iterate` re-invokes `claude -p` per iteration until `build-status.json.status` is terminal (`complete` or `blocked`) or `max_iterations` (default 10) exhausts. Status decision table: complete/blocked → break; partial/in_progress/unknown → continue; missing artifact → `blocked/missing-terminal-artifact`; invalid artifact status → `blocked/invalid-terminal-status`; exhaustion → `blocked/max-iterations-exceeded`.
- **Rate-limit backoff** — on `is_fast_failure` stderr match, inner retry loop sleeps exponentially (120/240/480/960/1920 s; cap = `backoff_cap_ms`/1000, default 7200 s = 2 h) and retries the SAME iteration. Counter resets on non-rate-limit completion. Test-mode env override `SPINE_QUEUE_RL_BASE_SEC` (default 120) for integration tests.
- **Trip-wire precedence (B2)** — `WOKE-ME-UP.md` check fires immediately after every `_spawn_child` return, BEFORE rate-limit sleep, AND after rate-limit sleep (sleeps can be 2 h). Invariant #3 honored literally.
- **Artifact-status schema gate (B3)** — `_classify_terminal_status` accepts only `{complete, partial, blocked, in_progress}` from `.status`; non-enumerated values → `blocked/invalid-terminal-status` (fail-secure per SPINE.md).
- **Resumption prompt** — iter-1 uses original handoff body; iter-2+ prepends a short header referencing prior iteration's JSONL path, captured iter-end timestamp (`_rot_prev_stamp`), branch + HEAD short-sha.
- **Shared `_rate_limit.sh`** — third-use extraction (envoy + run-queue). Envoy's bats fixture updated in-scope to preserve 45/45.
- **Validators** — `backoff_cap_ms` must be ≥ 1000 positive integer; `SPINE_QUEUE_RL_BASE_SEC` must be positive integer; task_id must contain no whitespace.
- **CC reduction** — `_rot_iterate` split into 3 cohesive functions via polish extraction; 3× halt-block duplication eliminated.

### E3 verification (this session)

- `sh -n` PASS on all 4 modified shell files.
- `bats skills/use-envoy/tests/fallback.bats` → **45/45** (pre-fix: 1/45; post-fix re-run: 45/45 verified 3×).
- Verifier probes E3: `_rot_compute_backoff` schedule correct; `backoff_cap_ms=0` rejected; `SPINE_QUEUE_RL_BASE_SEC=abc` rejected; `status:foo` → `blocked/invalid-terminal-status`.
- Preflight #7 (SIGINT forwarding): PASS via stub-supervisor probe under `setsid`; no orphan processes; 30 s grace honored; SIGKILL fallback fires correctly.

### Review + polish summary

- **Iter-1 review:** verifier FAIL + inspector 0B/3S/4F + codex [S]×2 + opencode [S]×2/[F] → synthesis **3 blocking + 5 should_fix + 5 follow_up**. Verifier caught B1 (bats regression) via E3; codex's two [S] findings elevated to blocking per invariant #3 + fail-secure mandate.
- **Fix iter-1:** all 3 blocking + 4 of 5 should_fix applied; S5 (unit tests) deferred to F6 per inspector escalation clause.
- **Iter-2 review:** verifier PASS + inspector 0B/1S (doc-comment drift) → ACCEPT. 1 residual should_fix bucketed as polish candidate.
- **Polish:** conventions 4S + complexity 2S/3F → 5 actions applied (doc Reads/Writes accuracy × 2, SKILL.md terminal-status wording fix, queue-schema.md decision-table row split, `_rot_halt_trip_wire` + `_rot_rate_limit_retry` extraction). 3 polish follow-ups preserved for future slice triggers.

### Live integration demos deferred

Per handoff §5 exit validation — the two cost-gated scenarios have NOT been run this session; code is review-passed + polish-applied and ready for user-triggered demo:

- **Loop demo** — task with `terminal_check` that passes only on iteration 3 (counter ≥ 3). Expected: 3 JSONL files `1-1.jsonl` `1-2.jsonl` `1-3.jsonl`, `attempts=1`, final status `complete`.
- **Rate-limit demo** — stub task writes `rate_limited` on iter-1 stderr, succeeds on retry. Use `SPINE_QUEUE_RL_BASE_SEC=1` for a 1-second first-sleep. Expected: queue-log shows sleep + retry; iter counter does NOT advance across retries.

### Key learnings (from build-learnings.md)

- **L1** — shared-helper extractions must update test-fixture helpers (test_helper.bash) in the SAME change; not-a-knowledge-candidate but a concrete Slice C scar.
- **L2 (knowledge candidate, weak)** — invariant-first review brief lets synthesizers elevate severity correctly (codex [S] × 2 → blocking via brief invariants). User approval requested for addition to `docs/skill-guardrail-patterns.md` or `docs/research-findings.md`.
- **L4 (knowledge candidate)** — verifier running real tests caught a defect inspector + envoy missed (B1 bats regression). Validates `docs/research-findings.md` multi-perspective claim with a concrete Slice C instance. User approval requested for 1-sentence addition.
- **L6 (knowledge candidate, weak)** — usage-limit mid-dispatch: write-skeleton-early pattern in subagent prompts survives a context cut-off. Candidate tip in `docs/tips.md`. User approval requested.
- L3 (third-use rule) and L5 (defense-in-depth doc visibility) — reinforcement only, no new knowledge.

### Open follow-ups deferred past Slice C

From review + polish synthesis:

- F1: Cross-skill relative-path smoke check in `queue-lint.sh` (verifier + inspector + codex consolidated).
- F2: Doc `retry_once × max-iterations-exceeded` interaction in queue-schema.md (inspector).
- F3: `unknown` row in decision table (mostly mooted by B3 artifact-status gate; doc consistency only).
- F4: `_rot_prompt_tmp` mktemp-failure cleanup guard (verifier).
- F5: Golden-file test for resumption prompt (blocked on F6).
- F6 (was S5): Unit tests for `_rot_compute_backoff` + `_rot_build_prompt` + `_rot_iterate` (inspector; deferred pending live demos).
- Polish-F1: `_rot_build_prompt` 5-line footer duplication (2-of-2 uses; third-use threshold not met).
- Polish-F2: `_classify_terminal_status` CC at bar 8 after B3 — extract on next touch.
- Polish-F3: Positive-integer validator pattern at 3 sites; extract on fourth addition.

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
