#!/bin/sh
# Invoke Claude Code CLI headlessly for cross-provider envoy.
# Exit: 0=success, 1=invocation failed, 2=timeout, 3=output validation failed

set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: run-claude.sh --prompt-file PATH --output-file PATH --stderr-log PATH [--timeout SECS] [--tier frontier|standard|fast]

Invoke Claude Code CLI headlessly with sanitized environment.
EOF
}

# --- Argument parsing ---

prompt_file="" output_file="" stderr_log="" timeout_secs="" tier="standard"

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
        --timeout)      timeout_secs="$2"; shift 2 ;;
        --tier)         tier="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              error "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

[ -n "$prompt_file" ]  || { error "Missing --prompt-file"; usage; exit 1; }
[ -n "$output_file" ]  || { error "Missing --output-file"; usage; exit 1; }
[ -n "$stderr_log" ]   || { error "Missing --stderr-log"; usage; exit 1; }
[ -f "$prompt_file" ]  || { error "Prompt file not found: $prompt_file"; exit 1; }
[ -s "$prompt_file" ]  || { error "Prompt file is empty: $prompt_file"; exit 1; }

# --- Shared functions ---

_script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=_common.sh
. "$_script_dir/_common.sh"

command -v jq >/dev/null 2>&1 || { error "jq required but not found"; exit 1; }

# --- Tier-aware model selection (configurable via SPINE_ENVOY_{TIER_}CLAUDE=model[:effort]) ---

resolve_tier "$tier" claude
case "$tier" in
    frontier) _envoy_val="${SPINE_ENVOY_FRONTIER_CLAUDE:-${SPINE_ENVOY_CLAUDE:-$_tier_model:$_tier_effort}}" ;;
    fast)     _envoy_val="${SPINE_ENVOY_FAST_CLAUDE:-${SPINE_ENVOY_CLAUDE:-$_tier_model:$_tier_effort}}" ;;
    *)        _envoy_val="${SPINE_ENVOY_STANDARD_CLAUDE:-${SPINE_ENVOY_CLAUDE:-$_tier_model:$_tier_effort}}" ;;
esac
model="${_envoy_val%%:*}"
effort="${_envoy_val#*:}"
[ "$effort" = "$model" ] && effort=high
timeout_secs="${timeout_secs:-900}"

# --- Pre-flight + cleanup ---

preflight_check
init_cleanup

# --- Invoke (coreutils timeout handles process group kill + SIGKILL escalation) ---

_json_tmp="${output_file}.json"
start_timer

_rc=0
timeout --kill-after=10 "$timeout_secs" env \
    -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
    PATH="$HOME/.local/bin:$PATH" \
    CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
    CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 \
    CLAUDE_CODE_EFFORT_LEVEL="$effort" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude --print \
        --no-session-persistence \
        --model "$model" \
        --output-format json \
        --dangerously-skip-permissions \
        < "$prompt_file" \
        > "$_json_tmp" 2>"$stderr_log" \
    || _rc=$?

_cleanup
handle_exit_code "Claude CLI"
stop_timer

# --- Extract body and metadata from JSON output ---

if [ -f "$_json_tmp" ] && jq -e '.result' "$_json_tmp" >/dev/null 2>&1; then
    jq -r '.result // ""' "$_json_tmp" > "$output_file"
    _meta_session_id=$(jq -r '.session_id // "none"' "$_json_tmp")
    _duration_ms=$(jq -r '.duration_ms // empty' "$_json_tmp")
    _meta_resolved_model=$(jq -r '(.modelUsage | keys[0]) // empty' "$_json_tmp")
else
    # JSON extraction failed — cannot deliver valid output
    rm -f "$_json_tmp"
    _json_tmp=""
    error "JSON extraction failed from Claude output"
    exit 3
fi
rm -f "$_json_tmp"
_json_tmp=""

# Prefer API-reported duration if available, otherwise shell timing
_meta_elapsed="${_duration_ms:+$(( _duration_ms / 1000 ))}"
_meta_elapsed="${_meta_elapsed:-$_timer_elapsed}"

# --- Validate + sanitize + trust-boundary marker ---

validate_output

_meta_provider="Claude Code"
_meta_model="$model"
_meta_effort="$effort"
_meta_fallback_note=""

assemble_output
finalize_output
