#!/bin/sh
# guard-read-large.sh
# PreToolUse hook for Read: warn when file exceeds 2000 lines and no limit is set.
# Prevents context window waste from reading entire large files.
#
# Exit codes: 2 = block with context, 0 = allow.
printf '%s\tpreToolUse\tguard-read-large\n' "$(date +%s)" >>"$HOME/.spine-hooks.log" 2>/dev/null || true

# Required: jq for JSON parsing. Fail open with actionable warning.
if ! command -v jq >/dev/null 2>&1; then
  echo "[spine] WARNING: jq not found — guard-read-large cannot check file size. Install: brew install jq" >&2
  exit 0
fi

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
LIMIT=$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null)

# If limit is already set, allow without check
[ -n "$LIMIT" ] && exit 0

# If file exists and exceeds 2000 lines, warn
if [ -f "$FILE" ]; then
  LINES=$(wc -l < "$FILE" | tr -d ' ')
  if [ "$LINES" -gt 2000 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"WARNING: This file has %d lines which exceeds the 2000-line default. Use offset and limit parameters to read in chunks."}}\n' "$LINES"
    exit 2
  fi
fi

exit 0
