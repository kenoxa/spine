#!/bin/sh
# Invoke Copilot CLI headlessly for cross-provider envoy.
# Exit: 0=success, 1=invocation failed, 2=interrupted (provider-specific), 3=output validation failed

set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: invoke-copilot.sh --prompt-file PATH --output-file PATH --stderr-log PATH [--tier frontier|standard|fast] [--fallback-for claude|codex]

Invoke Copilot CLI headlessly with sanitized environment.
EOF
}

# --- Argument parsing ---

prompt_file="" output_file="" stderr_log="" tier="standard" fallback_for=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)    prompt_file="$2"; shift 2 ;;
        --output-file)    output_file="$2"; shift 2 ;;
        --stderr-log)     stderr_log="$2"; shift 2 ;;
        --tier)           tier="$2"; shift 2 ;;
        --fallback-for)   fallback_for="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *)                error "Unknown argument: $1"; usage; exit 1 ;;
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

# --- Tier-aware model selection ---
# Two-pass: (1) fallback_for determines model family for budget-optimized selection,
# (2) env var cascade overrides. Budget-optimized: prefer 0.33x models (haiku, mini)
# at standard/fast tiers since copilot fallback is best-effort recovery.

resolve_tier "$tier" copilot
case "$fallback_for" in
    claude)
        # Claude family: match tier quality
        case "$tier" in
            frontier) _base="claude-sonnet-4.6"; _base_effort="high" ;;
            standard) _base="claude-sonnet-4.6"; _base_effort="high" ;;
            fast)     _base="claude-haiku-4.5";  _base_effort="high" ;;
        esac
        ;;
    codex)
        # GPT family: match tier quality
        case "$tier" in
            frontier) _base="gpt-5.4";      _base_effort="xhigh" ;;
            standard) _base="gpt-5.4";      _base_effort="medium" ;;
            fast)     _base="gpt-5.4-mini";  _base_effort="high" ;;
        esac
        ;;
    *)
        # Direct target (not fallback) — use resolve_tier defaults
        # shellcheck disable=SC2154  # set by resolve_tier() in _common.sh
        _base="$_tier_model"
        # shellcheck disable=SC2154
        _base_effort="$_tier_effort"
        ;;
esac

case "$tier" in
    frontier) _envoy_val="${SPINE_ENVOY_FRONTIER_COPILOT:-${SPINE_ENVOY_COPILOT:-$_base:$_base_effort}}" ;;
    fast)     _envoy_val="${SPINE_ENVOY_FAST_COPILOT:-${SPINE_ENVOY_COPILOT:-$_base:$_base_effort}}" ;;
    *)        _envoy_val="${SPINE_ENVOY_STANDARD_COPILOT:-${SPINE_ENVOY_COPILOT:-$_base:$_base_effort}}" ;;
esac
model="${_envoy_val%%:*}"
effort="${_envoy_val#*:}"
[ "$effort" = "$model" ] && effort=high
_copilot_timeout=3600  # liveness safety net

# --- Pre-flight + cleanup ---

preflight_check
init_cleanup

# --- Invoke (coreutils timeout handles process group kill + SIGKILL escalation) ---

_json_tmp="${output_file}.json"
start_timer

printf 'envoy: invoking copilot (model=%s, effort=%s)...\n' "$model" "$effort" >&2
_rc=0
timeout --kill-after=10 "$_copilot_timeout" env \
    -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
    -u QWEN_CODE -u QWEN_CODE_NO_RELAUNCH \
    -u COPILOT_MODEL \
    SPINE_ENVOY_COPILOT=1 \
    copilot \
        --silent \
        --no-ask-user \
        --model "$model" \
        --effort "$effort" \
        --output-format json \
        --allow-all \
        < "$prompt_file" \
        > "$_json_tmp" 2>"$stderr_log" \
    || _rc=$?

printf 'envoy: copilot completed (exit=%s), validating...\n' "$_rc" >&2
# Defer _cleanup until after JSON extraction — _cleanup deletes $_json_tmp
if [ "$_rc" -eq 124 ] || [ "$_rc" -eq 137 ]; then
    _cleanup
    error "Copilot CLI timed out after ${_copilot_timeout}s"; exit 2
fi
handle_exit_code "Copilot CLI"
stop_timer

# --- Extract body and metadata from JSONL output ---
# Copilot --output-format json produces JSONL: one JSON object per line.
# Content lives in type=assistant.message → .data.content
# Metadata lives in type=result → .sessionId, .usage.totalApiDurationMs

_meta_session_id=""
_meta_resolved_model=""
_duration_ms=""

if [ -f "$_json_tmp" ] && [ -s "$_json_tmp" ]; then
    # Extract content from assistant.message line(s) — may have multiple deltas
    _extracted=$(jq -r 'select(.type == "assistant.message") | .data.content // empty' "$_json_tmp" 2>/dev/null) || true
    # Extract metadata from result line (compact -c to keep on one line)
    _result_line=$(jq -c 'select(.type == "result")' "$_json_tmp" 2>/dev/null) || true

    if [ -n "$_extracted" ]; then
        printf '%s\n' "$_extracted" > "$output_file"
        if [ -n "$_result_line" ]; then
            _meta_session_id=$(printf '%s' "$_result_line" | jq -r '.sessionId // "none"') || true
            _duration_ms=$(printf '%s' "$_result_line" | jq -r '.usage.totalApiDurationMs // empty') || true
        fi
        # Model from tools_updated event
        _meta_resolved_model=$(jq -c -r 'select(.type == "session.tools_updated") | .data.model // empty' "$_json_tmp" 2>/dev/null | head -1) || true
    else
        _cleanup
        error "JSON extraction failed from Copilot output"
        exit 3
    fi
else
    _cleanup
    error "No output from Copilot CLI"
    exit 3
fi
rm -f "$_json_tmp"
_json_tmp=""
_cleanup

# Prefer API-reported duration if available, otherwise shell timing
_meta_elapsed="${_duration_ms:+$(( _duration_ms / 1000 ))}"
_meta_elapsed="${_meta_elapsed:-$_timer_elapsed}"

# --- Validate + sanitize + trust-boundary marker ---

validate_output

_provider_label="Copilot"
_fallback_note=""
if [ -n "$fallback_for" ]; then
    _provider_label="Copilot (fallback for $fallback_for)"
    _fallback_note="Note: $fallback_for was unavailable. This response was generated by Copilot as fallback."
fi

_meta_provider="$_provider_label"
_meta_model="$model"
_meta_effort="$effort"
_meta_fallback_note="$_fallback_note"

assemble_output
finalize_output
