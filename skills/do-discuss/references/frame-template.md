# Frame Template

## Self-Sufficiency Contract

Frames MUST be understandable without chat-history context. All claims cite evidence source.
Terms are defined where first used. No references to prior conversation turns.

## Required Sections

### Session

Session ID in `{slug}-{hash}` format. Carried forward into do-plan when user proceeds.

### Confidence

One of: `low`, `medium`, `high`

| Level | Meaning | Recommended next step |
|-------|---------|----------------------|
| `high` | Frame question answered, no blocking unknowns | `do-plan` |
| `medium` | Frame question answered, open assumptions remain | `do-plan` (with caveats) |
| `low` | Frame question not fully answerable | `brainstorming` or more discussion |

### Frame Question

The single question whose answer unblocks planning. Must be specific (names the affected system or behavior), answerable (finite set of possible answers), and scoped (answering it directly enables planning).

### Goal

One-sentence problem restatement, disambiguated by discussion. Maps to `planning_brief.goal`.

### Problem Statement

2–4 sentences elaborating the problem and why-now. Must include:
- What exists today (confirmed)
- What is failing or missing (confirmed or labeled as assumed)
- What the user wants instead

### Scope

Table format:

| Dimension | In | Out |
|-----------|-----|-----|
| [area] | [included] | [excluded] |

Maps to `planning_brief.scope`.

### Known Facts

Confirmed claims with evidence level tags.

| Fact | Evidence | Source |
|------|----------|--------|
| [claim] | E0/E1/E2/E3 | user-stated / file:path / doc:path |

Maps to `planning_brief.constraints` and `planning_brief.planner_focus_cues`.

### Key Decisions

Surfaced decisions for do-plan to resolve. Not pre-decided here.

| ID | Question | Options | Door type |
|----|----------|---------|-----------|
| KD-N | [decision question] | A / B / C | one-way / two-way |

Maps to `planning_brief.key_decisions`.

### Unknowns

Remaining unknowns that could not be resolved during discussion.

| Unknown | Type | Severity | Impact |
|---------|------|----------|--------|
| [unknown] | context / codebase | blocking / advisory | [planning impact] |

Blocking unknowns become do-plan discovery targets.

### Constraints

Hard limits discovered during discussion. Bullet list:

- [constraint] — [evidence level] — [source]

Maps to `planning_brief.constraints`.

### Recommended Next Step

One of: `do-plan`, `brainstorming`, `do-debug`, `more-discuss`.
Include context note on which fields to seed into the next step.

## Conditionally Required Sections

Include when scope meets the stated condition. Omission requires explicit skip rationale.

### Codebase Signals

Required when tier-2 investigate phase was triggered.

| Finding | File / Symbol | Evidence | Relevance |
|---------|--------------|----------|-----------|
| [finding] | path/to/file | E2 | [why it matters] |

Maps to `planning_brief.evidence_manifest`.

## Optional Sections

Use when scope warrants. When present, each section's MUST-when-present rules apply.

### Discussion Learnings

Proposals for skill/agent/workflow improvements discovered during the discussion.
Never auto-applied — user must explicitly approve.

### Docs Impact

Early classification when determinable: `customer-facing`, `internal`, `both`, or `none`.
Do-plan reclassifies after discovery — this is advisory, not authoritative.
Maps to `planning_brief.docs_impact`.

## Evidence Expectations

| Claim type | Required level |
|-----------|----------------|
| Known fact | E1+ (user-stated or doc reference) |
| Codebase signal | E2+ (code reference) |
| Assumption | E0 (labeled explicitly) |
| Constraint | E1+ |
