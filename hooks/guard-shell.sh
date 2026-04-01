#!/bin/sh
# guard-shell.sh
# PreToolUse hook: security deny-list for shell commands.
# Blocks dangerous patterns (docker escapes, file uploads, recursive rm).
# Uses permissionDecision for providers that support it (Claude Code),
# exit 2 for blocking on others.
#
# Exit codes: 0 = allow, 2 = block (with reason on stderr/stdout).
# ALWAYS exits 0 on missing deps — fail open.

# Required: jq for JSON parsing. Fail open with actionable warning.
if ! command -v jq >/dev/null 2>&1; then
  echo "[spine] WARNING: jq not found — guard-shell cannot parse commands. Install: brew install jq" >&2
  exit 0
fi

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Normalize: collapse line continuations, newlines/tabs → spaces
cmd=$(printf '%s' "$cmd" | tr '\n\t' '  ')

# Strip RTK proxy prefix — guard must inspect the underlying command.
# RTK transparently rewrites tool calls (e.g., "rm -rf" → "rtk rm -rf").
cmd=$(printf '%s' "$cmd" | sed 's/^rtk //')

# --- Output helpers ---
# permissionDecision JSON works on Claude Code + Qwen Code.
# exit 2 works on Codex + Cursor as fallback.
# Both are emitted so the hook works across all providers.

hook_deny() {
  jq -n --arg r "$1" '{
    "hookSpecificOutput":{
      "hookEventName":"PreToolUse",
      "permissionDecision":"deny",
      "permissionDecisionReason":$r
    }
  }'
  echo "BLOCKED: $1" >&2
  exit 2
}

hook_ask() {
  jq -n --arg r "$1" '{
    "hookSpecificOutput":{
      "hookEventName":"PreToolUse",
      "permissionDecision":"ask",
      "permissionDecisionReason":$r
    }
  }'
  exit 0
}

# --- Recursive rm ---
# Matches rm with recursive flags (-rf, -fr, -R, --recursive), including chained commands.
if echo "$cmd" | grep -qiE '(^|;[[:space:]]*|&&[[:space:]]*|[|][|][[:space:]]*|[|][[:space:]]*)rm[[:space:]]' && \
   echo "$cmd" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive'; then
  hook_deny "Use 'trash <path>' instead of 'rm -r' for recoverable deletion"
fi

# --- Docker run ---
if echo "$cmd" | grep -qE -- 'docker +run '; then
  echo "$cmd" | grep -qE -- '(^| )--privileged( |$)'                              && hook_deny "Container escape: --privileged grants full host access"
  echo "$cmd" | grep -qE -- '(-v[= ]/:|--volume[= ]/:)'                           && hook_deny "Root filesystem mount into container"
  echo "$cmd" | grep -qE -- '--mount [^ ]*source=/[, ]'                            && hook_deny "Root filesystem mount via --mount"
  echo "$cmd" | grep -qE -- '(-v[= ]|--volume[= ])/var/run/docker\.sock'           && hook_deny "Docker socket mount = host root access"
  echo "$cmd" | grep -qE -- '--(net|network)[= ]host'                              && hook_deny "Host network bypass"
  echo "$cmd" | grep -qE -- '--pid[= ]host'                                        && hook_deny "Host PID namespace exposure"
  echo "$cmd" | grep -qE -- '--ipc[= ]host'                                        && hook_deny "Host IPC namespace exposure"
  echo "$cmd" | grep -qiE -- '--cap-add[= ](SYS_ADMIN|ALL)'                        && hook_deny "Dangerous capability addition"
  echo "$cmd" | grep -qE -- '--security-opt[= ](apparmor|seccomp)=unconfined'       && hook_deny "Mandatory access control disabled"

  # ASK if --rm missing (warn about orphaned containers)
  echo "$cmd" | grep -qE -- '(^| )--rm( |$)' || hook_ask "docker run without --rm may leave orphaned containers"
  exit 0
fi

# --- Docker exec ---
if echo "$cmd" | grep -qE -- 'docker +(compose +)?exec |docker-compose +exec '; then
  echo "$cmd" | grep -qE -- '(^| )--privileged( |$)' && hook_deny "Privileged exec blocked"
  exit 0
fi

# --- Curl ---
if echo "$cmd" | grep -qE -- '(^|[ ;&|])curl '; then
  echo "$cmd" | grep -qE -- '-d[= ]?@|--data[= ]@|--data-binary[= ]@|--data-raw[= ]@|--data-urlencode[= ]@' && hook_deny "File upload: curl -d @file"
  echo "$cmd" | grep -qE -- '(-T[= ]?|--upload-file[= ])[^ ]'                                                && hook_deny "File upload: curl -T"
  echo "$cmd" | grep -qE -- '(-F[= ]?|--form[= ])[^ ]*@'                                                     && hook_deny "File upload: curl -F @file"
  echo "$cmd" | grep -qE -- '(-K[= ]?|--config[= ])'                                                          && hook_deny "curl --config may contain upload directives"
  exit 0
fi

# --- Wget ---
if echo "$cmd" | grep -qE -- '(^|[ ;&|])wget '; then
  echo "$cmd" | grep -qE -- '--post-file[= ]' && hook_deny "File upload: wget --post-file"
  exit 0
fi

# Non-matching: passthrough
exit 0
