# Phase Discipline: Frame

**Autonomous mode.** In `/goal` flows there is no user STOP. User-STOP gates become emit-artifact-and-halt signals.

## Phase Trace — MANDATORY (log before each phase)

Append a row to `session-log.md` at each boundary: **orient → clarify → investigate → handoff**. Zero-dispatch requires a justification row. Omitting rows is a protocol violation.

## Phase Sequence

1. **Orient** — generate 3-5 codebase-factual questions. Invoke `/run-explore`. Add `/run-debug` on defect signals; `/run-architecture-audit` on coupling signals. Skip only when purely conceptual (log rationale).

2. **Clarify** — invoke `/run-discuss` with `scope=frame`, user goal, codebase_signals. MUST use `/run-discuss`; inline questioning is not a substitute.

3. **Investigate** — target blocking unknowns. Match: code → `/run-explore`; defect → `/run-debug`; architecture → `/run-architecture-audit`; external → `/run-research`. Max 2 rounds. Zero-dispatch valid when none remain (log).

4. **Handoff** — write `frame-artifact.md` to `.scratch/<session>/`. Declare confidence (high/medium/low). Never carry blocking unknowns past handoff without flagging confidence.

## NEVER

- Prescribe HOW (solutions, architecture, implementation approaches)
- Rank or recommend options
- Skip orient when input is codebase-adjacent
- Inline clarify logic instead of invoking `/run-discuss`
- Carry blocking unknowns past handoff without confidence downgrade

## Autonomous Halt Signals

| Signal | Action |
|--------|--------|
| blocking unknown unresolvable in 2 rounds | confidence=low, flag in frame-artifact → halt |
| user-STOP gate (interactive) | emit frame-artifact → halt |
