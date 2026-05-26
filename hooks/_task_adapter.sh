#!/bin/sh
# _task_adapter.sh — Provider-aware task-tracker shim.
#
# Usage: sh _task_adapter.sh <session-dir> <from_phase|null> <to_phase> <trigger>
#
# Fires immediately after a phase.boundary event lands in events.jsonl.
# Detects the active provider from env (Claude Code / Codex / Cursor / OpenCode /
# unknown), records an audit `task.adapter` event into the same events.jsonl, and
# prints the provider-specific next-action instruction to stderr so the
# mainthread can issue the actual TaskCreate / update_plan / log call.
#
# For Cursor, which has no native task tracker, this script appends a stub
# Phase Trace row to session-log.md so the UX surface is preserved.
#
# Provider detection (in order):
#   CLAUDECODE=1        → claude-code
#   CODEX_HOME / CODEX_EXEC → codex
#   SPINE_PROVIDER_IS_CURSOR=1 → cursor (set by _env.sh)
#   OPENCODE_PROJECT_ROOT → opencode
#   else                → unknown (no-op)
#
# spine:managed

set -eu

[ $# -ge 4 ] || {
    printf 'usage: sh _task_adapter.sh <session-dir> <from_phase> <to_phase> <trigger>\n' >&2
    exit 2
}

dir="$1"
from_phase="$2"
to_phase="$3"
trigger="$4"

[ -d "$dir" ] || {
    printf 'task-adapter: session dir not found: %s\n' "$dir" >&2
    exit 1
}

# Provider detection
if [ "${CLAUDECODE:-}" = "1" ] || [ -n "${CLAUDE_CODE_VERSION:-}" ]; then
    provider="claude-code"
    action="TaskUpdate(prev → completed) + TaskCreate(next phase)"
elif [ -n "${CODEX_HOME:-}" ] || [ -n "${CODEX_EXEC:-}" ]; then
    provider="codex"
    action="update_plan: prev step → completed; next step → in_progress"
elif [ "${SPINE_PROVIDER_IS_CURSOR:-}" = "1" ]; then
    provider="cursor"
    action="log-only (session-log.md Phase Trace row)"
elif [ -n "${OPENCODE_PROJECT_ROOT:-}" ]; then
    provider="opencode"
    action="TBD (opencode/spine-hooks.ts shim)"
else
    provider="unknown"
    action="no-op"
fi

# halt trigger overrides next-step action; mainthread should mark current task
# as blocked/completed-with-reason rather than open a new one.
if [ "$trigger" = "halt" ]; then
    case "$provider" in
        claude-code) action="TaskUpdate(current → completed or blocked, with reason)" ;;
        codex)       action="update_plan: current step → in_progress + note halt reason" ;;
        cursor)      action="log-only (append halt row to session-log.md)" ;;
        opencode)    action="TBD halt-path" ;;
        unknown)     action="no-op (halt observed)" ;;
    esac
fi

# Audit event: record adapter dispatch in events.jsonl via emit-event.sh.
# Resolves emit-event.sh path relative to this script regardless of install layout.
script_dir=$(cd "$(dirname "$0")" && pwd)
emit="$script_dir/../skills/use-session/scripts/emit-event.sh"
if [ ! -f "$emit" ]; then
    # Installed layout: hooks/ and skills/ live as siblings under ~/.config/spine/
    emit="$script_dir/../use-session/scripts/emit-event.sh"
fi

if [ -f "$emit" ]; then
    payload=$(jq -nc \
        --arg from "$from_phase" --arg to "$to_phase" --arg trig "$trigger" \
        --arg prov "$provider" --arg act "$action" \
        '{from_phase:$from, to_phase:$to, trigger:$trig, provider:$prov, action:$act}')
    sh "$emit" "$dir" task.adapter "$payload" >/dev/null
fi

# Cursor log-only path: append a Phase Trace stub directly so the user-visible
# log surface mirrors what TaskUpdate/update_plan would render in other providers.
if [ "$provider" = "cursor" ]; then
    log="$dir/session-log.md"
    if [ -f "$log" ]; then
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        printf '\n<!-- task-adapter cursor stub %s -->\n| %s→%s | %s | task.adapter:cursor log-only | %s |\n' \
            "$ts" "$from_phase" "$to_phase" "$trigger" "$action" >> "$log"
    fi
fi

printf 'task-adapter: provider=%s action=%s\n' "$provider" "$action" >&2
printf '%s\n' "$provider"
