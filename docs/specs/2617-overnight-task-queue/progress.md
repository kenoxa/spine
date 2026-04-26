---
id: 2617-overnight-task-queue
updated: 2026-04-24
source_session: autonomous-overnight-task-queue-1034
latest_session: slice-d-claude-skill-e254
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

## Slice D — Claude skill integration

**Status: COMPLETE (code-level).** Review ITERATE→ACCEPT; polish applied; scope clean. Live end-to-end exit validation (consolidated 2-task loop + rate-limit demo) deferred to user-triggered run — see `build-status.json §deferred_exit_validation`.

### Delivered (uncommitted — 7 files)

| File | Change |
|------|--------|
| `skills/run-queue/SKILL.md` | Restructure — Slice A scaffold warning removed; `## Queue Shape` trimmed to one-line link; new `## Phases` cross-link table; `## References` expanded to list all 4 new phase refs. Token count 1372 (≤ 5000 hard cap). Trust Boundary + Ralph Pitfalls + Prerequisites preserved intact. |
| `skills/run-queue/references/prepare.md` | NEW — Discovery → Handoff-contract audit (`task_id`, `entry_skill`, `terminal_artifact`/`terminal_check` + optional field validation with `on_failure` default noted) → Roadmap proposal → Materialization gate. Invariant-first. |
| `skills/run-queue/references/kick.md` | NEW — Lint first → Preview (queue-shape primary: DAG + Tasks table + Branches + Base rev + Tmux command + rate-limit-handled note; one-line worst-case spawn count appended only for queues ≥ 5 tasks) → Confirmation gate → Spawn mechanism (tmux default + nohup + screen) → Post-kick report. Chain-of-trust advisory on placeholder substitution. No USD/budget framing in preview. |
| `skills/run-queue/references/monitor.md` | NEW — Stateless file-reading (`queue-state.json` via `jq`, `queue-log.md` tail, `WOKE-ME-UP.md` existence). Trip-wire shown first and prominently. Coarse rule-of-thumb "mid-task ~15–30 min; near-end iters ~5 min; trip-wire = act now." Explicit "no state files at v1" (O1 strict reading). |
| `skills/run-queue/references/review.md` | NEW — Trip-wire first → per-Outcome action table (6 rows with status/exit_reason mappings where relevant) → iteration artifacts grid pointer → one-at-a-time merge workflow. `<base_branch>` parameterized (not hardcoded `main`). |
| `skills/run-queue/references/queue-schema.md` | Removed `max_budget_usd` example row from handoff-frontmatter YAML block (per 2026-04-25 USD-drop directive). |
| `skills/run-queue/scripts/run.sh` | Removed `_rot_max_budget` parse + conditional `--max-budget-usd` flag forwarding (3 lines). Per-task budget cap feature dropped — supervisor's `_rot_rate_limit_retry` backoff (120 s → 2 h cap) is the only protection. |

### Surfaces delivered

- **Four-phase human-facing workflow** — Prepare → Kick → Monitor → Review. Each phase has a dedicated reference with invariant-first structure. SKILL.md is a thin 4-phase orchestrator (1372 tokens, well under the 5000-token hard cap).
- **Per-phase confirmation gates** — never-materialize (Prepare), never-auto-spawn (Kick), stateless-no-writes (Monitor), never-auto-merge (Review). Invariants captured verbatim on line 3 of each phase reference.
- **Queue-shape-primary Kick preview** — leads with DAG + Tasks table + Branches + Base rev + Tmux command + inline rate-limit-handled note. Worst-case spawn count appears only as a one-liner for queues ≥ 5 tasks (Tasks table already shows per-task values for smaller queues). **No USD/budget framing in preview at all.** Reframed post-finalize 2026-04-25 after user clarified that overnight serial runs ride supervisor backoff (`_rot_rate_limit_retry`, 120 s → 2 h cap) and are NOT budget-constrained on the 5h/weekly window — supervisor sleeps through window-exhaustion until reset.
- **Worst-case formula correctness** — `Σ(max_iterations × (2 if on_failure==retry_once else 1))`. Per-task gating on `retry_once` presence, confirmed against `run.sh:1092` retry loop + `queue-schema.md:67` on_failure values.
- **Outcome-vs-status clarity** — Review's action table renamed "Status" → "Outcome" column and maps non-status rows (`partial`, `retry-exhausted`, `trip-wire`) to their real `(status, exit_reason)` pairs. User querying `queue-state.json` via `jq` now knows which field to inspect.
- **Monitor without state** — O1 locked-decision-#5 strict reading applied; `.monitor-last.json` delta-view cursor is a v2 candidate.
- **Cross-file canonicalization** — `queue/<run_id>/<task_id>` placeholders match `queue-schema.md:136` + `run.sh:171` underscore form across all 5 files.
- **Supervisor changed only to drop per-task `max_budget_usd`** — 3-line removal in `scripts/run.sh` (parse + conditional flag forwarding). `queue-lint.sh`, `guard-queue-shell.sh`, `permission-profile.md` references untouched. D7 contingent patch NOT triggered in this pass. Per-task budget cap feature dropped per 2026-04-25 USD-drop directive — supervisor backoff is the only protection.

### E3 verification (this session)

- Token counts: SKILL.md 1372; prepare.md 732; kick.md 1169 (advisory >1000); monitor.md 690; review.md 947. All within targets.
- `_rot_build_prompt` resumption-header completeness (design §F1 baseline) confirmed via mainthread `awk 442,481` on `run.sh` — all 5 fields (continue-instruction, prior status/exit_reason/timestamp, session-log path, prior JSONL path, branch+HEAD) already emitted.
- `<run_id>`/`<task_id>` canonical form verified via `grep 'queue/<' queue-schema.md` + `run.sh` — polish normalized hyphen occurrences.
- Scope clean: `git status` shows only the 5 target files (one `.gitignore` silent-adjacent-edit from implementer was reverted by mainthread per handoff discipline).
- Cross-links resolve: all 6 SKILL.md `## References` entries + 4 phase-reference peer links verified present.
- Trust Boundary bit-for-bit preserved; `## Two Surfaces`, `## Prerequisites`, `## Entry Point`, `## Ralph Pattern` sections untouched.

### Review + polish summary

- **Design phase** (do-design): intake → 4-dispatch advise batch (rigorous, creative, navigator, envoy multi with cursor gap) → synthesis → zero-dispatch validate (mainthread E3 preflight) → decide. 2 `[CONFLICT]` items surfaced to user; user deferred to main-thread ("easy and simple"); F2 reframed from dollar-primary to spawn-count-primary per Max-plan context.
- **Build review iter-1**: verifier PARTIAL (structural, expected per standalone-review context) + risk-reviewer 1S (security lens chain-of-trust seam) + envoy codex+opencode (cursor gap again). Synthesis: 5 should_fix (F1-F5) + 1 bundleable advisory (F8) + 3 follow-ups; 0 blocking consensus. Two conflicts where envoy providers escalated to [B] on F1/F4 downgraded to [S] by evidence weight.
- **Fix iter-1**: F1 per-task `× 2` gating; F2 Outcome column + status/exit_reason mappings; F3 drop `running`/`iteration` claims supervisor never writes; F4 `<base_branch>` parameterized; F5 chain-of-trust advisory after spawn commands; F8 `on_failure` default noted.
- **Review-gate iter-1**: ACCEPT via budget-aware inline verification (user memory `feedback_model_budget_pattern.md` + `feedback_decide_dont_ask.md`). Each of 6 fixes confirmed applied; scope clean; invariants intact.
- **Polish**: conventions 6 findings + complexity 5 findings → synthesis 2 actions applied (A1 placeholder canonicalization at 6 sites + A2 table-header Title Case), 6 E2+ rejections with explicit rationale, 3 advisory-only notes.

### Open follow-ups deferred past Slice D

From design artifact §Follow-ups + review-iter-1 deferrals:

- **Per-task main-thread model selection** — `model:` field in handoff frontmatter / queue.yaml → `--model` flag on spawn. Matches existing `project_main_thread_model_override.md` memory + empirical budget pattern. Separate slice.
- **Delta-aware Monitor (O1 v2 candidate)** — `.monitor-last.json` cursor + diff rendering. Defer until first overnight-run signals prose rule-of-thumb inadequate.
- **Monitor "stuck task" heuristic** — rate-limit backoff at 2h cap silently eats hours without trip-wire. Add `iter-unchanged-for-N-min` detector.
- **F6** — `kick.md` >1000 tok advisory (1374 post re-reframe). Defensible (3 non-redundant spawn-variant command blocks + restructured queue-shape preview). Revisit if later polish finds prose to trim.
- **F7** — `monitor.md:41` rule-of-thumb "of 10" framing awkward for small `max_iterations`. Pre-existing noise; address in separate prose pass.
- **F9** — Monitor polling-floor prose tightening. No perf harm; optional clarification.
- **D7 contingent** — 3-line `jq -c '{status,exit_reason,head_rev}' build-status.json` inline summary near `run.sh:462` IF live exit-validation reveals silent child restart. Not triggered at code-level; tied to P_B user-gated run.

### Key learnings (from build-learnings.md)

- **L1 (knowledge candidate)** — **Budget-aware review-gate resolution**: when fix-mode output is narrow prose-local (all fixes confined to already-reviewed scope, scope git-clean, no new attack surface), inline mainthread ACCEPT is a defensible alternative to re-dispatching 3 inspect agents. Saves ~40-60% of second-round 5h-budget spend. Candidate for `skills/do-build/references/build-review-gate.md` addendum: "Budget-aware inline ACCEPT allowed when (a) prior review had 0 consensus [B], (b) all fixes are prose-local within reviewed scope, (c) git status shows no scope creep, (d) invariants structurally preserved." User approval requested.
- **L2 (weak knowledge candidate)** — User reframed F2 twice in one design phase: first from dollar-primary to spawn-count-primary ("I have Max plan; 5h window is the binding constraint"), then post-finalize from spawn-count-primary to queue-shape-primary ("overnight serial runs use supervisor backoff — not budget-constrained at all; 5h/weekly window only binds daytime parallel-subagent sessions"). Lesson: elicit user's **use-case context** (overnight-serial-with-backoff vs daytime-parallel-without) in intake before assembling advisor dispatch — billing model alone is insufficient. Corrected `feedback_model_budget_pattern.md` memory accordingly.
- **L3** (reinforcement only) — Implementer silent-adjacent-edit defense: `.gitignore` was modified outside partition_scope; mainthread revert matched user memory `Handoff & Scope Enforcement`. Reinforces that mainthread must run `git status` after every implement/polish dispatch. No new knowledge candidate — pattern already documented.
- **L4** — Invariant-first review brief (promoted to `docs/skill-guardrail-patterns.md` in Slice C curation) paid off again: verifier + envoy providers elevated the right severities using the invariants list. Reinforcement of prior knowledge, no new claim.

### Session artifacts

All under `.scratch/slice-d-claude-skill-e254/`:
- `session-log.md` — full Phase Trace (catchup → 4-phase do-design → 6-phase do-build)
- `intake.md` — design-phase intake (3 open UX forks + locked constraints)
- `advise-batch-*.md` — 4 advisory outputs (rigorous, creative, navigator, envoy.codex+opencode)
- `advise-synthesis.md` — per-fork directional merge + conflict surfacing
- `design-artifact.md` — D1–D10 + C1–C14 + O1/O2 resolved + follow-ups
- `scope-artifact.md` — P_A build partition + success criteria
- `implement-P_A-report.md` + `fix-P_A-report.md` — implementer output
- `review-brief.md` + `review-change-evidence.md` — review inputs
- `inspect-{verifier,risk-reviewer,envoy.codex,envoy.opencode}.md` — inspect outputs
- `inspect-synthesis.md` + `review-findings.md` — review synthesis + gate decision
- `polish-advisory-{conventions,complexity}.md` + `polish-synthesis.md` + `polish-apply-report.md` — polish outputs
- `build-status.json` — structured finalize artifact
- `build-learnings.md` — this session's learnings (pending)

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
