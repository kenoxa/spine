# Frame Dispatch

## frame_artifact Schema

Handoff assembles this artifact from accumulated phase state. All fields required.

```yaml
frame_artifact:
  problem_statement: |
    # What is the problem
    Concrete, observable description. Symptoms, triggers, affected users/systems.
    Not a restatement of the user's request — the validated, sharpened version.
  constraints:
    # What limits the solution space
    - type: hard | soft | assumed
      description: "..."
      source: user | codebase | external  # where this constraint was discovered
      evidence: E0-E3 tag
  blast_radius:
    # What else in the codebase touches this
    direct: []       # files/modules directly affected
    transitive: []   # files/modules affected through dependencies
    external: []     # APIs, services, consumers outside the repo
  key_assumptions:
    # What we believe to be true but haven't fully verified
    - assumption: "..."
      status: settled | disputed  # settled = agreed; disputed = competing framings exist
      evidence: E0-E3 tag
  success_criteria:
    # How we know it's solved — use EARS notation
    - ears: "When [trigger], the system shall [behavior]."  # or While/If variants
      evidence: E0-E3 tag
      example: "..."  # 1 concrete instance reducing ambiguity (optional)
  key_unknowns:
    # What we don't know yet
    - unknown: "..."
      impact: blocking | informational
      feasibility_note: "..."  # 1-2 sentences max; no ranked options
```

### Forbidden Fields

Do not include: `proposed_solution`, `implementation_plan`, `preferred_approach`, `architecture_decision`, `technology_choice`. Strip from subagent findings; log scope violation.

### Feasibility Notes

`key_unknowns.feasibility_note` permits bounded feasibility context: 1-2 sentences stating what is known about whether a constraint can be met. No ranked options, no recommendations, no "we should use X."

Valid: "The framework exposes a plugin API that could address this; feasibility unconfirmed."
Invalid: "We should use the plugin API because it's simpler than forking."

## Phase Integration

### Field Mapping

Orient (run-explore): `key_findings` → `blast_radius.direct`/`transitive`. Navigator findings → `blast_radius.external` + external constraints.

Clarify (run-discuss): `discuss_artifact` projection:
- `known` (source: user) → `constraints` + `success_criteria`
- `open_questions` → `key_unknowns`
- `proposals` (confirmed) → `key_assumptions` with `settled` status

Investigate (adaptive skills): findings → `constraints`, `key_unknowns.feasibility_note`, refine `blast_radius`.

### Assembly

Main thread assembles `frame_artifact` at handoff. Write to `.scratch/<session>/frame-artifact.md`. Validate:

1. All 6 required fields present and non-empty (allow `blast_radius.direct`/`transitive` empty with `not_applicable` for non-repo contexts)
2. No forbidden fields
3. Blocking `key_unknowns` reflected in handoff confidence
4. Disputed `key_assumptions` reflected in handoff confidence (disputed assumptions = medium confidence max)
5. Evidence levels tagged on constraints and success criteria
6. `success_criteria` use EARS notation (When/While/If patterns)
7. `blast_radius` sourced from codebase evidence (E2+) when codebase-adjacent; E1/E0 acceptable for non-repo contexts

Validation failure -> do not emit handoff declaration; surface gaps to user.
