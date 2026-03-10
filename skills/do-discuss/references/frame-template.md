# Frame Template

## Self-Sufficiency Contract

Frames MUST be understandable without chat-history context. All claims cite evidence source.
Terms are defined where first used. No references to prior conversation turns.

## Required Sections

**Planning brief mappings** — sections map to `planning_brief` fields as follows:

| Section | `planning_brief.*` field |
|---------|--------------------------|
| Goal | `goal` |
| Scope | `scope` |
| Known Facts | `constraints`, `planner_focus_cues` |
| Key Decisions | `key_decisions` |
| Constraints | `constraints` |
| Codebase Signals | `evidence_manifest` |
| Docs Impact | `docs_impact` |

### Session
Session ID in `{slug}-{hash}` format — 5–7 word slug, 4-char hex via `openssl rand -hex 2` (e.g., `fix-session-slug-length-validation-7d3f`). Carried forward into do-plan.

### Confidence
One of: `low`, `medium`, `high`

| Level | Meaning | Recommended next step |
|-------|---------|----------------------|
| `high` | Answered, no blocking unknowns | `do-plan` |
| `medium` | Answered, open assumptions remain | `do-plan` (with caveats) |
| `low` | Not fully answerable | `brainstorming` or more discussion |

### Frame Question
Single question whose answer unblocks planning. Specific (names affected system/behavior), answerable (finite options), scoped (enables planning directly).

### Goal
One-sentence problem restatement, disambiguated by discussion.

### Problem Statement
2–4 sentences elaborating the problem and why-now. Must include:
- What exists today (confirmed)
- What is failing or missing (confirmed or labeled as assumed)
- What the user wants instead

### Scope
| Dimension | In | Out |
|-----------|-----|-----|
| [area] | [included] | [excluded] |

### Known Facts
Confirmed claims with evidence level tags.

| Fact | Evidence | Source |
|------|----------|--------|
| [claim] | E0/E1/E2/E3 | user-stated / file:path / doc:path |

### Key Decisions
Decisions for do-plan to resolve. Not pre-decided.

| ID | Question | Options | Door type |
|----|----------|---------|-----------|
| KD-N | [decision question] | A / B / C | one-way / two-way |

### Unknowns
| Unknown | Type | Severity | Impact |
|---------|------|----------|--------|
| [unknown] | context / codebase | blocking / advisory | [planning impact] |

Blocking unknowns become do-plan discovery targets.

### Constraints
Hard limits from discussion:
- [constraint] — [evidence level] — [source]

### Recommended Next Step
One of: `do-plan`, `brainstorming`, `do-debug`, `more-discuss`. Note which fields to seed into next step.

## Conditionally Required Sections

Include when condition met. Omission requires explicit skip rationale.

### Codebase Signals
Required when tier-2 investigate phase triggered.

| Finding | File / Symbol | Evidence | Relevance |
|---------|--------------|----------|-----------|
| [finding] | path/to/file | E2 | [why it matters] |

## Optional Sections

Include when scope warrants. MUST-when-present rules apply.

### Discussion Learnings
Proposals for skill/agent/workflow improvements from discussion. Never auto-applied — user must approve.

### Docs Impact
Early classification: `customer-facing`, `internal`, `both`, or `none`. Advisory — do-plan reclassifies after discovery.

## Evidence Expectations

| Claim type | Required level |
|-----------|----------------|
| Known fact | E1+ (user-stated or doc reference) |
| Codebase signal | E2+ (code reference) |
| Assumption | E0 (labeled explicitly) |
| Constraint | E1+ |
