---
name: with-testing
description: >
  Test boundary decisions and risk-based testing strategy.
  Use when deciding what to mock, planning test strategy, evaluating coverage,
  or before writing tests for a new feature.
  Do NOT use for test execution during do-build — that skill has its own review gates.
argument-hint: "[feature, module, or function under test]"
---

Map test boundaries before writing tests — classify each collaborator as real or stubbed, then let risk set depth.

## Test Boundary Map

Before writing tests, classify each collaborator of the unit under test:

| Collaborator | Category | Decision |
|---|---|---|
| HTTP / external API | External | Mock — network is variable, not intention |
| Filesystem | External | Mock — side-effect producer |
| Date / RNG | Nondeterministic | Mock — breaks reproducibility |
| DOM side effects | External | Mock — environment dependency |
| Database | External | Context-dependent — prefer test DB when available |
| Internal module | Owned | Keep real — mocking what you own verifies nothing |

The heuristic: if a collaborator can fail the test for reasons unrelated to the code's intention, mock it.

For mock implementation rules and TDD workflow, use the `tdd` skill.

## Depth & Coverage

| Risk | Test expectations |
|---|---|
| Low | Unit coverage on changed logic; one failure case |
| Medium | + integration tests at mock seams; perspective table recommended |
| High | + security/failure-path scenarios; perspective table required |

Minimum: **90%** branch coverage. Target: **100%** for security, complex business logic, public APIs.
Edge values: 0, min, max, +-1, empty, null.

## Anti-Patterns

- Mocking what you own — stubbing internal collaborators produces tests that verify wiring, not behavior
- Vacuous assertions (`>= 0`, `length >= 0`)
- Claiming coverage without execution evidence
- Skipping perspective table for medium/high risk changes
