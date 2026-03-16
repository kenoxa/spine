# Plan Template

## Self-Sufficiency Contract

Plans MUST be executable without chat-history context. Paths are repo-relative; terms defined at first use; rationale included for material decisions. No references to prior conversation turns.

Target ~150 lines. Longer signals narrative Summary or prose-heavy Task descriptions.

## Required Sections

### Summary

Problem or goal, solution approach, expected outcome. 2–4 sentences minimum.

In spec mode: the spec reference line (`> Spec: ...`) appears as the first line after the Summary heading, before the prose summary.

### Tasks

Ordered list of implementation tasks. Each task includes:

| Field | Required | Content |
|-------|----------|---------|
| `id` | Always | Task identifier |
| `description` | Always | What to do and why |
| `dependencies` | Always | Task IDs this depends on (empty list if none) |
| `files` | Always | Repo-relative paths to create or modify |
| `changes` | Always | Per-file change description — what specifically changes and how |

No vague file refs — trace to concrete paths. New files: specify path + purpose.

### Parallelism Map

Dependency graph with explicit edges (A → B when B depends on A), fanout groups safe to parallelize, blockers. Diagram required when 2+ parallel groups or 6+ tasks.

### Completion Criteria

Testable acceptance conditions. Verifiable without plan author.

### Execution Handoff

State that execution begins on approval. Note required skills/context for subagents.

## Conditionally Required Sections

Include when condition met. Omit only with skip rationale.

### Documentation Tasks

Required when `docs_impact` ≠ `none`. Explicit doc updates with target files. When `docs_impact` is `customer-facing` or `both`, include changelog entries following the `use-writing` skill's changelog rules.

### Test Scenarios

Required for behavior-changing work. Concrete given/when/then — not abstract "add tests".

## Optional Sections

Use when scope warrants. When present, each section's MUST-when-present rules apply.

| Section | Content | MUST-when-present |
|---------|---------|-------------------|
| **Context and Orientation** | Repo conventions, flow gaps, known constraints | — |
| **Approach** | Key decisions and tradeoffs; written for human reader, not executor. Diagram for non-trivial flows | NEVER duplicate Implementation Intent — different readers |
| **Decisions** | Material decisions with options and rationale | NEVER include unresolved placeholders (TBD); all decisions resolved, defaulted, or user-deferred with evidence |
| **Phased Plan** | Multi-phase sequencing for work spanning distinct phases | — |
| **Risks and Rollback** | Notable risks and rollback strategy | — |
| **Implementation Intent** | `code_intent` (pattern-level what/how), `acceptance_criteria` (testable per-task). MAY include `reference_anchors` | Outcome-focused "what" over "how" |
| **Code Anchors** | Existing code to align with or modify | MUST list explicit paths |
| **Draft Artifacts** | Pre-written text for docs, config, schema. Workers refine rather than create | MUST be non-placeholder |
| **Spec Context** | Spec reference line + verbatim EARS acceptance criteria + constraints from spec | NEVER paraphrase EARS criteria — copy verbatim from spec |
| **Validation** | Runnable check per EARS criterion from spec phase | 1:1 mapping to acceptance criteria; every EARS criterion gets a validation step |
| **Deferred** | Scope drift log — tasks removed from this phase with target phase noted | Silent population — log drift items without prompting user for each one |

## Evidence Expectations

| Claim type | Required level |
|-----------|----------------|
| Approach choice | E1+ (cite evidence, not intuition) |
| Risk assertion | E2+ |
| Blocking objection | E2+ |
| Standard pattern note | E0 (advisory) |
