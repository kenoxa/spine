#!/bin/sh
# Fallback wrapper for envoy provider dispatch.
# Runs a target invoke script; on fast-failure (rate limit, auth error),
# iterates a 2-deep fallback chain trying alternative providers.
# Exit: propagates exit code from successful invoke or last failure.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# --- Argument parsing ---

_self="" _tier="standard" _chain=""
_prompt_file="" _output_file="" _stderr_log=""

while [ $# -gt 0 ]; do
    case "$1" in
        --self)         _self="$2"; shift 2 ;;
        --tier)         _tier="$2"; shift 2 ;;
        --chain)        _chain="$2"; shift 2 ;;
        --prompt-file)  _prompt_file="$2"; shift 2 ;;
        --output-file)  _output_file="$2"; shift 2 ;;
        --stderr-log)   _stderr_log="$2"; shift 2 ;;
        --)             shift; break ;;
        *)              error "Unknown fallback.sh argument: $1"; exit 1 ;;
    esac
done

# Remaining args = invoke script path (required)
[ $# -gt 0 ] || { error "No invoke script after --"; exit 1; }
_invoke_script="$1"; shift
_script_dir=$(cd "$(dirname "$_invoke_script")" && pwd)

# Extract target provider from script name (invoke-{provider}.sh)
_bn=$(basename "$_invoke_script" .sh)
_target="${_bn#invoke-}"

# --- Fast-failure detection ---
# Grep stderr for rate-limit and auth-failure patterns.
# Tightened patterns per challenge F4 to avoid false positives.

is_fast_failure() {
    [ -f "$1" ] || return 1
    grep -qiE 'rate[ _-]limit|rate_limited|hit a rate limit|quota|credits.*exhaust|out of usage|increase.*limit|not logged in|not authenticated|authorization.*error' "$1"
}

# --- Run target invoke ---

_rc=0
sh "$_invoke_script" \
    --prompt-file "$_prompt_file" \
    --output-file "$_output_file" \
    --stderr-log "$_stderr_log" \
    --tier "$_tier" \
    || _rc=$?

# Exit 0 → success
[ "$_rc" -ne 0 ] || exit 0

# Exit 124/137 (timeout), 2 (interrupted), 3 (validation) → propagate, no fallback
case "$_rc" in 124|137|2|3) exit "$_rc" ;; esac

# Exit 1 → check for fast-failure
if ! is_fast_failure "$_stderr_log"; then
    [ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: no fast-failure pattern in stderr, propagating exit %s\n' "$_rc" >&2
    exit "$_rc"
fi

[ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: fast-failure detected for %s, trying chain: %s\n' "$_target" "$_chain" >&2

# --- Iterate fallback chain ---

_chain_list=$(printf '%s' "$_chain" | tr ',' ' ')
_last_rc="$_rc"

for _fb in $_chain_list; do
    # Self-exclusion
    [ "$_fb" != "$_self" ] || continue
    # Skip the target that just failed
    [ "$_fb" != "$_target" ] || continue

    # Check availability
    if ! sh "$_script_dir/check-${_fb}.sh" >/dev/null 2>&1; then
        [ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: %s unavailable, skipping\n' "$_fb" >&2
        continue
    fi

    printf '%s failed (exit %s), attempting %s fallback\n' "$_target" "$_last_rc" "$_fb" >&2

    _fb_script="$_script_dir/invoke-${_fb}.sh"

    # Determine if this is the last viable fallback in chain
    _remaining=0
    _past_current=false
    for _check_fb in $_chain_list; do
        if [ "$_check_fb" = "$_fb" ]; then _past_current=true; continue; fi
        $_past_current || continue
        [ "$_check_fb" != "$_self" ] || continue
        [ "$_check_fb" != "$_target" ] || continue
        _remaining=$((_remaining + 1))
    done

    if [ "$_remaining" -eq 0 ]; then
        # Final invoke — exec replaces process, signal propagation automatic
        # shellcheck disable=SC2093
        exec sh "$_fb_script" \
            --prompt-file "$_prompt_file" \
            --output-file "$_output_file" \
            --stderr-log "$_stderr_log" \
            --tier "$_tier" \
            --fallback-for "$_target"
    fi

    # Non-final — run with signal trap forwarding
    _child=""
    trap 'kill "$_child" 2>/dev/null; exit 130' INT TERM
    _last_rc=0
    sh "$_fb_script" \
        --prompt-file "$_prompt_file" \
        --output-file "$_output_file" \
        --stderr-log "$_stderr_log" \
        --tier "$_tier" \
        --fallback-for "$_target" &
    _child=$!
    wait "$_child" || _last_rc=$?
    trap - INT TERM

    [ "$_last_rc" -eq 0 ] && exit 0

    # Check if this fallback also fast-failed
    if is_fast_failure "$_stderr_log"; then
        [ "${SPINE_ENVOY_DEBUG:-}" = "1" ] && printf 'fallback: %s also fast-failed, continuing chain\n' "$_fb" >&2
        continue
    fi
    # Non-fast failure from fallback — propagate
    exit "$_last_rc"
done

# All fallbacks exhausted
exit "$_last_rc"
