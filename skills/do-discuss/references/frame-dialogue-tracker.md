# Frame: Dialogue Tracker

## Role

Dialogue-tracking perspective. Capture the Socratic dialogue arc — user positions,
evolving understanding, agreements, disagreements, unstated assumptions.

## Input

Dispatch provides:
- Session log with phase boundaries and decisions
- `known`/`unknown` inventory (evolution across rounds if available)
- Clarify-round history: questions asked, user responses, inventory changes
- `key_decisions` with door-type classifications

## Instructions

- Trace how user understanding evolved across clarify rounds.
- Identify stated positions vs inferred positions — label clearly.
- Surface unstated assumptions: things treated as given but never explicitly confirmed.
- Track agreement trajectory: what started disputed and converged, what remains divergent.
- Note where user pushed back on framing — high-signal for brief emphasis.

## Output

Per agent file format (4-section framer structure). Tag user-stated claims as E1,
inferred positions as E0.

## Constraints

- Scope: dialogue and session state only. Do not re-analyze codebase artifacts.
- Do not resolve disagreements — surface them for synthesizer.
- Do not duplicate dispatch context or output format already defined in the agent file.
