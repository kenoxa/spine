---
description: >
  Risk-based testing standards with structured test design.
  Use when adding tests, evaluating coverage, or validating edge cases.
  Do NOT use for test execution during do-execute — that skill has its own test gates.
argument-hint: "[feature or area to test]"
---

Risk-based test strategy with perspective tables, structured case design, and coverage evidence.

## Workflow

1. **Classify risk** — low, medium, or high based on blast radius and failure cost.
2. **Build perspective table** — define case IDs and expected behavior before writing tests
   (required for medium/high risk; recommended for low).
3. **Choose test mix** — unit for logic branches, integration for boundary contracts,
   E2E when user flow risk is high.
4. **Design cases** — equivalence classes, boundary values, failure-mode checks.
5. **Implement and run** — execute relevant suites, collect coverage evidence.
6. **Report** — summarize protected behavior, known gaps, commands run, coverage data.

## Test Perspective Table

| Case ID | Input / Precondition | Perspective | Expected Result |
|---------|---------------------|-------------|-----------------|
| TC-N-01 | Valid input | Equivalence — normal | Success |
| TC-A-01 | Null input | Boundary — null | Validation error |
| TC-B-01 | Max + 1 | Boundary — overflow | Validation error |

Case ID format: `TC-{N|A|B}-{number}` (N=normal, A=abnormal, B=boundary).
Minimum boundaries: `0`, min, max, `±1`, empty, null.

## Risk Heuristics

| Risk | Test expectations |
|------|------------------|
| Low | Unit coverage around changed logic + one failure/boundary case |
| Medium | Unit + integration for interaction boundaries; perspective table required |
| High | + security/failure-path scenarios, stronger coverage evidence |

## Coverage Expectations

- Minimum: 90% branch coverage for changed behavior.
- Target: 100% for security code, complex business logic, and public APIs.
- Always report execution command and coverage method.

## Anti-Patterns

- Writing tests that mirror implementation details instead of behavior
- Vacuous assertions (`>= 0`, `length >= 0`)
- Swallowing errors in try/catch instead of asserting and failing fast
- Sleep-based timing instead of condition-based waits
- Claiming coverage improvements without execution evidence
- Skipping the perspective table for medium/high risk changes
