# Scope + Context (Phase 1)

## Role

Scope and context building for standalone review — main thread phases. Classify depth, lock risk, build understanding before dispatch.

## Input

- User request (file, PR, scope, or free-form review ask)
- Diff or file list to review
- Active session ID (if invoked from another skill — inherit; otherwise generate)
- Caller-supplied `risk_level` (optional — from do-build scope or other invoker)

## Instructions

### Depth Classification

Classify and lock at end of Phase 1. May upgrade during Phase 2 on strong evidence (auth boundary, privilege escalation, injection surface). Downgrade never permitted.

| Depth | Risk | Behavior |
|-------|------|----------|
| `focused` | Low | Phase 1 inline -> skip to Phase 4. No dispatch, no session ID, no scratch artifacts (except @visualizer, non-blocking). |
| `standard` | Medium | Session ID generated. Phase 1 inline -> review_brief (Gate A) -> dispatch phases. |
| `deep` | High | Same as `standard` + expanded security probe + augmented @inspector (cap 5 total). |

**Default standalone: `standard`.**

### Session

At `standard`/`deep`: generate session ID after depth classification. Format: `{slug}-{hash}` — 3-5 words from review scope, hash from `openssl rand -hex 2`. Inherit active session ID when invoked from another skill. All scratch paths: `.scratch/<session>/`.

At `focused`: no session ID.

### Phase 1: Scope

Main thread (all depths). Confirm what was requested and what changed. Classify depth. Lock risk level.

When a caller supplies `risk_level`, use it as the floor — may upgrade on evidence, never downgrade below caller's classification. This ensures do-build's risk assessment (e.g., `high` for auth changes) is not silently reduced.

### Context (passes 1-4)

Main thread (all depths). Build understanding before judging. Four passes:

1. **Scope check** — what was requested; what changed; what is explicitly out of scope.
2. **Context building** — scale depth by risk.
   - High risk: line-by-line analysis, not gist-level skimming.
   - Track invariants and assumptions explicitly.
   - Treat external calls as adversarial until proven otherwise.
3. **Evidence check** — validate claims against current code and requirements.
4. **Spec compliance** — verify built behavior matches requested behavior.

At `focused` depth: after pass 4, skip directly to Phase 4.

At `standard`/`deep` depth: after pass 4, emit `review_brief` per [template-review-brief.md](template-review-brief.md) (Gate A) before proceeding.

### Bug-Fix Review

Require root-cause evidence — fix must target source trigger, not symptom. Missing root-cause -> `blocking`.

### Documentation Review

When reviewing docs, READMEs, or user-facing text:
- Wording precision and actionability
- Outdated or contradictory statements
- Command/skill/API names match current surface
- Claims backed by codebase evidence — unsupported -> `should_fix`

### Gate A: review_brief

After writing review_brief, read it back and confirm all 7 fields present. Dispatch must not begin in the same orchestration turn as the write. If any mandatory field is absent: do NOT proceed to Phase 2. Fall back to inline execution of remaining phases. Log to user: "review_brief incomplete after pass 4; proceeding inline at focused depth."

### Gate A2: review change evidence (recommended)

After Gate A, if a diff exists: write `.scratch/<session>/review-change-evidence.md` per [review-change-evidence-schema.md](review-change-evidence-schema.md) — diff/patch/excerpts, not paths-only. Omit → `inspect-envoy` uses deterministic gap string (see ref).

## Output

- `review_brief` written to `.scratch/<session>/review-brief.md` per [template-review-brief.md](template-review-brief.md) schema.
- **`review-change-evidence.md`** at `.scratch/<session>/review-change-evidence.md` when standard/deep and a change exists (recommended).

## Constraints

- Read-only — no file writes except `review-brief.md` and optional `review-change-evidence.md`. `@verifier` may run non-destructive commands (build, test, lint, type-check) for E3 probes. All other agents: no test execution.
- Emitting a `review_brief` without `noise_context` is an error — inspectors will flag pre-existing issues as findings.
- At `focused` depth, skip dispatch entirely — proceed inline to output phase.
