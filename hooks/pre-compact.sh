#!/usr/bin/env _env.sh
# pre-compact.sh
# PreCompact hook — emits agentMessage with handoff instructions before compaction.
# Reads pre-compact.prompt from the same directory (resolved at runtime).

prompt_file="$(dirname "$0")/pre-compact.prompt"

[ -f "$prompt_file" ] || exit 0

command -v jq >/dev/null 2>&1 || { printf '{"agentMessage":""}\n'; exit 0; }

jq -Rs '{agentMessage: .}' "$prompt_file"
