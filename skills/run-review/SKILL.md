---
name: run-review
description: >
  Structured code review with severity-bucketed findings and evidence-level gating.
  Two modes: (1) standalone — four-phase workflow with depth classification, parallel
  @verifier + @inspector dispatch, and envoy integration;
  (2) agent preload — shared review rules (severity buckets, risk scaling, noise filtering)
  for @inspector, @analyst, @debater. Use after code changes or when the user asks for
  review, code audit, or thorough/deep review. Do NOT use during active implementation —
  use the review phase in do-build instead.
argument-hint: "[file, PR, or scope]"
---

Read-only — no file writes, no test execution. Exception: @verifier may run non-destructive commands for E3 probes.

When invoked directly (not as agent preload): follow standalone review phases below.

**Reference convention**: linked refs load into mainthread. Backticked paths → dispatch to subagent, do NOT Read into mainthread.

**Phase Trace**: Log row at scope, inspect dispatch, synthesis, output. Include phase name, dispatch count, 1-line summary.

## Phases

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Scope + Context | mainthread | [scope-context.md](references/scope-context.md) |
| Inspect | `@verifier` (x1) + `@inspector` (x1 risk) + `@envoy` | `inspect-verifier.md`, `inspect-risk-reviewer.md`, `inspect-envoy.md` |
| Synthesis | `@synthesizer` | `inspect-synthesis.md` |
| Output | mainthread | [review-output.md](references/review-output.md) |

| Phase | Base | Envoy | Max Augmented (s/d) | Cap |
|-------|------|-------|--------------------|-----|
| Inspect | 2 | 1 | 0 / 2 | 5 |

### Phase 1: Scope + Context

Mainthread. Load [scope-context.md](references/scope-context.md).

Depth → session → context → Gate A (`review-brief.md`) → Gate A2 (`review-change-evidence.md`, optional) per [review-change-evidence-schema.md](references/review-change-evidence-schema.md). Brief: [template-review-brief.md](references/template-review-brief.md). Security: [security-probe.md](references/security-probe.md).

### Phase 2: Inspect

Dispatch in parallel with the **same** `{review_brief_path}` and `{change_evidence_path}` (when present) for every role — shared evidence plane with Phase 3 synthesis:
- `verifier` (`@verifier`) → `references/inspect-verifier.md`
- `risk-reviewer` (`@inspector`) → `references/inspect-risk-reviewer.md`
- `@envoy` → `references/inspect-envoy.md` (via `use-envoy`)

At `deep` depth: +augmented `@inspector` per variance lens (cap 5 total).

Do NOT run Phase 2 inline at `standard` or `deep` depth. Dispatch is mandatory. Inline execution only when Gate A fails (fallback to focused depth).

**Gate B** (before synthesis files exist): verifier: VERDICT present (FAIL/PARTIAL → note for synthesis; output without VERDICT → treat as PARTIAL). risk-reviewer: ≥1 finding entry (`[B`/`[S`/`[F`) OR explicit per-category clearance with rationale. Absent → inject blocking. envoy: not dispatched → `[COVERAGE_GAP: envoy — not dispatched]`. Verifier absent → inject blocking. (Same tag family as `use-envoy` Synthesis; Gate B = pre-run, Synthesis = post-run.)

### Phase 3: Synthesis

`@synthesizer` → `references/inspect-synthesis.md` (pass `{review_brief_path}`, `{change_evidence_path}` when applicable, plus inspector/verifier/envoy outputs)

**Gate C**: synthesis empty → fall back to individual agent outputs, merge manually.

### Phase 4: Output

Mainthread. Load [review-output.md](references/review-output.md).

Conflict resolution → re-sort → user output → visual diff → findings artifact.

---

## Shared Rules

Preloaded by `@inspector`, `@analyst`, `@debater` via `skills:` frontmatter. Must remain in SKILL.md.

### Severity Buckets

| Bucket | Gate behavior |
|--------|--------------|
| `blocking` | Must fix before completion. Requires E2+ evidence. |
| `should_fix` | Recommended fix. Blocks completion unless user explicitly defers. |
| `follow_up` | Tracked debt. Does not block completion — record for future action. |

`blocking` findings without code evidence (E2+) are invalid — demote to `should_fix`. Evidence levels: E0 intuition/best-practice (advisory only), E1 doc ref + quote, E2 code ref + symbol, E3 command + observed output.

### Risk Scaling

| Risk | Lenses |
|------|--------|
| Low | Spec compliance + quality |
| Medium | + testing-depth |
| High | + security probe |

### Noise Filtering

Before raising any finding, verify:
- Introduced or worsened by reviewed change — pre-existing issues out of scope
- Discrete and actionable — not general codebase observations
- Does not demand rigor absent from rest of codebase
- Security findings at high risk: apply exclusion rules from [references/security-probe.md](references/security-probe.md)
- Consistent with project intent — deliberate tradeoffs documented in plan or spec are not defects

### Anti-Patterns

- Reviewing against personal preference instead of requested outcome and plan
- Blocking on E0-only claims without code evidence
- Writing files or executing tests during review (exception: @verifier E3 probes)
- Silently dropping deferred findings from output
- Skipping security probe on high-risk changes
- Merging review with implementation unless user asked for immediate fixes

## See Also

`security-reviewer` (deeper heuristics), `@visualizer` (visual diff review — dispatched after findings), `reducing-entropy` (net-complexity measurement), `differential-review` (security-focused PR review with blast radius detection), `fp-check` (systematic true/false positive verification).
