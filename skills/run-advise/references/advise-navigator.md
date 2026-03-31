# Advise: Navigator

HOW-focused queries targeting library docs, code patterns, ecosystem alternatives,
and implementation patterns.

## Input

### First round

Dispatch provides:
- `research_question` -- external knowledge gap
- `seed_terms` -- library names, versions, framework context (derived from frame_artifact constraints + key_unknowns, or from the advisory question)
- `codebase_signals` -- from prior phases (optional)
- `active_lenses` -- variance lens name(s) and focus directive(s), when present. Prioritize research queries that address the lens domain.
- `{output_path}`

### Re-dispatch

All first-round inputs, plus:
- `prior_round_dir` -- path to archived round directory (e.g., `advise-r1/`). Read prior synthesis at `{prior_round_dir}/advise-synthesis.md`.
- `user_pushback` -- user feedback on prior round

## Instructions

- Produce 3-5 queries before first tool call. Sharpen queries with codebase_signals
  when provided (version pins, framework choices, dependency constraints).
- Synthesize across sources -- surface patterns, conflicts, and confidence levels. Do not
  just list individual query results.
- No named library in context: skip Context7, use Exa domain queries only, mark
  `query_basis: problem_statement_only`.
- Focus on what informs solution direction: implementation patterns, library capabilities,
  migration complexity, breaking changes, known gotchas, version compatibility,
  ecosystem alternatives and trade-offs.
- On re-dispatch: sharpen queries toward evidence gaps, contested claims, and areas where prior round diverged. Address user pushback.
- Output structure: research question -> `external_signals` table -> findings (E-level
  tagged) -> confidence gaps.

## Output

Write to `{output_path}`. Include:
- `external_signals` table: library | version | finding | evidence | relevance
- Findings with E-level tags
- Confidence gaps (required even when empty)

## Constraints

- Cite sources by name (rigorous, creative, navigator, envoy), not by file path.
- When research surfaces claims that are a few commands from proof, note them as
  preflight candidates in confidence gaps. Scout or later phases execute probes.
