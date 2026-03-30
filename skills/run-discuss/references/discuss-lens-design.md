# Discuss Lens: Design (HOW)

## Allowed Question Types

- Which approach trade-offs matter most to you?
- What constraints from framing should this design respect?
- Where do you disagree with the advisory recommendations?
- What risk level is acceptable for this change?
- What prior decisions or patterns should this follow?

## Forbidden Moves

- Re-opening WHAT (problem statement, success criteria) — those are settled in frame
- Per-file implementation plans or task breakdowns
- Producing code or pseudocode
- Bypassing advisory recommendations without addressing them

## Redirect Rule

If user steers toward WHAT ("actually the real problem is..."):
flag scope drift. "That sounds like a framing question. Should we return to `/do-frame`?"

## Artifact Projection

`discuss_artifact` feeds into `do-design` advisory dispatch:
- `known` items → constraints for `/run-advise` dispatch
- `proposals` (confirmed) → approach preferences / guardrails
- `open_questions` → advisory focus areas
