---
name: run-review
description: >
  Structured code review with severity-bucketed findings and resolution gates.
  Use after code changes or when the user asks for review, code audit, or thorough/deep review.
  Do NOT use during active implementation — use the review phase in do-execute instead.
argument-hint: "[file, PR, or scope]"
---

Review changed code against requested outcome and accepted plan. Structured, severity-bucketed findings. Read-only — no file writes, no test execution.

## Depth Model

**Agent preload note:** When run-review is loaded via `skills: [run-review]` by @inspector, @analyst, @debater, or any other agent, only the following sections apply: Severity Buckets, Risk Scaling, Noise Filtering, Output Format, Completion Declaration, Evidence Levels, and Anti-Patterns. The Depth, Session, review_brief, Dispatch, Gate A/B/C, [CONFLICT] Resolution, and Severity Re-Sort sections do NOT apply in agent preload context.

Depth is classified and locked at the end of pass 1 (after scope is established). Depth may be upgraded during passes 2-4 if strong evidence emerges (e.g., auth boundary, privilege escalation path, or injection surface discovered). Downgrading is never permitted once set.

| Depth | Risk level | Behavior |
|-------|-----------|----------|
| `focused` | Low | All passes inline on main thread. No dispatch, no session ID, no scratch artifacts (except @visualizer, non-blocking). |
| `standard` | Medium | Session ID generated. Passes 1-4 inline → `review_brief` → parallel @inspector (3 roles) → @synthesizer → re-sort → user output. |
| `deep` | High | Same as `standard` + expanded security probe + augmented @inspector at deep (cap 6 total). |

Default when invoked standalone: `standard`.
When loaded as a rule-set by another agent: depth classification does not apply (see agent preload note above).

At `focused` depth: existing single-pass inline behavior fully preserved. No `review_brief` written, no session ID generated, no scratch artifacts. Output contract identical to current behavior.

## Session

At `standard`/`deep` depth: generate session ID immediately after depth classification. Format: `{slug}-{hash}` where slug is 3-5 words from the review scope, hash from `openssl rand -hex 2`. When invoked from a skill with an active session, inherit that session ID. All scratch paths use `.scratch/<session>/`.

At `focused` depth: no session ID generated.

## Workflow

1. **Scope check** — confirm what was requested and what changed.
2. **Context building** — build understanding before judging. Scale depth by risk.
   - High risk: line-by-line analysis, not gist-level skimming.
   - Track invariants and assumptions explicitly.
   - Treat external calls as adversarial until proven otherwise.
   - When evidence contradicts mental model, update the model — never reshape evidence to fit.
3. **Evidence check** — validate claims against current code and requirements.
4. **Spec compliance** — verify built behavior matches requested behavior.

### review_brief (Gate A — standard/deep only)

After pass 4, before dispatching any @inspector agent, emit `review_brief` to `.scratch/<session>/review-brief.md`.

Mandatory 7-field schema — all fields required:

| Field | Source | Content |
|-------|--------|---------|
| `scope` | Pass 1 | What was requested; what changed; what is explicitly out of scope |
| `invariants` | Pass 2 | Key assumptions, adversarial surfaces, external call trust levels |
| `evidence_baseline` | Pass 3 | Per-claim evidence levels; E2+ vs E0 observations |
| `spec_compliance_map` | Pass 4 | In-scope vs out-of-scope behavior; confirmed vs missing vs extra |
| `noise_context` | Pass 2+3 | Pre-existing issues (listed by pattern/file); issues introduced or worsened by this change |
| `risk_level` | Pass 1 | Low / Medium / High (locked value) |
| `diff_ref` | Pass 1 | Git ref or file list being reviewed |

**Gate A check:** After writing review_brief, read it back and confirm all 7 fields are present before issuing any @inspector dispatch. Dispatch must not begin in the same orchestration turn as the write. If any mandatory field is absent: do NOT dispatch @inspector. Fall back to inline execution of passes 5-6 on main thread. Log to user: "review_brief incomplete after pass 4; proceeding inline at focused depth."

Inspector agents MUST read `review_brief` before raising any finding. `noise_context` is required reading — findings about pre-existing issues that predate this change are invalid.

### Pass 5-6: Risk and Quality review (conditional on depth)

**At `focused` depth:** Run passes 5 (risk) and 6 (quality) inline on main thread using existing single-pass behavior.

**At `standard`/`deep` depth:** Dispatch in parallel (`@inspector` type). Each receives: `review_brief` path, diff/file list, risk level.

<!-- @inspector preloads run-review as its rule-set; the agent-preload gate above prevents this from causing behavioral confusion. Subagents are independent processes — no runtime recursion. -->

| Role | Persona | Output |
|------|---------|--------|
| `spec-reviewer` | Plan requirement ↔ implementation coverage; Missing/Extra/Misaligned labels | `.scratch/<session>/review-spec-reviewer.md` |
| `correctness-reviewer` | Logic errors, edge cases, race conditions, adversarial inputs | `.scratch/<session>/review-correctness-reviewer.md` |
| `risk-reviewer` | Security boundaries, performance, scalability; depth scales by risk level | `.scratch/<session>/review-risk-reviewer.md` |

At `deep` depth: dispatch additional `@inspector` per applicable variance lens, capped at 6 total agents. Each writes to `.scratch/<session>/review-augmented-{lens}.md`.

Variant hunting scope: `standard` → constrained to reviewed change surface only. `deep` → full codebase per existing run-review rules.

#### Second-Opinion (standard/deep only)

Load `with-second-opinion`. Dispatch `@second-opinion` concurrently with @inspector agents:
- Prompt content: `review_brief` contents + diff/file list + severity bucket definitions + noise filtering rules (all self-contained — no local path references)
- Output format: severity-bucketed findings with `[B]`/`[S]`/`[F]` prefixes, evidence levels, per-finding file path and line range, correctness assessment (`correct` or `issues found`) with categorical confidence (high/med/low)
- Output path: `.scratch/<session>/review-second-opinion.md`
- Variant: `standard`

Cap: base (3) + second-opinion (1) + augmented <= 6.

### Gate B: Agent output verification (standard/deep only)

After all @inspector agents complete, before @synthesizer dispatch, verify each expected output file contains at least one finding entry (prefixed `[B`, `[S`, or `[F`). A file with only preamble text and no finding entries is treated as absent.

| Agent output | Fallback action |
|-------------|-----------------|
| `risk-reviewer` missing or no findings | Inject a blocking finding: "Risk review agent produced no output (infrastructure gap, not a detected defect) — security coverage is incomplete. Manual security pass recommended before accepting this change." |
| `spec-reviewer` missing or no findings | Note in findings header: "Spec compliance review incomplete — coverage gap." Proceed with remaining outputs. |
| `correctness-reviewer` missing or no findings | Note in findings header: "Correctness review incomplete — coverage gap." Proceed with remaining outputs. |
| `second-opinion` missing or skip advisory | Proceed without — primary inspectors are sufficient. Do not include in synthesis. |

Do NOT pass empty/absent paths to @synthesizer.

### Synthesis (standard/deep only)

Dispatch `@synthesizer` with all non-empty inspector output paths. Include `.scratch/<session>/review-second-opinion.md` if it exists and is not a skip advisory. Output: `.scratch/<session>/review-synthesis.md`.

Synthesizer: with-second-opinion `standard` variant. Tail: "After merging findings, include a correctness assessment (`correct` or `issues found`) with categorical confidence (high/med/low) and 1-2 sentence justification. When second-opinion assessment exists, note agreement or disagreement."

**Gate C:** If synthesis output is empty or missing: read individual agent output files directly; merge manually by severity bucket; apply deduplication; apply severity re-sort. Log to user: "Synthesis output absent — falling back to individual agent outputs."

### [CONFLICT] Resolution (main thread, after Gate C, before re-sort)

Main thread has full pass 1-4 context and is the orchestrator for this review. Apply:

1. **Higher-evidence claim wins** when evidence levels differ (E2 over E1 is deterministic). If evidence levels in a [CONFLICT] tag are ambiguous, untagged, or appear summarized, read the source inspector output files directly (`.scratch/<session>/review-{role}.md`) to retrieve original evidence levels before applying this rule.
2. **Equal evidence → higher severity bucket.** Severity demotion requires explicit written justification.
3. **Irresolvable** → retain BOTH findings labeled "(unresolved — user decision required)" at the top of their severity bucket.

Never silently drop a [CONFLICT] entry.

### Severity Re-Sort (main thread, after [CONFLICT] resolution, before user presentation)

Re-sort all findings:
1. `blocking` (within bucket: E3 → E2 → E1 → E0)
2. `should_fix` (within bucket: E3 → E2 → E1 → E0)
3. `follow_up` (within bucket: E3 → E2 → E1 → E0)

**Primary sort is ALWAYS severity bucket.** Evidence level is secondary sort within bucket only. A `follow_up` at E3 is presented after a `blocking` at E2.

7. **Output** — return findings using severity buckets below.

## Severity Buckets

| Bucket | Gate behavior |
|--------|--------------|
| `blocking` | Must fix before completion. Requires E2+ evidence. |
| `should_fix` | Recommended fix. Blocks completion unless user explicitly defers. |
| `follow_up` | Tracked debt. Does not block completion — record for future action. |

`blocking` findings without code evidence (E2+) are invalid — demote to `should_fix`.

## Risk Scaling

| Risk | Lenses |
|------|--------|
| Low | Spec compliance + quality |
| Medium | + testing-depth |
| High | + security probe |

### High-Risk Security Probe

When risk is high, explicitly check:
- Auth boundary regressions and privilege escalation paths
- Input trust boundaries (injection, unsafe parsing, unvalidated external data)
- Secret/token exposure in logs, configs, or error surfaces
- Failure-mode behavior that leaks data or bypasses controls

### Variant Hunting

After finding a security issue, search for similar patterns across the entire codebase — not just the module where the issue was found.

1. Start with exact match of the vulnerable pattern using Grep.
2. Generalize one element at a time (function name → argument shape → call context).
3. Review all new matches after each generalization. Stop when false-positive rate exceeds ~50%.
4. Search everywhere — variants often appear in unrelated modules.
5. Group results by root cause, not by symptom. One root cause may manifest as multiple vulnerability classes.
6. Per match: note location, confidence (high/medium/low), and whether inputs are attacker-controllable.

See also: [references/security-probe.md](references/security-probe.md) (false-positive filtering), `security-reviewer` (deeper heuristics), `@visualizer` (visual diff review — dispatched after findings), `reducing-entropy` (net-complexity measurement), `differential-review` (security-focused PR review with blast radius detection), `fp-check` (systematic true/false positive verification).

## Noise Filtering

Before raising any finding, verify:
- Introduced or worsened by reviewed change — pre-existing issues out of scope
- Discrete and actionable — not general codebase observations
- Does not demand rigor absent from rest of codebase
- Security findings at high risk: apply exclusion rules from [references/security-probe.md](references/security-probe.md)

## Output Format

Per finding: severity bucket, target file(s), remediation path, evidence level.

Directional findings: numbered issue ID with options (A/B/C), recommendation first, include "do nothing" when reasonable. Tradeoff rationale per option.

At `standard`/`deep` depth, intermediate artifacts are written to `.scratch/<session>/` (review-brief.md, review-{role}.md, review-synthesis.md). User-facing findings are always assembled and presented by the main thread.

### Visual diff report

After findings, dispatch `@visualizer` subagent: diff review for <git-ref>. Findings: <key blocking/should_fix>. Output: `.scratch/<session>/diff-review.html` (standalone: `.scratch/<slug>-<hash>.html`).

Non-blocking — if dispatch fails, log and continue; review findings are the primary deliverable.

Write `.scratch/<session>/review-findings.md` as a severity-bucketed table: severity | file | finding | evidence level | status. Non-blocking; write after user output is presented.

## Bug-Fix Review

Require root-cause evidence — fix must target source trigger, not symptom. Missing root-cause → `blocking`.

## Documentation Review

When reviewing docs, READMEs, or user-facing text:
- Wording precision and actionability
- Outdated or contradictory statements
- Command/skill/API names match current surface
- Claims backed by codebase evidence — unsupported → `should_fix`

## Deferral Policy

- Any finding deferrable with explicit user approval. Deferred findings remain visible — never silently removed.
- Deferral is an exception path, not the default.

## Completion Declaration

When all resolved or deferred: `Review complete. No unresolved findings.` or `Review complete. Unresolved findings remain` + list.

## Evidence Levels

See SPINE.md for E0–E3 definitions.

## Anti-Patterns

- Reviewing against personal preference instead of requested outcome and plan
- Blocking on E0-only claims without code evidence
- Writing files or executing tests during review
- Silently dropping deferred findings from output
- Skipping security probe on high-risk changes
- Merging review with implementation unless user asked for immediate fixes
- Blocking on `@visualizer` failure — review findings are the primary deliverable
- Dispatching @inspector at `focused` depth — inline pass only
- Re-sorting by evidence level instead of severity bucket before user presentation
- Passing empty/absent agent output paths to @synthesizer — filter before dispatch
- Emitting a `review_brief` without `noise_context` — inspectors will flag pre-existing issues as findings
- Resolving [CONFLICT] by silently picking one side — present both or apply tiebreaker rules explicitly
