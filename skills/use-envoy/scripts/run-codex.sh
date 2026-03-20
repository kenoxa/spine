#!/bin/sh
# Invoke Codex CLI headlessly for cross-provider envoy.
# Exit: 0=success, 1=invocation failed, 2=timeout, 3=output validation failed

set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: run-codex.sh --prompt-file PATH --output-file PATH --stderr-log PATH [--timeout SECS] [--tier frontier|standard|fast]

Invoke Codex CLI headlessly with sanitized environment.
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

# --- Tier-aware model selection (configurable via SPINE_ENVOY_{TIER_}CODEX=model[:effort]) ---

resolve_tier "$tier" codex
case "$tier" in
    frontier) _envoy_val="${SPINE_ENVOY_FRONTIER_CODEX:-${SPINE_ENVOY_CODEX:-$_tier_model:$_tier_effort}}" ;;
    fast)     _envoy_val="${SPINE_ENVOY_FAST_CODEX:-${SPINE_ENVOY_CODEX:-$_tier_model:$_tier_effort}}" ;;
    *)        _envoy_val="${SPINE_ENVOY_STANDARD_CODEX:-${SPINE_ENVOY_CODEX:-$_tier_model:$_tier_effort}}" ;;
esac
model="${_envoy_val%%:*}"
effort="${_envoy_val#*:}"
[ "$effort" = "$model" ] && effort=high
timeout_secs="${timeout_secs:-900}"

# --- Pre-flight + cleanup ---

preflight_check
init_cleanup
start_timer

# --- Invoke (coreutils timeout handles process group kill + SIGKILL escalation) ---

_rc=0
timeout --kill-after=10 "$timeout_secs" env \
    -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
    PATH="$HOME/.local/bin:$PATH" \
    CODEX_HOME="${CODEX_HOME:-$HOME/.codex}" \
    codex exec \
        -m "$model" \
        -c "model_reasoning_effort=$effort" \
        --ephemeral \
        --skip-git-repo-check \
        - < "$prompt_file" \
        > "$output_file" 2>"$stderr_log" \
    || _rc=$?

_cleanup
handle_exit_code "Codex CLI"
stop_timer

# --- Parse Codex stderr for metadata (best-effort, unstable source) ---

_meta_session_id=""
_meta_resolved_model=""
if [ -f "$stderr_log" ]; then
    _parsed_session=$(grep -i 'session id:' "$stderr_log" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]') || true
    _parsed_model=$(grep -i 'model:' "$stderr_log" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]') || true
    [ -n "$_parsed_session" ] && _meta_session_id="$_parsed_session"
    [ -n "$_parsed_model" ] && _meta_resolved_model="$_parsed_model"
fi
# shellcheck disable=SC2154  # set by stop_timer() in _common.sh
_meta_elapsed="$_timer_elapsed"

# --- Validate + sanitize + trust-boundary marker ---

validate_output

_meta_provider="Codex"
_meta_model="$model"
_meta_effort="$effort"
_meta_fallback_note=""

assemble_output
finalize_output
