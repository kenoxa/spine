# Inspect: Security Depth Methodology

Security-depth supplement for `run-review` when `inspect-risk-reviewer` flags AUTH, CRYPTO, VALUE-TRANSFER, or EXTERNAL-CALL surfaces. Spine-native methodology distilled from prior external security-review work.

## Codebase Size Strategy

| Size | Threshold | Strategy |
|------|-----------|----------|
| SMALL | <20 files | DEEP — read all deps, full git blame on every changed file |
| MEDIUM | 20–200 files | FOCUSED — 1-hop deps, priority files only |
| LARGE | 200+ files | SURGICAL — critical paths only; state scope limit explicitly |

## Risk-Level Triggers

| Risk | Surfaces | Required depth |
|------|----------|----------------|
| HIGH | Auth, crypto, value transfer, validation removal, external calls added | Full phases below + adversarial |
| MEDIUM | Business logic, state mutations, new public APIs | Phases 0–3 |
| LOW | Comments, tests, UI, logging | Standard run-review; skip security depth |

## Phase Outline

- **Triage** (Phase 0) — classify each changed file by risk; score blast radius; determine size strategy.
- **Code Analysis** (Phase 1) — read both versions; analyze each diff region (before/after/change/security); git-blame removed code for CVE or fix commits.
- **Test Coverage** (Phase 2) — identify coverage gaps; elevate risk when new functions lack tests or validation changes lack test updates.
- **Blast Radius** (Phase 3) — count callers quantitatively (1–5 LOW, 6–20 MEDIUM, 21–50 HIGH, 50+ CRITICAL); populate priority matrix.
- **Deep Context** (Phase 4) — map full call graph for HIGH surfaces; trace invariants and trust boundaries; five-whys root cause.
- **Adversarial** (Phase 5) — HIGH risk only: attacker model, concrete exploit scenarios with preconditions; cross-reference baseline invariants.
- **Report** (Phase 6) — write findings artifact; never output to chat only.

## Anti-Rationalization

Do not accept these excuses — escalate or apply full methodology:

- "Small PR / quick review" — Heartbleed was 2 lines; classify by RISK not size.
- "I know this codebase" — familiarity breeds blind spots; build explicit baseline context.
- "Just a refactor, no security impact" — refactors break invariants; treat as HIGH until proven LOW.
- "Blast radius is obvious" — you will miss transitive callers; calculate quantitatively.
- "I'll explain verbally" — no artifact = findings lost; always write the report.

## Output Contract

Write to: `.scratch/<session>/inspect-security-depth-report.md`

Required fields:
- **findings** — E2+ anchor (file + line), severity bucket (`blocking`/`should_fix`/`follow_up`), concrete attack scenario, confidence level.
- **blast_radius** — quantified caller count per surface; LOW/MEDIUM/HIGH/CRITICAL.
- **confidence** — per finding: HIGH (demonstrated path) / MEDIUM (plausible, not traced to end) / LOW (theoretical).
- **coverage_limits** — explicit statement of what was NOT reviewed.

Missing artifact = treat as blocking; downstream synthesis injects `[COVERAGE_GAP: security-depth — report absent]`.

## Cross-References

- [`security-probe.md`](security-probe.md) — false-positive exclusion rules; apply before raising any finding.
- [`inspect-risk-reviewer.md`](inspect-risk-reviewer.md) — risk-reviewer role; shares the same HIGH/MEDIUM/LOW surface classification.
