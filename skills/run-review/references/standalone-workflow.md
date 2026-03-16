# Standalone Review Workflow

Six-phase standalone review. Read-only — no file writes, no test execution.

## Depth

Classify and lock at end of Phase 1. May upgrade during Phases 2–4 on strong evidence (auth boundary, privilege escalation, injection surface). Downgrade never permitted.

| Depth | Risk | Behavior |
|-------|------|----------|
| `focused` | Low | Phases 1–2 inline → skip to Phase 6. No dispatch, no session ID, no scratch artifacts (except @visualizer, non-blocking). |
| `standard` | Medium | Session ID generated. Phases 1–2 inline → review_brief (Gate A) → Phase 3 dispatch → Phase 4 dispatch → Phase 5 re-sort → Phase 6 output. |
| `deep` | High | Same as `standard` + expanded security probe + augmented @inspector (cap 6 total). |

**Default standalone: `standard`.**

## Session

At `standard`/`deep`: generate session ID after depth classification. Format: `{slug}-{hash}` — 3–5 words from review scope, hash from `openssl rand -hex 2`. Inherit active session ID when invoked from another skill. All scratch paths: `.scratch/<session>/`.

At `focused`: no session ID.

## Phases

Six phases. All six always execute at every depth — but phases 3–5 change form based on depth.

**Do NOT run Phases 3–5 inline at `standard` or `deep` depth. Dispatch is mandatory.** Inline execution at standard/deep is an error — fall back only when Gate A fails.

Dispatch roles apply at `standard` and `deep` depth. At `focused` depth, run all phases inline on main thread — skip directly from Phase 2 to Phase 6.

| Phase | Agent type | Depth |
|-------|-----------|-------|
| 1. Scope | main thread | all |
| 2. Context (passes 1–4) | main thread | all |
| 3. Inspect | `@inspector` (parallel) + `@second-opinion` | standard/deep |
| 4. Synthesize | `@synthesizer` | standard/deep |
| 5. Re-sort | main thread | standard/deep |
| 6. Output | main thread | all |

### 1. Scope

Main thread (all depths). Confirm what was requested and what changed. Classify depth. Lock risk level.

### 2. Context (passes 1–4)

Main thread (all depths). Build understanding before judging. Four passes:

1. **Scope check** — what was requested; what changed; what is explicitly out of scope.
2. **Context building** — scale depth by risk.
   - High risk: line-by-line analysis, not gist-level skimming.
   - Track invariants and assumptions explicitly.
   - Treat external calls as adversarial until proven otherwise.
3. **Evidence check** — validate claims against current code and requirements.
4. **Spec compliance** — verify built behavior matches requested behavior.

At `focused` depth: after pass 4, skip directly to Phase 6.

At `standard`/`deep` depth: after pass 4, emit `review_brief` per [review-brief-schema.md](review-brief-schema.md) (Gate A) before proceeding.

### 3. Inspect (standard/deep only — mandatory dispatch)

Dispatch `@inspector` type in parallel. Each receives: `review_brief` path, diff/file list, risk level.

| Role | Persona | Output |
|------|---------|--------|
| `spec-reviewer` | Plan requirement ↔ implementation coverage; Missing/Extra/Misaligned labels | `.scratch/<session>/review-spec-reviewer.md` |
| `correctness-reviewer` | Logic errors, edge cases, race conditions, adversarial inputs | `.scratch/<session>/review-correctness-reviewer.md` |
| `risk-reviewer` | Security boundaries, performance, scalability; depth scales by risk level | `.scratch/<session>/review-risk-reviewer.md` |

At `deep` depth: dispatch additional `@inspector` per applicable variance lens, capped at 6 total. Each writes to `.scratch/<session>/review-augmented-{lens}.md`.

Variant hunting scope: `standard` — constrained to reviewed change surface. `deep` — full codebase.

#### Second-Opinion

Load `use-second-opinion`. Dispatch `@second-opinion` concurrently with @inspector agents:
- Prompt content: `review_brief` contents + diff/file list + severity bucket definitions + noise filtering rules (all self-contained — no local path references)
- Output format: severity-bucketed findings with `[B]`/`[S]`/`[F]` prefixes, evidence levels, per-finding file path and line range, correctness assessment (`correct` or `issues found`) with categorical confidence (high/med/low)
- Output path: `.scratch/<session>/review-inspect-second-opinion.md`
- Variant: `standard`

Cap: base (3) + second-opinion (1) + augmented ≤ 6.

#### Gate B: Agent output verification

After all @inspector agents complete, before Phase 4 dispatch, verify each expected output file contains at least one finding entry (prefixed `[B`, `[S`, or `[F`). File with only preamble and no finding entries = absent.

| Agent output | Fallback action |
|-------------|-----------------|
| `risk-reviewer` missing or no findings | Inject blocking finding: "Risk review agent produced no output (infrastructure gap) — security coverage incomplete. Manual security pass recommended." |
| `spec-reviewer` missing or no findings | Note in findings header: "Spec compliance review incomplete — coverage gap." Proceed. |
| `correctness-reviewer` missing or no findings | Note in findings header: "Correctness review incomplete — coverage gap." Proceed. |
| `second-opinion` missing or skip advisory | Proceed without — primary inspectors sufficient. Do not include in synthesis. |

Do NOT pass empty/absent paths to Phase 4 (@synthesizer).

### 4. Synthesize (standard/deep only — mandatory dispatch)

Dispatch `@synthesizer` with all non-empty inspector output paths. Include `.scratch/<session>/review-inspect-second-opinion.md` if it exists and is not a skip advisory. Output: `.scratch/<session>/review-synthesis.md`.

Synthesizer: use-second-opinion `standard` variant. Tail: "After merging findings, include a correctness assessment (`correct` or `issues found`) with categorical confidence (high/med/low) and 1-2 sentence justification. When second-opinion assessment exists, note agreement or disagreement."

**Gate C:** If synthesis output empty or missing: read individual agent output files directly; merge manually by severity bucket; apply deduplication; apply severity re-sort. Log to user: "Synthesis output absent — falling back to individual agent outputs."

### [CONFLICT] Resolution

Main thread, after Phase 4. Orchestrator has full pass 1–4 context. Apply:

1. **Higher-evidence claim wins** when evidence levels differ (E2 over E1 is deterministic). If evidence levels in a [CONFLICT] tag are ambiguous or summarized, read source inspector files (`.scratch/<session>/review-{role}.md`) to retrieve original levels.
2. **Equal evidence** — higher severity bucket wins. Severity demotion requires explicit written justification.
3. **Irresolvable** — retain BOTH findings labeled "(unresolved — user decision required)" at top of their severity bucket.

Never silently drop a [CONFLICT] entry.

### 5. Re-sort (standard/deep only — main thread)

Re-sort all findings after [CONFLICT] resolution, before user presentation:

1. `blocking` (within bucket: E3 > E2 > E1 > E0)
2. `should_fix` (within bucket: E3 > E2 > E1 > E0)
3. `follow_up` (within bucket: E3 > E2 > E1 > E0)

**Primary sort is ALWAYS severity bucket.** Evidence level is secondary within bucket only. A `follow_up` at E3 is presented after a `blocking` at E2.

### 6. Output

Main thread (all depths). Return findings using severity buckets and output format from SKILL.md.

At `standard`/`deep` depth: intermediate artifacts in `.scratch/<session>/` (review-brief.md, review-{role}.md, review-synthesis.md). User-facing findings always assembled by main thread.

#### Visual diff report

After findings, dispatch `@visualizer` subagent: diff review for <git-ref>. Findings: <key blocking/should_fix>. Output: `.scratch/<session>/diff-review.html` (standalone: `.scratch/<slug>-<hash>.html`).

Non-blocking — if dispatch fails, log and continue; review findings are the primary deliverable.

Write `.scratch/<session>/review-findings.md` as severity-bucketed table: severity | file | finding | evidence level | status. Non-blocking; write after user output.

## Anti-Patterns

- Re-sorting by evidence level instead of severity bucket before user presentation
- Passing empty/absent agent output paths to @synthesizer — filter before dispatch
- Emitting a `review_brief` without `noise_context` — inspectors will flag pre-existing issues as findings
- Resolving [CONFLICT] by silently picking one side — present both or apply tiebreaker rules explicitly
