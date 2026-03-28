# Build: Finalize

## Role

Sole completion authority (mainthread-only). Evaluates prototype completion, proposes learnings, declares outcome.

## Input

- `review_result` — ACCEPT or ITERATE with specifics (from review synthesis)
- `files_modified` — repo-relative list of all changed files
- `input_source` — original plan or consult recommendation
- `scope_artifact` — target files, partitions

## Instructions

### 1. Question Answered

Evaluate whether the build addressed the original intent:

| Assessment | Criteria |
|------------|----------|
| `yes` | Build fully addresses the plan tasks or consult recommendation |
| `partially` | Core intent addressed but notable gaps remain |
| `no` | Build does not answer the original question or recommendation |

When `partially` or `no`: suggest re-direction to `/do-consult` to reframe the problem before another build attempt. State what was missed and why re-framing may help.

### 2. Prototype Completion Gates

**Precondition**: Phase Trace has rows for scope, implement, review, review-gate, polish; expected artifacts exist.

Gate applies on ACCEPT only. On ITERATE (cap reached), skip to completion declaration.

| Gate | Criteria |
|------|----------|
| Builds/parses | Changed files are syntactically valid |
| Intent met | Implementation matches input source intent |

No mandatory test or documentation gates. Surface test/doc suggestions as learnings, not blockers.

### 3. Learnings

Identify `build_learnings` on ALL outcomes (ACCEPT, cap-reached, partial) — not only on ACCEPT. Failed/capped builds often contain the most valuable learnings.

For each learning, capture structured fields:
- `what_was_attempted` — approach or assumption tested
- `result` — succeeded, failed, or partially worked
- `assumption_corrected` — what we now know to be true/false (if applicable)
- `memory_candidate` — yes/no: should this persist as a memory entry?

Categories: skill updates, memory entries, rule changes, spec corrections, constraint discoveries.

Propose only — never auto-apply. User must approve each update before it is written.

### 4. Completion Declaration

- **ACCEPT + gates met + question answered `yes`**: `Build complete.`
- **ACCEPT + gates met + question answered `partially`**: `Build complete (partial).` — list gaps; suggest `/do-consult` for reframing.
- **ACCEPT + question answered `no`**: `Build NOT complete.` — explain mismatch; suggest `/do-consult`.
- **ITERATE (cap reached)**: `Build NOT complete.` — list remaining blockers from review.

### 5. Session Log

Append: completion declaration, question-answered assessment, final `files_modified`, learnings proposals if any, open items.

## Constraints

- Never declare `Build complete.` without evaluating question-answered assessment.
- Never auto-apply learnings — proposal only, user approval required.
- No mandatory test/doc content gates. Surface test/doc suggestions as learnings, not blockers.
- Gate completion declaration on ACCEPT. Surface learnings on ALL outcomes (ACCEPT, cap-reached, partial).
