# Frame Template

## Self-Sufficiency Contract

Frames MUST be understandable without chat-history context. Claims cite evidence; terms defined at first use. No references to prior conversation turns.

Target ~80 lines. Longer signals unresolved ambiguity or prose-table duplication.

## Required Sections

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
| `high` | No blocking unknowns | `do-plan` |
| `medium` | Open assumptions remain | `do-plan` (with caveats) |
| `low` | Not fully answerable | `brainstorming` or more discussion |

### Frame Question
Question whose answer unblocks planning. Specific (names affected system/behavior), answerable (finite options), scoped (enables planning directly).

### Goal
One-sentence problem restatement, disambiguated by discussion.

### Problem Statement
2-4 sentences. Cover: what exists (confirmed), what fails/missing (confirmed or labeled assumed), what user wants.

### Scope
| Dimension | In | Out |
|-----------|-----|-----|
| [area] | [included] | [excluded] |

### Known Facts

| Fact | Evidence | Source |
|------|----------|--------|
| [claim] | E0/E1/E2/E3 | user-stated / file:path / doc:path |

### Key Decisions

| ID | Question | Options | Door type |
|----|----------|---------|-----------|
| KD-N | [decision question] | A / B / C | one-way / two-way |

### Unknowns
| Unknown | Type | Severity | Impact |
|---------|------|----------|--------|
| [unknown] | context / codebase | blocking / advisory | [planning impact] |

Blocking unknowns become do-plan discovery targets.

### Constraints
- [constraint] — [evidence level] — [source]

### Recommended Next Step
One of: `do-plan`, `brainstorming`, `run-debug`, `more-discuss`. Note which fields to seed into next step.

## Conditionally Required Sections

Include when condition met. Omit only with skip rationale.

### Codebase Signals
Required when tier-2 investigate phase triggered.

| Finding | File / Symbol | Evidence | Relevance |
|---------|--------------|----------|-----------|
| [finding] | path/to/file | E2 | [why it matters] |

## Optional Sections

Include when scope warrants. MUST-when-present rules apply.

### Discussion Learnings
Proposals — never auto-applied, user approves.

### Docs Impact
Early classification: `customer-facing`, `internal`, `both`, or `none`. Advisory — do-plan reclassifies after discovery.

## Evidence Expectations

| Claim type | Required level |
|-----------|----------------|
| Known fact | E1+ (user-stated or doc reference) |
| Codebase signal | E2+ (code reference) |
| Assumption | E0 (labeled explicitly) |
| Constraint | E1+ |
