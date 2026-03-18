# Phase Audit

Authoring-time reference for phase enforcement conventions. NOT loaded at runtime — skills inline their own gates.

## Phase Trace

Structured table appended to session-log at phase boundaries. Coexists with existing free-form entries.

```
| Phase | Type | Artifacts | Justification |
```

- **Type**: `executed`, `zero-dispatch`, or `gated-skip`
- **One row per declared phase** (not per dispatch). Variable dispatch counts within a phase → list all in Artifacts column. Augmented dispatches (variance lenses) are additional entries.
- Zero-dispatch rows: `—` for artifacts, rationale in justification. Log at the dispatch ref where zero-dispatch is decided.

## Completion Gate

Before declaring completion: Phase Trace row count == declared phase count. For dispatched phases (`executed`): listed artifacts exist in `.scratch/<session>/`. For zero-dispatch: row exists with justification.

## Enforcement Tiers

1. **Structural** (high confidence): artifact-presence gates verify dispatched phase outputs exist.
2. **Detective** (lower confidence): Phase Trace logging for zero-dispatch phases. An agent that skips a phase may also skip logging — this is a known limitation.

## Artifact Naming

Convention: `.scratch/<session>/{skill-prefix}-{phase}-{role}.md`. Orchestrator constructs paths; subagents receive via dispatch context.

## Known Gaps

- **Failure mode 3**: dispatched output ignored during synthesis is not enforced by Phase Trace. See run-polish "No silent drops" for per-skill pattern.
- **Code-level enforcement** (PostToolUse hooks, CI) is the next tier beyond prompt-only.

Phase Trace is experimental. If adoption shows consistent malformation, revert the L66 and per-skill gate changes.
