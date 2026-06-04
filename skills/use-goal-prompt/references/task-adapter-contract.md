# Task-Adapter Contract (Slice B)

The installed Spine task adapter is a provider-aware shim invoked by
mainthread immediately after every `phase.boundary` event lands in
`events.jsonl`. Its job is to surface the transition in the active provider's
task tracker so the user sees progress at a glance.

## Invocation

```sh
sh "${SPINE_HOME:-$HOME/.config/spine}/hooks/_env.sh" _task_adapter.sh .scratch/<session> <from_phase> <to_phase> <trigger>
```

- `<from_phase>`: `frame`, `design`, `build`, or the literal `null` for the initial boundary.
- `<to_phase>`: `design`, `build`, or `complete`.
- `<trigger>`: `auto`, `user`, or `halt`.

Do not call a project-local `hooks/` path. Project checkouts usually do not
contain Spine hooks; the installed wrapper above works from any checkout and
loads `~/.config/spine/.env` before dispatching the adapter.

The shim writes a `task.adapter` event (audit trail) into the same
`events.jsonl`, then prints the detected provider on stdout and the suggested
next-action on stderr.

## Per-provider mainthread responsibilities

After the shim returns its `provider=<X>` line, mainthread MUST execute the
provider-specific tool call below. The shim does not (and cannot) issue
model-side tool calls — those have to come from mainthread.

| Provider | Auto-transition | Halt |
|---|---|---|
| `claude-code` | `TaskUpdate(prev → completed)`; `TaskCreate(next phase, in_progress)` | `TaskUpdate(current → completed-with-reason or blocked)` |
| `codex` | `update_plan`: prev step → `completed`; next step → `in_progress` | `update_plan`: current → `in_progress` + note halt reason |
| `cursor` | Shim already appended a Phase Trace stub to `session-log.md`. Mainthread reads it as confirmation; no extra action. | Same — log-only, halt-row appended automatically. |
| `opencode` | TBD (planned: `opencode/spine-hooks.ts` shim — currently no-op). | TBD. |
| `unknown` | No-op — the workflow still terminates correctly; only the task-tracker UX is missing. | No-op. |

## Provider detection

The shim probes env vars in this order:
1. `SPINE_PROVIDER` set to `claude-code`, `codex`, `cursor`, `opencode`, or `unknown` → explicit override
2. `CLAUDECODE=1` or `CLAUDE_CODE_VERSION` set → `claude-code`
3. `CODEX_HOME`, `CODEX_EXEC`, `CODEX_SANDBOX`, `CODEX_THREAD_ID`, or `CODEX_CI` set → `codex`
4. `SPINE_PROVIDER_IS_CURSOR=1` (exported by `_env.sh`) → `cursor`
5. `OPENCODE_PROJECT_ROOT` set → `opencode`
6. Otherwise → `unknown`

Codex shells that expose none of the native `CODEX_*` signals should run the
canonical invocation with `SPINE_PROVIDER=codex`.

## Install-layout decision

Spine hooks are installed under `${SPINE_HOME:-$HOME/.config/spine}/hooks`.
Spine skills are installed separately under
`${SPINE_SKILLS_DIR:-$HOME/.agents/skills}`. The adapter therefore lives behind
the installed `_env.sh` wrapper and resolves `use-session`'s `emit-event.sh`
from the installed skills root, while still supporting source-tree execution
for local tests.

## Failure mode

If `emit-event.sh` is unreachable (install drift), the shim still detects the
provider and prints the next-action line — only the audit-trail event is
skipped. The workflow continues.

## Anti-patterns

- Mainthread calling `TaskCreate` without the prior shim invocation: bypasses
  the audit trail in `events.jsonl`.
- Sub-agents calling the adapter: violates C3 (single active writer). Only
  mainthread emits boundary events and dispatches the adapter.
- Treating the shim's stdout as a substitute for the actual tool call: the
  shim is advisory; the tool call must still happen.
