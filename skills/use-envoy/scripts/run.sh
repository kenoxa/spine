#!/bin/sh
# Cross-provider envoy dispatcher.
# Detects current provider, picks target, delegates, handles fallback.
# Exit: propagates exit code from provider script.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: run.sh --hint claude|codex|cursor --prompt-file PATH --output-file PATH --stderr-log PATH [--timeout SECS] [--tier frontier|standard|fast] [--target <provider>]

Detect current provider, invoke opposite provider's CLI, fall back on failure.
EOF
}

# --- Argument parsing ---

hint="" prompt_file="" output_file="" stderr_log="" timeout_secs="900" tier="standard" target=""

while [ $# -gt 0 ]; do
    case "$1" in
        --hint)         hint="$2"; shift 2 ;;
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
        --timeout)      timeout_secs="$2"; shift 2 ;;
        --tier)         tier="$2"; shift 2 ;;
        --target)       target="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              error "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

[ -n "$prompt_file" ] || { error "Missing --prompt-file"; usage; exit 1; }
[ -n "$output_file" ] || { error "Missing --output-file"; usage; exit 1; }
[ -n "$stderr_log" ]  || { error "Missing --stderr-log"; usage; exit 1; }
case "$tier" in frontier|standard|fast) ;; *) error "Invalid --tier '$tier' (expected: frontier|standard|fast)"; exit 1 ;; esac

_script_dir=$(cd "$(dirname "$0")" && pwd)

# --- Detect self (env vars → hint → default) ---

_self=""
if printenv CLAUDECODE >/dev/null 2>&1; then
    _self=claude
elif [ "${CURSOR_AGENT:-}" = "1" ]; then
    _self=cursor
elif printenv CODEX_SANDBOX >/dev/null 2>&1; then
    _self=codex
fi
_self="${_self:-${hint:-codex}}"

# --- Direct target (--target flag bypasses cascade) ---

if [ -n "$target" ]; then
    [ "$target" != "$_self" ] || { error "--target '$target' matches self '$_self'"; exit 1; }
    if ! sh "$_script_dir/check-${target}.sh" >/dev/null 2>&1; then
        error "Target provider $target unavailable"; exit 1
    fi
    sh "$_script_dir/run-${target}.sh" \
        --prompt-file "$prompt_file" --output-file "$output_file" \
        --stderr-log "$stderr_log" --timeout "$timeout_secs" --tier "$tier"
    exit $?
fi

# --- Pick target and fallback (never target or fall back to self) ---

case "$_self" in
    claude) _target=codex;  _fallback=cursor ;;
    cursor) _target=claude; _fallback=codex ;;
    *)      _target=claude; _fallback=cursor ;;
esac

# --- Invoke target ---

_rc=0
if sh "$_script_dir/check-${_target}.sh" >/dev/null 2>&1; then
    sh "$_script_dir/run-${_target}.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$output_file" \
        --stderr-log "$stderr_log" \
        --timeout "$timeout_secs" \
        --tier "$tier" \
        || _rc=$?
else
    printf 'Target provider %s unavailable, skipping to fallback\n' "$_target" >&2
    _rc=1
fi

# Exit 0 (success) → propagate, no fallback
if [ "$_rc" -eq 0 ]; then
    exit 0
fi

# --- Fallback on exit 1 (invocation failed), 2 (timeout), or 3 (output validation failed) ---

if ! sh "$_script_dir/check-${_fallback}.sh" >/dev/null 2>&1; then
    error "Fallback provider $_fallback also unavailable"
    exit "$_rc"
fi

printf '%s failed (exit %s), attempting %s fallback\n' "$_target" "$_rc" "$_fallback" >&2

if [ "$_fallback" = "cursor" ]; then
    # shellcheck disable=SC2093
    exec sh "$_script_dir/run-cursor.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$output_file" \
        --stderr-log "$stderr_log" \
        --timeout "$timeout_secs" \
        --tier "$tier" \
        --fallback-for "$_target"
else
    # shellcheck disable=SC2093
    exec sh "$_script_dir/run-${_fallback}.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$output_file" \
        --stderr-log "$stderr_log" \
        --timeout "$timeout_secs" \
        --tier "$tier"
fi
# Dead-code guard (exec replaces process)
error "exec failed"; exit 1
