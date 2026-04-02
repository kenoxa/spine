# Advise: Envoy

CLI dispatcher — external prompt assembly only; never self-answer. Advisory batch phase.

## Dispatch Parameters
- mode: multi
- tier: frontier

## Input

### First round

Dispatch prompt provides:
- `{source_artifact_path}` — repo-relative; same file `advise-synthesis` reads (decision object). List in prompt; provider reads file. Prefer path over redundant inline excerpts when both exist.
- `frame_artifact`, `problem_context`, or advisory question — supplementary if not redundant with source file.
- `active_lenses` -- variance lens name(s) and focus directive(s), when present. Include in the assembled prompt so external providers weight their analysis accordingly.
- `{output_path}` -- routing metadata for run.sh output

### Re-dispatch

All first-round inputs (including `{source_artifact_path}`), plus:
- `prior_round_dir` -- path to archived round directory (e.g., `advise-r1/`). Read prior synthesis at `{prior_round_dir}/advise-synthesis.md`.
- `user_pushback` -- user feedback on prior round

## Instructions

### First round

Assemble prompt content in this order:
1. **Authoritative source** -- repo-relative `{source_artifact_path}` (required when dispatch provides it). Instruct the external provider to read that file as the shared decision object for this advisory round, consistent with internal consultants and synthesis.
2. Problem context -- inline `frame_artifact` fields, freeform problem statement, or advisory question, when they add lens or emphasis beyond the source file
3. Instruction: "Given this problem, what approach would you take? Provide an independent external perspective. Surface tradeoffs and risks."

### Re-dispatch

Assemble prompt content in this order:
1. **Authoritative source** -- same `{source_artifact_path}` as first round (still the decision object)
2. Problem context -- same as first round
3. Prior round synthesis (read from `{prior_round_dir}/advise-synthesis.md`) + user pushback
4. Instruction: "Given this problem, the prior round's internal recommendations, and the user's pushback, what approach would you take? Where do you agree/disagree? Surface tradeoffs the prior recommendations may have missed."

## Output

Include this 5-section structure as the output format:
1. **Angle summary** -- external perspective and approach rationale
2. **Recommended approach** -- direction with rationale
3. **External perspective** (first round) / **Agreement/disagreement** (re-dispatch) -- independent take on the problem, or where this aligns/diverges from prior round
4. **Tradeoffs** -- what other perspectives may have missed
5. **Confidence** -- self-assessed confidence per section (high/medium/low)

## Constraints

- Cite angles by name (rigorous, creative, navigator, envoy), not by file path.
- Repo-relative paths only; no file-body inline. Include `{source_artifact_path}` when provided.
- Self-contained prompt — no session-internal-only refs.
- Use `mode` and `tier` from `## Dispatch Parameters` as `--mode` and `--tier` flags on `run.sh` invocation
