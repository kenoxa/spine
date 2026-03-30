---
name: do
description: >
  Catch-all entry point for features, bugs, issues, ideas, questions.
  Use when: "do", "fix", "add", "change", "build this", "implement this",
  "solve this", "help me with this", or any actionable request that doesn't
  match a specific skill.
  Do NOT use when: already inside a phase skill (do-frame, do-design, do-build).
argument-hint: "[task, problem, feature, bug, question, or idea]"
---

Route through phase skills, track progress. Phases run interactively on mainthread, never as subagents.

## Session

Generate session ID at entry per SPINE.md (`{slug}-{hash}`). Persist state in `.scratch/<session>/session-log.md`. After `/clear` or compaction, re-read session-log to restore state before continuing.

## State Machine

```
START ──► /do-frame ──► /do-design ──► /do-build ──► DONE
             (WHAT)          (HOW)       (BUILD+REVIEW)
```

Each transition requires user confirmation. Suggest next phase; never auto-advance.

## Routing

Assess input against skip criteria. Default: start at `/do-frame`.

| Skip | Criteria | Required in input |
|------|----------|-------------------|
| frame | Problem already clear | Explicit problem statement with constraints and blast radius |
| design | Direction already clear | Explicit approach/direction statement |
| both | Ready to build | Both of the above |

When skip criteria are met, state the skip rationale and suggest the target phase. User confirms.

## Phase Handoff

After each phase completes:

1. Read phase output from `.scratch/<session>/` artifacts
2. State current position in the machine
3. Suggest next phase (or completion)
4. STOP -- user decides

## Anti-Patterns

- Invoking phase skills as subagents (they are interactive, need mainthread)
- Auto-advancing without user confirmation
- Skipping phases without validating skip criteria against actual input
- Running analysis when user has a clear problem + direction + wants to build
- Reading phase outputs from session-log (outputs live in `.scratch/<session>/` files; session-log tracks decisions only)
