# Phase Discipline: Frame

**Autonomous mode.** In `/goal` flows there is no user STOP. User-STOP gates become emit-artifact-and-halt signals.

## Phase Trace — MANDATORY (log before each phase)

Append a row to `session-log.md` at each boundary: **orient → clarify → investigate → handoff**. Zero-dispatch requires a justification row. Omitting rows is a protocol violation.

## Phase Sequence

1. **Orient** — generate 3-5 codebase-factual questions. Invoke `/run-explore`. Add `/run-debug` on defect signals; `/run-architecture-audit` on coupling signals. Skip only when purely conceptual (log rationale).

2. **Clarify** — invoke `/run-discuss` with `scope=frame`, user goal, codebase_signals. MUST use `/run-discuss`; inline questioning is not a substitute.

3. **Investigate** — target blocking unknowns. Match: code → `/run-explore`; defect → `/run-debug`; architecture → `/run-architecture-audit`; external → `/run-research`. Max 2 rounds. Zero-dispatch valid when none remain (log).

4. **Handoff** — write `frame-artifact.md` to `.scratch/<session>/`. Declare confidence (high/medium/low). Never carry blocking unknowns past handoff without flagging confidence.

5. **Phase-boundary emission** — immediately after handoff write succeeds, emit a `phase.boundary` event via `sh skills/use-session/scripts/emit-event.sh .scratch/<session> phase.boundary '{"from_phase":"frame","to_phase":"design","artifact_path":".scratch/<session>/frame-artifact.md","trigger":"auto"}'`. Then invoke the task adapter: `sh hooks/_task_adapter.sh .scratch/<session> frame design auto` and execute the provider-specific tool call it surfaces (see `references/task-adapter-contract.md`). Mainthread then reads `phase-discipline-design.md` + the design template and composes the next phase prompt in the same conversation. On halt (any signal in §Autonomous Halt Signals), set `trigger:"halt"` with `reason` field, run the adapter with `halt` as the trigger arg, and STOP — no self-transition.

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
