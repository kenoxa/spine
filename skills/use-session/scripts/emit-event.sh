#!/bin/sh
# emit-event.sh — Append one event to a session's events.jsonl.
#
# Usage: sh emit-event.sh <session-dir> <type> <payload-json>
#
# Computes next seq monotonically (max existing + 1), fills schema_version,
# session_id (from dir basename), ISO-8601 UTC ts, actor, branch, and
# worktree_path, then appends a single JSON line to <session-dir>/events.jsonl.
#
# Solo-writer (C7 invariant) — no locking; relies on POSIX append being
# whole-write atomic for small lines.

set -eu

[ $# -ge 3 ] || {
    printf 'usage: sh emit-event.sh <session-dir> <type> <payload-json>\n' >&2
    exit 2
}

dir="$1"
type="$2"
payload="$3"

[ -d "$dir" ] || {
    printf 'emit-event: session dir not found: %s\n' "$dir" >&2
    exit 1
}

# Verify payload parses as JSON before touching the log.
printf '%s' "$payload" | jq -e . >/dev/null 2>&1 || {
    printf 'emit-event: payload is not valid JSON: %s\n' "$payload" >&2
    exit 1
}

events="$dir/events.jsonl"
sid="${dir##*/}"

# Next seq = (max existing seq) + 1. Empty/missing file → 1.
if [ -f "$events" ]; then
    seq=$(jq -s 'if length==0 then 0 else (map(.seq // 0) | max) end' "$events" 2>/dev/null || printf '0')
    seq=$((seq + 1))
else
    seq=1
fi

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Branch + worktree_path: optional context — never fatal if outside a git tree.
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')
worktree_path=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || (cd "$dir" && pwd))

# Actor is provided via env so the caller (mainthread, sub-agent dispatch, hook)
# can label itself accurately. Defaults: mainthread/writer.
actor_id="${SPINE_ACTOR_ID:-mainthread}"
actor_role="${SPINE_ACTOR_ROLE:-writer}"

record=$(jq -nc \
    --argjson seq "$seq" \
    --arg ts "$ts" \
    --arg type "$type" \
    --arg sid "$sid" \
    --arg aid "$actor_id" \
    --arg arole "$actor_role" \
    --arg branch "$branch" \
    --arg wt "$worktree_path" \
    --argjson payload "$payload" \
    '{schema_version:1, session_id:$sid, seq:$seq, ts:$ts, type:$type, actor:{id:$aid, role:$arole}, branch:$branch, worktree_path:$wt, payload:$payload}')

printf '%s\n' "$record" >> "$events"
printf 'emitted: seq=%d type=%s\n' "$seq" "$type"
