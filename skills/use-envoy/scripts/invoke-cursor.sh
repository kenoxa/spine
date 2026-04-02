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
_fb_model="" _fb_effort=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)    prompt_file="$2"; shift 2 ;;
        --output-file)    output_file="$2"; shift 2 ;;
        --stderr-log)     stderr_log="$2"; shift 2 ;;
        --tier)           tier="$2"; shift 2 ;;
        --fallback-for)   fallback_for="$2"; shift 2 ;;
        --model)          _fb_model="$2"; shift 2 ;;
        --effort)         _fb_effort="$2"; shift 2 ;;
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

# --- Model selection ---
# Direct cursor invoke: tier → Cursor pool (composer / auto). Fallback after
# Claude/Codex failure: deterministic two-step mapping from canonical model+effort
# to cursor-agent model IDs (see docs/model-selection.md).

_CLAUDE_CURSOR_PREFIX="claude-4.6"

# Two-step mapping: canonical model+effort → cursor-agent model ID.
# Step 1: map model to cursor-agent base. Step 2: compose effort suffix.
# Returns 1 if no cursor-agent equivalent exists for the model.
to_cursor_model() {
    _tcm_model="$1"
    _tcm_effort="$2"

    # Step 1 — map canonical model to cursor-agent base
    case "$_tcm_model" in
        opus)   _tcm_base="${_CLAUDE_CURSOR_PREFIX}-opus" ;;
        sonnet) _tcm_base="${_CLAUDE_CURSOR_PREFIX}-sonnet" ;;
        haiku)  _cursor_model="auto"; return 0 ;;  # terminal — skip step 2
        gpt-*)  _tcm_base="$_tcm_model" ;;  # pass through — cursor-agent rejects unknown IDs
        *)      return 1 ;;
    esac

    # Step 2 — compose cursor-agent model ID with effort
    case "$_tcm_base" in
        "${_CLAUDE_CURSOR_PREFIX}-sonnet")
            # Sonnet: only medium-thinking variant available on cursor-agent
            _cursor_model="${_tcm_base}-medium-thinking" ;;
        "${_CLAUDE_CURSOR_PREFIX}"-*)
            # Other Claude models: effort + thinking suffix
            _cursor_model="${_tcm_base}-${_tcm_effort}-thinking" ;;
        gpt-*)
            # GPT models: effort suffix, no thinking
            _cursor_model="${_tcm_base}-${_tcm_effort}" ;;
    esac
    return 0
}

if [ -n "$fallback_for" ]; then
    # Fallback mode: mirror the failed provider’s model via cursor-agent.
    # Prefer --model/--effort from caller (respects env var overrides);
    # fall back to resolve_tier when not provided.
    if [ -n "$_fb_model" ] && [ -n "$_fb_effort" ]; then
        _fallback_model="$_fb_model"
        _fallback_effort="$_fb_effort"
    else
        resolve_tier "$tier" "$fallback_for"
        # shellcheck disable=SC2154  # _tier_model, _tier_effort set by resolve_tier()
        _fallback_model="$_tier_model"
        _fallback_effort="$_tier_effort"
    fi
    if ! to_cursor_model "$_fallback_model" "$_fallback_effort"; then
        error "No cursor-agent equivalent for model ‘$_fallback_model’"
        exit 1
    fi
    model="$_cursor_model"
else
    # Direct cursor dispatch: tier → Cursor pool via env var cascade
    resolve_tier "$tier" cursor
    case "$tier" in
        frontier) model="${SPINE_ENVOY_FRONTIER_CURSOR:-${SPINE_ENVOY_CURSOR:-$_tier_model}}" ;;
        fast)     model="${SPINE_ENVOY_FAST_CURSOR:-${SPINE_ENVOY_CURSOR:-$_tier_model}}" ;;
        *)        model="${SPINE_ENVOY_STANDARD_CURSOR:-${SPINE_ENVOY_CURSOR:-$_tier_model}}" ;;
    esac
fi
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

# Model-level retry: rate limit → auto (different usage pool).
# Auto uses Cursor's routing with a separate allocation from named models.
# Only retry rate-limit failures; other errors propagate to fallback.sh.
# Guard: skip when model is already auto (haiku fallback or direct auto dispatch).
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
