---
name: run-review
description: >
  Structured code review with severity-bucketed findings and evidence-level gating.
  Two modes: (1) standalone — six-phase workflow with depth classification, parallel
  @inspector dispatch, and second-opinion integration (see references/standalone-workflow.md);
  (2) agent preload — shared review rules (severity buckets, risk scaling, noise filtering)
  for @inspector, @analyst, @debater. Use after code changes or when the user asks for
  review, code audit, or thorough/deep review. Do NOT use during active implementation —
  use the review phase in do-execute instead.
argument-hint: "[file, PR, or scope]"
---

Review changed code against requested outcome and accepted plan. Structured, severity-bucketed findings. Read-only — no file writes, no test execution.

When invoked directly (not as agent preload): follow [references/standalone-workflow.md](references/standalone-workflow.md).

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
2. Generalize one element at a time (function name > argument shape > call context).
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

## Bug-Fix Review

Require root-cause evidence — fix must target source trigger, not symptom. Missing root-cause → `blocking`.

## Documentation Review

When reviewing docs, READMEs, or user-facing text:
- Wording precision and actionability
- Outdated or contradictory statements
- Command/skill/API names match current surface
- Claims backed by codebase evidence — unsupported → `should_fix`

## Output Format

Per finding: severity bucket, target file(s), remediation path, evidence level.

Directional findings: numbered issue ID with options (A/B/C), recommendation first, include "do nothing" when reasonable. Tradeoff rationale per option.

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
