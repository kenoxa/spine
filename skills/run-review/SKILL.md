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

## Phases

| Phase | Agent type | Reference |
|-------|-----------|-----------|
| Scope + Context | main thread | [scope-context.md](references/scope-context.md) |
| Inspect | `@inspector` (parallel) + `@envoy` | [inspect-dispatch.md](references/inspect-dispatch.md) |
| Synthesize + Output | `@synthesizer` + main thread | [synthesize-resort.md](references/synthesize-resort.md) |

Review brief: [template-review-brief.md](references/template-review-brief.md)

Security: [security-probe.md](references/security-probe.md)

See also: `security-reviewer` (deeper heuristics), `@visualizer` (visual diff review — dispatched after findings), `reducing-entropy` (net-complexity measurement), `differential-review` (security-focused PR review with blast radius detection), `fp-check` (systematic true/false positive verification).

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
