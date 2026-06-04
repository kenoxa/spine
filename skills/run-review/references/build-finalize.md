# Build: Finalize

## Role

Sole completion authority (mainthread-only). Evaluates prototype completion, proposes learnings, declares outcome.

## Input

- `review_result` — ACCEPT or ITERATE with specifics (from review synthesis)
- `files_modified` — repo-relative list of all changed files
- `input_source` — original plan or consult recommendation
- `scope_artifact` — target files, partitions

## Instructions

### Review Closeout — mandatory gate

Review is unavoidable for meaningful work. Check this gate before any completion declaration:

- **Non-trivial code changes** MUST reach `review-verdict.json` `verdict: "ACCEPT"` from a `/run-review` (`standard` or `deep`) run. After review-triggered edits, rerun the focused tests and re-review until ACCEPT or the user explicitly defers a `should_fix`/`follow_up` (see [build-review-gate.md](build-review-gate.md)).
- **Trivial work** — docs-only, comment-only, config-only, or no-code — may take the lightweight path: `/run-review` at `focused` depth (verdict sidecar only; the focused closeout inherits the build's session ID per [scope-context.md](scope-context.md) §Session — never run it standalone). The focused run should still reach `ACCEPT`; a non-`ACCEPT` focused verdict means the work was misclassified as trivial — re-run at `standard`. Record the trivial classification and reason in `session-log.md` and `build-status.json.review`.
- "Trivial" = no new or altered logic, no new attack surface, prose/config only. When in doubt, run `standard`.

A finalize with non-trivial changes and no ACCEPT verdict is `blocked`, not `complete`. This gate never forces `standard`/`deep` on trivial or docs-only work — the lightweight path with a recorded reason satisfies it.

### 1. Question Answered

Evaluate whether the build addressed the original intent:

| Assessment | Criteria |
|------------|----------|
| `yes` | Build fully addresses the plan tasks or consult recommendation |
| `partially` | Core intent addressed but notable gaps remain |
| `no` | Build does not answer the original question or recommendation |

When `partially` or `no`: suggest re-direction to the design phase (via `/use-goal-prompt plan`) to reframe the problem before another build attempt. State what was missed and why re-framing may help.

### 2. Prototype Completion Gates

**Precondition**: Phase Trace has rows for scope, implement, review, review-gate, polish; expected artifacts exist.

Gate applies on ACCEPT only. On ITERATE (cap reached), skip to completion declaration.

| Gate | Criteria |
|------|----------|
| Builds/parses | Changed files are syntactically valid |
| Intent met | Implementation matches input source intent |

No mandatory test or documentation gates. Surface test/doc suggestions as learnings, not blockers.

### 3. Learnings

Identify `build_learnings` on ALL outcomes (ACCEPT, cap-reached, partial) — not only on ACCEPT. Failed/capped builds often contain the most valuable learnings.

For each learning, capture structured fields:
- `what_was_attempted` — approach or assumption tested
- `result` — succeeded, failed, or partially worked
- `assumption_corrected` — what we now know to be true/false (if applicable)
- `knowledge_candidate` — yes/no: should this persist as a project knowledge entry?

Categories: skill updates, memory entries, rule changes, spec corrections, constraint discoveries, doc-update candidates (behavior changed but no doc file modified).

Propose only — never auto-apply. User must approve each update before it is written.

### 4. Knowledge Curation

When any learning has `knowledge_candidate: yes`, the orchestrator schedules knowledge curation with the items as candidates.

### 5. Completion Declaration

- **ACCEPT + gates met + question answered `yes`**: `Build complete.`
- **ACCEPT + gates met + question answered `partially`**: `Build complete (partial).` — list gaps; suggest design phase reframing via `/use-goal-prompt plan`.
- **ACCEPT + question answered `no`**: `Build NOT complete.` — explain mismatch; suggest design phase reframing via `/use-goal-prompt plan`.
- **ITERATE (cap reached)**: `Build NOT complete.` — list remaining blockers from review.

### 6. Session Log

Append: completion declaration, question-answered assessment, final `files_modified`, learnings proposals if any, open items.

Include a **review summary**: target + depth used, verdict, findings accepted/rejected (one line each, with why), focused tests run, and the clean result — or, for the lightweight path, the trivial classification and reason. Do not run an extra review just to improve this wording; report the run that actually produced the verdict.

### 7. Structured Completion Artifact

Write `.scratch/<session>/build-status.json` on every terminal outcome (ACCEPT, cap-reached, partial, question-answered=no). Schema and field semantics: [build-status-schema.md](build-status-schema.md). Atomic write via `.tmp + mv` — never emit half-written JSON.

Required fields on emission: `schema_version`, `status`, `exit_reason`, `session_id`, `timestamp_utc`, `base_rev`, `head_rev`, `dirty_start`, `dirty_end`, `iteration`, `commits`, `files_modified`. Optional: `iteration_cost_usd` (only when invoking harness set `--max-budget-usd`); `review` block recording the review-closeout decision (`{mode, depth, verdict, verdict_path, trivial_exception, reason}`) — see [build-status-schema.md](build-status-schema.md).

The artifact is additive — it does not replace the natural-language declaration. Existing consumers reading stdout/session-log continue to work unchanged. Downstream consumers can read the JSON as the terminal signal.

## Constraints

- Never declare `Build complete.` without evaluating question-answered assessment.
- Never auto-apply learnings — proposal only, user approval required.
- No mandatory test/doc content gates. Surface test/doc suggestions as learnings, not blockers.
- Gate completion declaration on ACCEPT. Surface learnings on ALL outcomes (ACCEPT, cap-reached, partial).
- Always emit `build-status.json`. A missing artifact is a bug, not a silent skip — downstream consumers treat absence as `in_progress` and may stall.
