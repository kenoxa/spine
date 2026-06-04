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
#   SPINE_PROVIDER       → explicit provider override
#   CLAUDECODE=1        → claude-code
#   CODEX_HOME / CODEX_EXEC / CODEX_SANDBOX / CODEX_THREAD_ID / CODEX_CI → codex
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
case "${SPINE_PROVIDER:-}" in
    claude|claude-code)
        provider="claude-code"
        action="TaskUpdate(prev → completed) + TaskCreate(next phase)"
        ;;
    codex)
        provider="codex"
        action="update_plan: prev step → completed; next step → in_progress"
        ;;
    cursor)
        provider="cursor"
        action="log-only (session-log.md Phase Trace row)"
        ;;
    opencode)
        provider="opencode"
        action="TBD (opencode/spine-hooks.ts shim)"
        ;;
    unknown)
        provider="unknown"
        action="no-op"
        ;;
    "")
        provider=""
        action=""
        ;;
    *)
        provider="unknown"
        action="no-op"
        ;;
esac

if [ -z "$provider" ] && { [ "${CLAUDECODE:-}" = "1" ] || [ -n "${CLAUDE_CODE_VERSION:-}" ]; }; then
    provider="claude-code"
    action="TaskUpdate(prev → completed) + TaskCreate(next phase)"
elif [ -z "$provider" ] && {
    [ -n "${CODEX_HOME:-}" ] ||
    [ -n "${CODEX_EXEC:-}" ] ||
    [ -n "${CODEX_SANDBOX:-}" ] ||
    [ -n "${CODEX_THREAD_ID:-}" ] ||
    [ -n "${CODEX_CI:-}" ]
}; then
    provider="codex"
    action="update_plan: prev step → completed; next step → in_progress"
elif [ -z "$provider" ] && [ "${SPINE_PROVIDER_IS_CURSOR:-}" = "1" ]; then
    provider="cursor"
    action="log-only (session-log.md Phase Trace row)"
elif [ -z "$provider" ] && [ -n "${OPENCODE_PROJECT_ROOT:-}" ]; then
    provider="opencode"
    action="TBD (opencode/spine-hooks.ts shim)"
elif [ -z "$provider" ]; then
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
script_dir=$(cd "$(dirname "$0")" && pwd)
spine_home="${SPINE_HOME:-$(cd "$script_dir/.." && pwd)}"
home_dir="${HOME:-}"
skills_dir="${SPINE_SKILLS_DIR:-}"
if [ -z "$skills_dir" ] && [ -n "$home_dir" ]; then
    skills_dir="$home_dir/.agents/skills"
fi

resolve_emit_event() {
    if [ -n "${SPINE_EMIT_EVENT:-}" ] && [ -f "$SPINE_EMIT_EVENT" ]; then
        printf '%s\n' "$SPINE_EMIT_EVENT"
        return 0
    fi

    candidate="$script_dir/../skills/use-session/scripts/emit-event.sh"
    if [ -f "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    if [ -n "$skills_dir" ] && [ -f "$skills_dir/use-session/scripts/emit-event.sh" ]; then
        printf '%s\n' "$skills_dir/use-session/scripts/emit-event.sh"
        return 0
    fi

    if [ -n "$home_dir" ] && [ -f "$home_dir/.agents/skills/use-session/scripts/emit-event.sh" ]; then
        printf '%s\n' "$home_dir/.agents/skills/use-session/scripts/emit-event.sh"
        return 0
    fi

    for candidate in \
        "$spine_home/skills/use-session/scripts/emit-event.sh" \
        "$script_dir/../use-session/scripts/emit-event.sh"
    do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

emit=$(resolve_emit_event || true)

if [ -n "$emit" ]; then
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
