#!/bin/sh
# Fallback helper — called BY invoke scripts after primary invocation fails.
# On fast-failure (rate limit, auth error, stale model), attempts cursor-agent
# as single-hop fallback. Non-fast failures propagate the original exit code.
# Exit: exec's into invoke-cursor.sh on fast-failure, or returns original exit code.

set -eu

_script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=_common.sh
. "$_script_dir/_common.sh"

# --- Argument parsing ---

_provider="" _tier="standard" _exit_code="" _model="" _effort=""
_prompt_file="" _output_file="" _stderr_log=""

while [ $# -gt 0 ]; do
    case "$1" in
        --provider)     _provider="$2"; shift 2 ;;
        --tier)         _tier="$2"; shift 2 ;;
        --exit-code)    _exit_code="$2"; shift 2 ;;
        --model)        _model="$2"; shift 2 ;;
        --effort)       _effort="$2"; shift 2 ;;
        --prompt-file)  _prompt_file="$2"; shift 2 ;;
        --output-file)  _output_file="$2"; shift 2 ;;
        --stderr-log)   _stderr_log="$2"; shift 2 ;;
        *)              printf 'Error: Unknown fallback.sh argument: %s\n' "$1" >&2; exit 1 ;;
    esac
done

[ -n "$_provider" ]    || { printf 'Error: Missing --provider\n' >&2; exit 1; }
[ -n "$_exit_code" ]   || { printf 'Error: Missing --exit-code\n' >&2; exit 1; }
[ -n "$_prompt_file" ] || { printf 'Error: Missing --prompt-file\n' >&2; exit 1; }
[ -n "$_output_file" ] || { printf 'Error: Missing --output-file\n' >&2; exit 1; }
[ -n "$_stderr_log" ]  || { printf 'Error: Missing --stderr-log\n' >&2; exit 1; }

# --- Fast-failure gate ---

if ! is_fast_failure "$_stderr_log"; then
    [ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: no fast-failure pattern in stderr, propagating exit %s\n' "$_exit_code" >&2
    exit "$_exit_code"
fi

[ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: fast-failure detected for %s, trying cursor-agent\n' "$_provider" >&2

# --- Cursor-agent availability ---

if ! sh "$_script_dir/check-cursor.sh" >/dev/null 2>&1; then
    [ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: cursor-agent unavailable, propagating exit %s\n' "$_exit_code" >&2
    exit "$_exit_code"
fi

printf '%s failed (exit %s), attempting cursor-agent fallback\n' "$_provider" "$_exit_code" >&2

_model_args=""
[ -n "$_model" ]  && _model_args="$_model_args --model $_model"
[ -n "$_effort" ] && _model_args="$_model_args --effort $_effort"

# shellcheck disable=SC2086,SC2093
exec sh "$_script_dir/invoke-cursor.sh" \
    --prompt-file "$_prompt_file" \
    --output-file "$_output_file" \
    --stderr-log "$_stderr_log" \
    --tier "$_tier" \
    --fallback-for "$_provider" \
    $_model_args
