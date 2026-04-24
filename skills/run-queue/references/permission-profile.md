# Permission Profile

run-queue does **not** replace your Claude settings. It inherits whatever permission posture is already in `~/.claude/settings.json` (or project/local equivalents) and layers a narrow, queue-specific overlay on top. The overlay exists because overnight autonomous runs have stricter trust needs than interactive sessions — not because the interactive baseline is wrong.

## Layered Model

1. **Global / project settings** (`~/.claude/settings.json`, `.claude/settings.json`). Source of truth for cross-cutting allow/deny/ask rules, MCP access, the existing PreToolUse hook (e.g. `rtk hook claude` → `hooks/guard-shell.sh`). Applied to every `claude -p` invocation the supervisor spawns.

2. **Bundled skill overlay** (`skills/run-queue/settings-overlay.tmpl.json` + `skills/run-queue/scripts/guard-queue-shell.sh`). The supervisor renders the template with the absolute path to the bundled hook, writes `<queue-dir>/.run-queue-settings.json`, and passes `claude -p --settings <that-file>`. The `--settings` flag is additive — it augments user/project settings rather than replacing them. The bundled hook registration ONLY fires for queue runs because only queue runs pass the overlay. Defense-in-depth: the hook still env-gates on `SPINE_QUEUE=1` in case the overlay leaks into an unrelated invocation.

3. **Per-queue profile** (`<queue-dir>/profile.json`, optional). A tiny declarative file the hook reads for rules that vary across runs (extra deny patterns, allowed-out-of-repo paths). Absent profile → the hook falls back to built-in defaults (below). Most queues will not need a profile at all.

The skill is self-contained: installing run-queue installs its hook. No changes to the project `claude/hooks.json` or `opencode/spine-hooks.ts` are required.

## What the queue overlay adds beyond global settings

Only rules that matter specifically for overnight autonomous execution and are NOT appropriate as global defaults:

| Rule | Why not global? |
|------|-----------------|
| Deny **all** `git push` (not just `--force`) | Interactive sessions routinely push; overnight runs should never publish. |
| Deny writes outside the queue's repo root | Interactive sessions often span repos; queue tasks are project-scoped. |
| Deny `git -C /path` (sidestep for out-of-project git ops) | Same reason as above. |
| Attribute trip-wire events to `agent_id` / `agent_type` when present | Specific to the queue's post-run forensic story; not useful interactively. |
| Write `WOKE-ME-UP.md` into the queue directory on any deny | Specific to the queue's halt-and-signal mechanism. |

Everything else — recursive `rm`, docker escapes, curl uploads, package publishes, etc. — is already covered by your global hook and is not duplicated here.

## `profile.json` — Optional, Minimal

Schema v1. Shipping without a `profile.json` is the expected default.

```json
{
  "schema_version": "1",
  "extra_deny": [
    { "match": "Bash", "command_prefix": "aws s3 cp",
      "reason": "this queue should not touch S3" }
  ],
  "allow_out_of_repo": [
    "/tmp/spine-queue/"
  ]
}
```

| Field | Purpose |
|-------|---------|
| `schema_version` | `"1"`. |
| `extra_deny[]` | Additional deny patterns layered on top of built-in queue denies. Same match semantics as below. |
| `allow_out_of_repo[]` | Absolute paths permitted for Edit/Write despite the default "writes confined to repo" rule. Paths are matched as prefixes. |

## Built-in queue denies (no profile needed)

The hook's fail-secure defaults — applied whenever it fires with `SPINE_QUEUE=1`:

```
Bash command_prefix  "git push"             → deny (all push, not just force)
Bash command_prefix  "git -C "              → deny (out-of-project git)
Edit/Write path      outside repo root      → deny (unless allow_out_of_repo matches)
```

The `path_prefix` and `command_prefix`/`command_regex` semantics match `guard-shell.sh` — normalization collapses whitespace and strips `rtk ` proxy prefix.

## Fail-secure contract

The supervisor refuses to start when:

- `SPINE_QUEUE=1` is not set in its environment (user bypassed the arming step).
- `skills/run-queue/scripts/guard-queue-shell.sh` is missing or not executable.
- `skills/run-queue/settings-overlay.tmpl.json` is missing or the rendered overlay fails JSON validation.

These are configuration errors — not user-recoverable at runtime. Every deny path ends with an explicit `exit 2` + stderr line.

## Trip-wire behavior

On any deny, the hook:

1. Appends a structured line to `<queue-dir>/queue-log.md` — tool, command, reason, `agent_id` when the caller is a subagent.
2. Creates (or appends to) `<queue-dir>/WOKE-ME-UP.md` — task id, timestamp, reason. First deny also stamps the file header.
3. Emits `permissionDecision: deny` JSON + exits 2 — the tool call is blocked.
4. Child `claude -p` reports the block; supervisor observes non-`complete` terminal status.
5. Supervisor halts the queue — no further tasks spawn. Failed task branches preserved for inspection. `queue-report.md` flags the trip-wire prominently.

Halt-on-any-deny is deliberate: false negatives overnight are costlier than false positives. Morning review decides whether the deny was correct.

## Env contract with the supervisor

The hook discovers the queue context from env vars that run.sh exports into the child:

| Env var | Purpose |
|---------|---------|
| `SPINE_QUEUE=1` | Arms the hook. Without it, the hook is inert. |
| `SPINE_QUEUE_DIR` | Absolute path of the queue directory. Hook reads `profile.json` from here and writes `WOKE-ME-UP.md` / appends `queue-log.md` here. |
| `SPINE_QUEUE_RUN_ID` | Run id for attribution. |
| `SPINE_QUEUE_TASK_ID` | Current task id for attribution. |

All four must be present when the hook fires with `SPINE_QUEUE=1`. Missing → fail-secure deny with a diagnostic reason.
