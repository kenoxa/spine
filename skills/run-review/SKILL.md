---
name: run-review
description: >
  Structured code review with severity-bucketed findings and evidence-level gating.
  Two modes: (1) standalone — six-phase workflow with depth classification, parallel
  @inspector dispatch, and envoy integration;
  (2) agent preload — shared review rules (severity buckets, risk scaling, noise filtering)
  for @inspector, @analyst, @debater. Use after code changes or when the user asks for
  review, code audit, or thorough/deep review. Do NOT use during active implementation —
  use the review phase in do-execute instead.
argument-hint: "[file, PR, or scope]"
---

Read-only — no file writes, no test execution.

When invoked directly (not as agent preload): follow standalone review phases below.

**Reference convention**: linked refs load into mainthread. Backticked paths → dispatch to subagent, do NOT Read into mainthread.

## Phases

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Scope + Context | mainthread | [scope-context.md](references/scope-context.md) |
| Inspect | `@inspector` (x3 parallel) + `@envoy` | `inspect-*.md` |
| Synthesis | `@synthesizer` | `inspect-synthesis.md` |
| Output | mainthread | [review-output.md](references/review-output.md) |

| Phase | Base | Envoy | Max Augmented (s/d) | Cap |
|-------|------|-------|--------------------|-----|
| Inspect | 3 | 1 | 0 / 2 | 6 |

### Phases 1-2: Scope + Context

Mainthread. Load [scope-context.md](references/scope-context.md).

Depth classification → session → context passes → review_brief (Gate A).

Review brief schema: [template-review-brief.md](references/template-review-brief.md).
Security probe: [security-probe.md](references/security-probe.md).

### Phase 3: Inspect

Dispatch `@inspector` in parallel + `@envoy`:
- `spec-reviewer` (`@inspector`) → `references/inspect-spec-reviewer.md`
- `correctness-reviewer` (`@inspector`) → `references/inspect-correctness-reviewer.md`
- `risk-reviewer` (`@inspector`) → `references/inspect-risk-reviewer.md`
- `@envoy` → `references/inspect-envoy.md`

At `deep` depth: +augmented `@inspector` per variance lens (cap 6 total).

Do NOT run Phase 3 inline at `standard` or `deep` depth. Dispatch is mandatory. Inline execution only when Gate A fails (fallback to focused depth).

**Gate B**: verify each output has ≥1 finding entry (`[B`/`[S`/`[F`). risk-reviewer absent → inject blocking. spec/correctness absent → note gap. envoy absent → proceed without.

### Phase 4: Synthesis

`@synthesizer` → `references/inspect-synthesis.md`

**Gate C**: synthesis empty → fall back to individual agent outputs, merge manually.

### Phases 5-6: Output

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

### Anti-Patterns

- Reviewing against personal preference instead of requested outcome and plan
- Blocking on E0-only claims without code evidence
- Writing files or executing tests during review
- Silently dropping deferred findings from output
- Skipping security probe on high-risk changes
- Merging review with implementation unless user asked for immediate fixes

## See Also

`security-reviewer` (deeper heuristics), `@visualizer` (visual diff review — dispatched after findings), `reducing-entropy` (net-complexity measurement), `differential-review` (security-focused PR review with blast radius detection), `fp-check` (systematic true/false positive verification).
