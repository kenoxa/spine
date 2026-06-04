# Phase Discipline: Build

**Autonomous mode.** In `/goal` flows there is no user STOP. User-STOP gates become emit-artifact-and-halt signals.

## Phase Trace — MANDATORY (log before each dispatch)

Append a row to `session-log.md` at EVERY boundary: **each slice boundary AND each dispatch boundary**. Omitting rows is a protocol violation.

## Slice Invariant

Execute slices in declared order. NEVER advance past a slice without E3 exit gate.

## Per-Slice Loop

1. **Implement** — invoke `@implementer` with slice scope.
2. **Review** — invoke `@inspector`. Binary gate: PASS → advance; BLOCKED → invoke `/run-polish` (max 3 polish iterations per slice), then re-review.
3. **Cap** — 5 review iterations per slice. At cap: write `build-status.json` `status=blocked`, halt.
4. **Exit gate (E3)** — verify deliverables exist at declared paths.

## Terminal Outcome — ALWAYS write build-status.json

Write atomically to `.scratch/<session>/build-status.json` on EVERY outcome (pass/blocked/failed):
`{ session, slice, status, reason, evidence: [...], learnings: [...], next }`

**Learnings field is MANDATORY regardless of outcome.**

- **Emitter**: mainthread/orchestrator writes `build-status.json` only after all verification phases complete. Subagents (implementer/inspector/envoy) NEVER write the terminal artifact — they emit their own role-specific outputs, and mainthread synthesizes the final status.

## Phase-Boundary Emission + Terminal Curate Gate

Immediately BEFORE writing the terminal `build-status.json`:

1. Emit a `phase.boundary` event with `to_phase:"complete"` via `sh "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/use-session/scripts/emit-event.sh" .scratch/<session> phase.boundary '{"from_phase":"build","to_phase":"complete","artifact_path":".scratch/<session>/build-status.json","trigger":"auto"}'`.
2. Invoke the task adapter via the installed Spine hook wrapper: `sh "${SPINE_HOME:-$HOME/.config/spine}/hooks/_env.sh" _task_adapter.sh .scratch/<session> build complete auto` and execute the provider-specific tool call it surfaces (see `references/task-adapter-contract.md`).
3. Invoke the curate terminal gate: `/run-curate --terminal --session=<id>` (which runs `sh "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-curate/scripts/terminal-gate.sh" .scratch/<session>` to write `curate-report.md`, then optionally augments with AI synthesis under a 60s budget). Reference the report in `build-status.json` as `learnings.curate_report` + `learnings.curate_status`.

On halt (review cap, slice exit gate fail, scope expansion), set `trigger:"halt"` with `reason` field BEFORE the build-status write, run the adapter with `halt`, SKIP the curate gate, and STOP — no further slices, no autonomous re-launch.

## Refuse

Adjacent refactors, backcompat shims, scope creep — refuse immediately and surface to user.

## Autonomous Halt Signals

| Signal | Action |
|--------|--------|
| review cap reached (5) | build-status blocked → halt |
| slice exit gate fails | build-status blocked → halt |
| scope expansion detected | refuse → surface to user → halt |
