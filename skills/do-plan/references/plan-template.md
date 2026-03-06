# Plan Template

## Self-Sufficiency Contract

Plans MUST be executable without chat-history context. All paths are repo-relative.
Terms are defined where first used. Rationale is included for material decisions.
No references to prior conversation turns.

## Required Sections

### Summary

Problem or goal, solution approach, expected outcome. 2–4 sentences minimum.
A reader unfamiliar with the conversation should understand purpose and approach from this section alone.

### Tasks

Ordered list of implementation tasks. Each task: id, description, dependencies (task IDs),
file/area scope when known.

### Parallelism Map

Dependency graph: explicit edges (A → B when B depends on A), fanout groups safe to parallelize,
blockers. Include a diagram when dependency structure is non-trivial (2+ parallel groups or 6+ tasks).

### Completion Criteria

Testable acceptance conditions. Must be verifiable without running the plan author.

### Execution Handoff

Explicit statement that when the plan is approved, execution begins. Note any domain-specific skills
or context required for execution subagents.

## Conditionally Required Sections

Include when scope meets the stated condition. Omission requires explicit skip rationale.

### Documentation Tasks

Required when scope has user-visible, API, or config changes (`docs_impact` ≠ `none`).
Explicit doc updates with target files. When `docs_impact` is `customer-facing` or `both`,
include changelog entries following the `writing` skill's changelog rules.

### Test Scenarios

Required for behavior-changing work. Concrete cases with given/when/then expectations
and expected inputs/outputs. Not abstract "add tests" tasks.

## Optional Sections

Use when scope warrants. When present, each section's MUST-when-present rules apply.

- **Context and Orientation** — Repo conventions, flow gaps, known constraints.
- **Approach** — Key decisions and tradeoffs; written for human reader, not executor. Include a diagram
  when non-trivial flow, sequencing, or component relationships warrant it. NEVER duplicate
  Implementation Intent; the two sections serve different readers.
- **Decisions** — Material decisions with options and rationale. NEVER include unresolved placeholders
  (TBD, "to be decided"); all decisions must be resolved, defaulted, or explicitly user-deferred
  with evidence before synthesis.
- **Phased Plan** — Multi-phase sequencing when work spans distinct phases.
- **Risks and Rollback** — Notable risks and rollback strategy.
- **Implementation Intent** — Goal-level intent: `code_intent` (pattern-level what/how),
  `acceptance_criteria` (testable per-task conditions). MAY include `reference_anchors`
  (existing code to align with). Outcome-focused "what" over implementation "how".
- **Code Anchors** — Repo-relative file paths and existing code to align with or modify.
  When present, MUST list explicit paths.
- **Draft Artifacts** — Pre-written text for docs, config, schema changes. Workers refine rather than
  create from scratch. When present, MUST be non-placeholder.

## Evidence Expectations

| Claim type | Required level |
|-----------|----------------|
| Approach choice | E1+ (cite evidence, not intuition) |
| Risk assertion | E2+ |
| Blocking objection | E2+ |
| Standard pattern note | E0 (advisory) |
