# Inspect (Phase 3)

## Role

Inspector dispatch and envoy coordination for standalone review. Parallel @inspector agents examine change from different lenses; @envoy provides external perspective.

## Input

- `review_brief` at `.scratch/<session>/review-brief.md`
- Diff/file list and risk level from Phase 2
- Depth classification (`standard` or `deep`)

## Instructions

Cap: base (3) + envoy (1) + augmented <= 6.

### Inspector Dispatch

Dispatch `@inspector` type in parallel. Each receives: `review_brief` path, diff/file list, risk level.

| Role | Persona | Output |
|------|---------|--------|
| `spec-reviewer` | Plan requirement <-> implementation coverage; Missing/Extra/Misaligned labels | `.scratch/<session>/review-spec-reviewer.md` |
| `correctness-reviewer` | Logic errors, edge cases, race conditions, adversarial inputs | `.scratch/<session>/review-correctness-reviewer.md` |
| `risk-reviewer` | Security boundaries, performance, scalability; depth scales by risk level | `.scratch/<session>/review-risk-reviewer.md` |

### Persona Disambiguation

Each inspector applies ONLY its assigned lens — override @inspector generic review order.

- **spec-reviewer**: NOT logic, risk, or quality — only plan↔code structural alignment
- **correctness-reviewer**: NOT plan coverage or security — only logic soundness under adversarial inputs
- **risk-reviewer**: NOT plan fidelity or isolated logic — only production survivability (security, perf, scale)

Ambiguity tiebreaker: plan requirement gap → spec-reviewer. Logic defect → correctness-reviewer. Missing control/resource bound → risk-reviewer.

At `deep` depth: dispatch additional `@inspector` per applicable variance lens, capped at 6 total. Each writes to `.scratch/<session>/review-augmented-{lens}.md`.

Variant hunting scope: `standard` — constrained to reviewed change surface. `deep` — full codebase.

### High-Risk Security Probe

When risk is high: auth boundary regressions, privilege escalation paths, input trust boundary violations (injection, unsafe parsing, unvalidated data), secret/token exposure in logs/configs/errors, failure-mode data leaks.

### Variant Hunting

After finding a security issue, search codebase-wide for similar patterns. Exact match first → generalize one element at a time (function name → argument shape → call context) → stop when FP rate >50%. Group by root cause. Per match: location, confidence (high/med/low), attacker-controllability.

See also: [security-probe.md](security-probe.md) (false-positive filtering).

### Envoy

Load `use-envoy`. Dispatch `@envoy` concurrently with @inspector agents:
- Prompt content: `review_brief` contents, diff/file list, severity buckets, noise filtering rules (self-contained, no local paths)
- Output format: `[B]`/`[S]`/`[F]`-prefixed findings with evidence levels, file+line range, correctness assessment (correct/issues, high/med/low confidence)
- Output path: `.scratch/<session>/review-inspect-envoy.md`
- Variant: `standard`

### Gate B: Agent output verification

After all @inspector agents complete, before Phase 4 dispatch, verify each expected output file contains at least one finding entry (prefixed `[B`, `[S`, or `[F`). File with only preamble and no finding entries = absent.

| Agent output | Fallback action |
|-------------|-----------------|
| `risk-reviewer` missing or no findings | Inject blocking finding: "Risk review agent produced no output (infrastructure gap) — security coverage incomplete. Manual security pass recommended." |
| `spec-reviewer` missing or no findings | Note in findings header: "Spec compliance review incomplete — coverage gap." Proceed. |
| `correctness-reviewer` missing or no findings | Note in findings header: "Correctness review incomplete — coverage gap." Proceed. |
| `envoy` missing or skip advisory | Proceed without — primary inspectors sufficient. Do not include in synthesis. |

Do NOT pass empty/absent paths to Phase 4 (@synthesizer).

## Output

Inspector output files at `.scratch/<session>/review-{role}.md` and optionally `.scratch/<session>/review-inspect-envoy.md`.

## Constraints

- Do NOT run Phase 3 inline at `standard` or `deep` depth. Dispatch is mandatory. Inline execution at standard/deep is an error — fall back only when Gate A fails.
- Passing empty/absent agent output paths to @synthesizer is an error — filter before dispatch.
