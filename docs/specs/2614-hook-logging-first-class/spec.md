# Hook Logging First-Class

**Spec ID:** 2614-hook-logging-first-class
**Session:** hook-logging-first-class-jsonl-4de3
**Status:** framed — ready for design

## Problem

Spine hook diagnostic logging exists (added during cross-provider-hooks-8435) but is provisional: TSV format to `~/.spine-hooks.log`, unbounded growth, no toggle, timestamp precision inconsistency between shell (seconds) and TS (ms) hooks, and a location outside the spine config tree. Useful for debugging hook behavior across providers, but currently requires manual cleanup and lacks structured queryability (no jq-over-JSONL). The logging needs to become a first-class, on-demand diagnostic tool: toggleable without ceremony, JSONL-structured, rotated automatically, and consistent across all 4 hooks.

## Constraints

| Type | Constraint | Source | Evidence |
|------|-----------|--------|----------|
| hard | Log at `~/.config/spine/logs/hooks.jsonl` — inside spine config tree | user | E0 |
| hard | Toggle: `SPINE_HOOK_LOG=1` in `~/.config/spine/.env` (sourced by `_env.sh`); ephemeral shell export also works | user | E2 |
| hard | JSONL fields: `{ts: ISO-8601-ms, event, hook, tool}` | user | E0 |
| hard | Rotation: ~500 KB cap, rolling window of 2 rotated files (3 total max) | user | E0 |
| hard | Consistent JSONL schema across sh and TS hooks | user | E0 |
| soft | `jq` already required by guard-shell + guard-read-large; check-on-edit does not currently use it | codebase | E2 |
| assumed | Fail-open: logging failures must never block tool calls | inferred | E0 |

## Blast Radius

**Direct:**
- `hooks/guard-shell.sh` — replace TSV printf (line 10)
- `hooks/guard-read-large.sh` — replace TSV printf (line 7)
- `hooks/check-on-edit.sh` — replace TSV printf (line 10)
- `hooks/inject-types-on-read.ts` — replace appendFileSync TSV (line 133)
- `hooks/_env.sh` — candidate for shared `spine_log()` shell function
- `install.sh` — must create `~/.config/spine/logs/` on install

**Transitive:**
- `~/.config/spine/.env` — toggle lives here; `.env.example` needs documenting
- `~/.config/spine/hooks/` — installed copies updated via install.sh

**External:**
- `~/.spine-hooks.log` — current log location; superseded (not deleted)

## Key Assumptions

| Assumption | Status |
|-----------|--------|
| `SPINE_HOOK_LOG=1` in `.env` is sufficient toggle without ceremony | settled |
| ISO-8601-ms resolves seconds/ms inconsistency and is human-readable | settled |
| 500 KB cap + N=2 window covers typical debug sessions | settled |
| Stdin JSON payload contains a top-level `tool_name` field (Claude Code schema); no hook currently reads it | **disputed** |

## Success Criteria

- **When** `SPINE_HOOK_LOG=1` is set and a hook fires, **the system shall** append a JSONL line to `~/.config/spine/logs/hooks.jsonl`.
  - Example: `{"ts":"2026-04-03T10:22:01.123Z","event":"preToolUse","hook":"guard-shell","tool":"Bash"}`
- **When** `SPINE_HOOK_LOG` is unset or empty, **the system shall** write no log entries and impose no observable overhead.
- **When** `hooks.jsonl` exceeds ~500 KB, **the system shall** rotate it to `hooks.jsonl.1`, delete `hooks.jsonl.2` if present, and start a fresh `hooks.jsonl`.
- **When** `install.sh` runs, **the system shall** create `~/.config/spine/logs/` if it does not exist.
- **When** logging fails (disk full, permissions), **the system shall** silently continue and not block the tool call.

## Open Unknowns

| Unknown | Impact | Note |
|---------|--------|------|
| Does hook stdin include `tool_name` across all providers (Claude Code, Cursor, Codex, OpenCode)? | informational | Claude Code documents `tool_name` at top level; Cursor uses camelCase `toolName`. May need provider-aware extraction or hardcoded fallback per hook. |
