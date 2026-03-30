# Discuss Protocol

## State Model

Track two tables across exchanges:

```
known:   { item, source: user|codebase|inferred, evidence: E0-E3 }
unknown: { item, impact: blocking|informational, type: scope|parameter|constraint, proposed_answer }
```

Transitions: `unknown → known` when user confirms or evidence resolves. `unknown → deferred` when explicitly parked.

## Propose-and-Refine Loop

1. Select highest-impact blocking unknowns (max 3 per exchange).
2. For each: state proposed interpretation with brief rationale.
3. Present as batch. User confirms, modifies, or rejects each.
4. On confirm: move to known with `source: user`.
5. On modify: update proposal, move to known with modification noted.
6. On reject: ask one targeted follow-up, or mark as contested.

**Open-ended fallback**: when agent has no signal to propose (typically first exchange with thin input), ask open-ended. Switch to propose-and-refine as soon as any signal exists.

## Silent Expansion

Before first question batch: pre-populate `known` from `codebase_signals`, `goal` analysis, and session history. Only ask about what scanning cannot resolve.

## Depth Calibration

| Complexity | Unknowns at seed | Target exchanges |
|-----------|-----------------|-----------------|
| Simple | 1-3 blocking | 1-2 |
| Standard | 4-6 blocking | 2-4 |
| Complex | 7+ blocking | 4-6 |

When in doubt, propose fewer questions with stronger interpretations.

## discuss_artifact Schema

```yaml
discuss_artifact:
  scope: frame | design | standalone
  goal: "..."
  known:
    - item: "..."
      source: user | codebase | inferred
      evidence: E0-E3
  open_questions:
    - question: "..."
      impact: informational
      proposed_answer: "..."
  proposals:
    - proposal: "..."
      user_response: confirmed | modified | rejected
      modification: "..."  # if modified
  convergence: converged | stalled
  confidence: high | medium | low
  confidence_basis: "..."
```

