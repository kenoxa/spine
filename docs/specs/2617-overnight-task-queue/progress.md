---
id: 2617-overnight-task-queue
updated: 2026-04-24
source_session: autonomous-overnight-task-queue-1034
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

## Slice B — DAG executor (not started)

See `design-artifact.md §Slice B`. Entry gate: Slice A complete ✓. Ready to start.

Additional context for Slice B kickoff:
- `_current_task_id` pattern already in place for parallel-safe state management.
- DAG resolution via `tsort` already scaffolded in `queue-lint.sh:186-198`.
- Slice-B-specific handoff frontmatter fields (`depends_on`, `on_failure`) already validated by lint.

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
