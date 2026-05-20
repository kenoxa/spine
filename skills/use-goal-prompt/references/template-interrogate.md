# Template: Ideation / Interrogation

**When**: user has a vague or semi-formed idea and needs a structured intake interview that translates fuzzy language into concrete artifacts before any docs, plans, or code are written.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**Must-ask inputs**: `[topic]`. Everything else below is a proven scaffold — adapt it to the topic.

```
GOAL:
Interrogate the user's idea exhaustively until zero assumptions remain, then output a complete build-ready brief.

CONTEXT:
User has a vague or semi-formed idea about [topic] and needs a structured intake interview that translates fuzzy language into concrete artifacts before any docs, plans, or code are written.
User is assumed non-technical unless they signal otherwise.
Use the `/do-frame` skill to conduct the interview.

CONSTRAINTS:
Do not write code, generate docs, or propose plans during the interview phase.
Do not assume, infer, or fill gaps with "reasonable defaults."
Do not stack questions. One question per turn.
Do not declare the interview complete until every item in DONE WHEN is satisfied.

PRIORITY:
1. Zero assumptions remaining
2. Every vague noun translated into a concrete artifact
3. Failure modes, edge cases, non-goals, and regulatory exposure surfaced

PLAN:
Start broad: problem, user or integration surface, success criteria.
Drill on every vague answer. Push back on "something modern" or "users can log in" with specific follow-ups.
Surface regulatory, compliance, and data-handling requirements if the domain implies them (healthcare, finance, EU users, enterprise sales, government, education).
Refresh a running summary every 5-7 turns of what's been established.
Surface hidden assumptions out loud. Name them. Confirm or correct.

DONE WHEN:
Failure modes enumerated (what breaks, when, how).
Edge cases surfaced (empty states, error states, abuse cases).
Success metrics are measurable, not vibes.
Scope boundaries explicit, including non-goals.
Regulatory, compliance, and data-handling requirements surfaced or confirmed not applicable.
User has explicitly confirmed the final brief.

VERIFY:
Re-read the final brief against the DONE WHEN list. Confirm each item.
State any item that could not be verified and why.

OUTPUT:
Final brief in this structure:
- Problem (one paragraph)
- Target user OR primary integration surface (specific, not "people"; for libraries, tools, infrastructure, name the consuming engineer or system)
- Primary user action OR primary integration contract
- Success criteria (measurable)
- Scope (in)
- Non-goals (out)
- Known constraints
- Regulatory and compliance requirements (or explicitly noted as not applicable)
- Open risks
- Assumptions awaiting confirmation

STOP RULES:
Halt and surface the gap when an answer would require inventing scope, audience, or success criteria.
Surface uncertainties together with ranked highest-confidence proposals, not open-ended clarification questions.
Do not transition to documentation or planning after the brief is confirmed.
```
