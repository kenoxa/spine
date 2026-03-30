#!/bin/sh
# _opencode-common.sh — shared transport for OpenCode-based envoy providers.
# Provides CLI invocation + JSONL parsing. Per-provider scripts own model selection.
# Caller must source _common.sh first and set: $prompt_file, $output_file, $stderr_log, $_script_dir.
# shellcheck disable=SC2154  # all vars are caller-provided (sourced file pattern)

_opencode_timeout=3600  # liveness safety net (matches other providers)

# Invoke opencode CLI with sanitized environment.
# Args: $1=model, $2=effort (variant)
# Sets: _rc, _json_tmp
opencode_invoke() {
    _oc_model="$1"
    _oc_effort="$2"

    _json_tmp="${output_file}.json"
    start_timer

    printf 'envoy: invoking opencode (model=%s, effort=%s)...\n' "$_oc_model" "$_oc_effort" >&2
    _rc=0
    timeout --kill-after=10 "$_opencode_timeout" env \
        -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
        -u QWEN_CODE -u QWEN_CODE_NO_RELAUNCH \
        -u OPENCODE_CLIENT -u OPENCODE_PID \
        opencode run \
            --format json \
            --model "$_oc_model" \
            --variant "$_oc_effort" \
            < "$prompt_file" \
            > "$_json_tmp" 2>"$stderr_log" \
        || _rc=$?

    printf 'envoy: opencode completed (exit=%s), validating...\n' "$_rc" >&2
}

# Extract content and metadata from OpenCode JSONL output.
# Sets: _meta_session_id, _meta_resolved_model, _meta_elapsed
# Writes extracted text to $output_file.
opencode_extract() {
    if [ ! -f "$_json_tmp" ] || [ ! -s "$_json_tmp" ]; then
        _cleanup
        error "No output from OpenCode CLI"
        exit 3
    fi

    # Completeness gate: require at least one step_finish with reason:"stop"
    # Uses jq -s (slurp) + any() for robustness against multi-step sessions
    if ! jq -s 'any(.[]; .type == "step_finish" and .part.reason == "stop")' "$_json_tmp" 2>/dev/null | grep -q true; then
        _cleanup
        error "JSONL stream incomplete (no step_finish)"
        exit 3
    fi

    # Extract text content: concatenate .part.text from all type:"text" events
    _extracted=$(jq -r 'select(.type == "text") | .part.text // empty' "$_json_tmp" 2>/dev/null) || true

    if [ -z "$_extracted" ]; then
        _cleanup
        error "No text content in OpenCode JSONL output"
        exit 3
    fi
    printf '%s\n' "$_extracted" > "$output_file"

    # Metadata from JSONL events
    _meta_session_id=$(jq -r 'select(.type == "step_start") | .sessionID // "none"' "$_json_tmp" 2>/dev/null | head -1) || true
    _meta_resolved_model=""  # opencode doesn't report resolved model

    rm -f "$_json_tmp"
    _json_tmp=""
    _cleanup

    # Use shell timer for elapsed (opencode doesn't report duration_ms directly)
    _meta_elapsed="$_timer_elapsed"
}
