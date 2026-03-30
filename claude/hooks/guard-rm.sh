#!/bin/bash
# guard-rm.sh
# Claude Code PreToolUse hook: block recursive rm commands.
# Enforces the SPINE.md guardrail: "Prefer trash over rm for file deletion."
# Triggered by Bash tool via hooks.json PreToolUse matcher.
#
# Exit codes: 2 = block tool call, 0 = allow.

# jq required for JSON parsing; fail open if unavailable
if ! command -v jq &>/dev/null; then
  exit 0
fi

input=$(cat)
CMD=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Block: rm appearing as a command AND a recursive flag present.
# Matches -r, -R, --recursive, and combined flags (-rf, -fr, -rn, etc.).
# Also matches RTK-rewritten forms (rtk rm ...) for defense-in-depth.
# Does not block non-recursive rm (e.g., rm file.txt, rm -f file.txt).
if echo "$CMD" | grep -qiE '(^|;[[:space:]]*|&&[[:space:]]*|[|][|][[:space:]]*|[|][[:space:]]*)(rtk[[:space:]]+)?rm[[:space:]]' && \
   echo "$CMD" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive'; then
  echo "BLOCKED: Use 'trash <path>' instead of 'rm -r' for recoverable deletion" >&2
  exit 2
fi

exit 0
