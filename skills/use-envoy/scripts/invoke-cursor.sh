#!/bin/sh
# Invoke cursor-agent CLI headlessly for cross-provider envoy.
# Exit: 0=success, 1=invocation failed, 2=interrupted (provider-specific), 3=output validation failed

set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: invoke-cursor.sh --prompt-file PATH --output-file PATH --stderr-log PATH [--tier frontier|standard|fast] [--fallback-for claude|codex]

Invoke cursor-agent CLI headlessly with sanitized environment.
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

# --- Tier-aware model selection (no effort — cursor-agent CLI unsupported) ---
# Two-pass: (1) fallback_for determines base model for standard tier,
# (2) tier overrides base for frontier/fast. Differs from claude/codex
# scripts because cursor composes fallback-provider with tier selection.

resolve_tier "$tier" cursor
case "$fallback_for" in
    claude) _base="${SPINE_ENVOY_CLAUDE_CURSOR_FALLBACK:-composer-2}" ;;
    codex)  _base="${SPINE_ENVOY_CODEX_CURSOR_FALLBACK:-composer-2}" ;;
    *)      _base="$_tier_model" ;;  # Direct target (not fallback) — use tier default
esac
case "$tier" in
    frontier) model="${SPINE_ENVOY_FRONTIER_CURSOR:-${SPINE_ENVOY_CURSOR:-$_tier_model}}" ;;
    fast)     model="${SPINE_ENVOY_FAST_CURSOR:-${SPINE_ENVOY_CURSOR:-$_tier_model}}" ;;
    *)        model="${SPINE_ENVOY_STANDARD_CURSOR:-${SPINE_ENVOY_CURSOR:-$_base}}" ;;
esac
_cursor_timeout=1800  # cursor-agent hang bug (GH #3588)

# --- Binary resolution ---

_binary=""
if command -v cursor-agent >/dev/null 2>&1; then
    _binary=cursor-agent
elif command -v agent >/dev/null 2>&1; then
    _binary=agent
else
    error "cursor-agent CLI not found on PATH"
    exit 1
fi

# --- Pre-flight + cleanup ---

preflight_check

# ARG_MAX guard: cursor-agent takes prompt as positional arg, not stdin.
# Truncate to 128KB if needed (positional args share ARG_MAX with env).
_prompt_arg=$(cat "$prompt_file")
_prompt_size=$(printf '%s' "$_prompt_arg" | wc -c | tr -d ' ')
if [ "$_prompt_size" -gt 131072 ]; then
    _prompt_arg=$(printf '%s' "$_prompt_arg" | head -c 131072)
    printf 'Warning: prompt truncated from %s to 131072 bytes (ARG_MAX guard)\n' "$_prompt_size" >&2
fi

init_cleanup
start_timer

# --- Invoke (coreutils timeout handles process group kill + SIGKILL escalation) ---
# --force: consistency with --dangerously-skip-permissions (Claude) and codex exec defaults

printf 'envoy: invoking cursor (model=%s)...\n' "$model" >&2
_rc=0
timeout --kill-after=10 "$_cursor_timeout" env \
    -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
    -u OPENCODE \
    PATH="$HOME/.local/bin:$PATH" \
    "$_binary" -p \
        --output-format text \
        --trust \
        --force \
        --model "$model" \
        -- "$_prompt_arg" \
        > "$output_file" 2>"$stderr_log" \
    || _rc=$?

# Model-level retry: composer-2 rate limit → auto (different usage pool).
# Auto uses Cursor's routing with a separate allocation from composer-2.
# Only retry rate-limit failures; other errors propagate to fallback.sh.
if [ "$_rc" -ne 0 ] && [ "$model" != "auto" ]; then
    if grep -qiE 'out of usage|increase.*limit|rate[ _-]limit|quota|credits.*exhaust' "$stderr_log" 2>/dev/null; then
        printf 'envoy: cursor %s rate-limited, retrying with auto...\n' "$model" >&2
        _original_model="$model"
        model=auto
        _rc=0
        timeout --kill-after=10 "$_cursor_timeout" env \
            -u CLAUDECODE -u CURSOR_AGENT -u CODEX_SANDBOX \
            -u OPENCODE \
            PATH="$HOME/.local/bin:$PATH" \
            "$_binary" -p \
                --output-format text \
                --trust \
                --force \
                --model "$model" \
                -- "$_prompt_arg" \
                > "$output_file" 2>"$stderr_log" \
            || _rc=$?
    fi
fi

printf 'envoy: cursor completed (exit=%s), validating...\n' "$_rc" >&2
_cleanup
if [ "$_rc" -eq 124 ] || [ "$_rc" -eq 137 ]; then
    error "cursor-agent CLI timed out after ${_cursor_timeout}s"; exit 2
fi
handle_exit_code "cursor-agent CLI"
stop_timer

# --- Validate + sanitize + trust-boundary marker ---

validate_output

_provider_label="Cursor-Agent"
_fallback_note=""
if [ -n "${_original_model:-}" ]; then
    _fallback_note="Note: cursor-agent model $_original_model was rate-limited. Retried with model auto."
fi
case "$fallback_for" in
    claude)
        _provider_label="Claude Code -> Cursor-Agent Fallback"
        _fallback_note="${_fallback_note:+$_fallback_note }Note: Claude Code was unavailable. This response was generated by cursor-agent as fallback."
        ;;
    codex)
        _provider_label="Codex -> Cursor-Agent Fallback"
        _fallback_note="${_fallback_note:+$_fallback_note }Note: Codex was unavailable. This response was generated by cursor-agent as fallback."
        ;;
esac

_meta_provider="$_provider_label"
_meta_model="$model"
_meta_effort=""
# shellcheck disable=SC2154  # set by stop_timer() in _common.sh
_meta_elapsed="$_timer_elapsed"
_meta_session_id=""
_meta_resolved_model=""
_meta_fallback_note="$_fallback_note"

assemble_output
finalize_output
