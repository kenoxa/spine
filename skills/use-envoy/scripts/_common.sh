#!/bin/sh
# _common.sh — shared functions for Envoy provider scripts.
# Caller-provided vars: $prompt_file, $output_file, $stderr_log, $timeout_secs, $_rc, $_script_dir.
# Caller-provided function: error().
# Ordering: call finalize_output() AFTER trust-boundary marker assembly (which reads $_sanitize_tmp).
# shellcheck disable=SC2154  # all vars are caller-provided (sourced file pattern)

preflight_check() {
    chmod 600 "$prompt_file"
    if grep -qE '(API_KEY|SECRET|TOKEN|PASSWORD)=|AKIA[A-Z0-9]{16}|ghp_[A-Za-z0-9]{36}|github_pat_' "$prompt_file" 2>/dev/null; then
        printf 'Warning: prompt file may contain secrets\n' >&2
    fi
}

_sanitize_tmp=""
_cleanup() {
    [ -n "$_sanitize_tmp" ] && rm -f "$_sanitize_tmp" "${_sanitize_tmp}.2" "${_sanitize_tmp}.cap"
    if [ -f "$stderr_log" ]; then
        sed -E 's/(sk-|key-|AKIA|ghp_|gho_|xai-|ant-|github_pat_|ghu_|ghs_|ghr_|eyJ|xoxb-|xoxp-|glpat-|npm_|pypi-)[A-Za-z0-9_-]{16,}/[REDACTED]/g' \
            "$stderr_log" > "${stderr_log}.tmp" && mv "${stderr_log}.tmp" "$stderr_log"
        chmod 600 "$stderr_log"
    fi
}
init_cleanup() { trap _cleanup EXIT INT TERM; }

handle_exit_code() {
    if [ "$_rc" -eq 124 ] || [ "$_rc" -eq 137 ]; then
        error "$1 timed out after ${timeout_secs}s"; exit 2
    fi
    if [ "$_rc" -ne 0 ]; then
        error "$1 invocation failed (exit $_rc)"; exit 1
    fi
}

validate_output() {
    [ -f "$output_file" ] || { error "Output file not created"; exit 3; }
    _output_size=$(wc -c < "$output_file" | tr -d ' ')
    [ "$_output_size" -ge 200 ] || { error "Output too small (${_output_size} bytes, minimum 200)"; exit 3; }
    _sanitize_tmp="${output_file}.sanitize"
    # shellcheck source=sanitize.sh
    . "$_script_dir/sanitize.sh"
}

finalize_output() {
    rm -f "$_sanitize_tmp"
    chmod 600 "$output_file"
    printf '%s\n' "$output_file"
}

# Tier-to-model resolution for envoy dispatch.
# Canonical mapping reference: docs/model-selection.md
resolve_tier() {
    case "$1:$2" in
        frontier:claude) _tier_model=opus;          _tier_effort=high ;;
        frontier:codex)  _tier_model=gpt-5.4;       _tier_effort=high ;;
        frontier:cursor) _tier_model=gpt-5.4-high;  _tier_effort= ;;
        standard:claude) _tier_model=sonnet;         _tier_effort=high ;;
        standard:codex)  _tier_model=gpt-5.4-mini;  _tier_effort=high ;;
        standard:cursor) _tier_model=composer-2;     _tier_effort= ;;
        fast:claude)     _tier_model=haiku;          _tier_effort=medium ;;
        fast:codex)      _tier_model=gpt-5.4-nano;  _tier_effort=medium ;;
        fast:cursor)     _tier_model=auto;           _tier_effort= ;;
        *)               _tier_model=;               _tier_effort= ;;
    esac
}
