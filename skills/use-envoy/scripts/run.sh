#!/bin/sh
# Cross-provider envoy dispatcher.
# Detects current provider, picks target, delegates, handles fallback.
# Exit: propagates exit code from provider script.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: run.sh --hint claude|codex|cursor --prompt-file PATH --output-file PATH --stderr-log PATH [--timeout SECS] [--tier frontier|standard|fast] [--target <provider>] [--mode single|multi]

Detect current provider, invoke opposite provider's CLI, fall back on failure.
EOF
}

# --- Argument parsing ---

hint="" prompt_file="" output_file="" stderr_log="" timeout_secs="540" tier="standard" target="" mode="single"

while [ $# -gt 0 ]; do
    case "$1" in
        --hint)         hint="$2"; shift 2 ;;
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
        --timeout)      timeout_secs="$2"; shift 2 ;;
        --tier)         tier="$2"; shift 2 ;;
        --target)       target="$2"; shift 2 ;;
        --mode)         mode="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              error "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

[ -n "$prompt_file" ] || { error "Missing --prompt-file"; usage; exit 1; }
[ -n "$output_file" ] || { error "Missing --output-file"; usage; exit 1; }
[ -n "$stderr_log" ]  || { error "Missing --stderr-log"; usage; exit 1; }
case "$tier" in frontier|standard|fast) ;; *) error "Invalid --tier '$tier' (expected: frontier|standard|fast)"; exit 1 ;; esac
case "$mode" in single|multi) ;; *) error "Invalid --mode '$mode' (expected: single|multi)"; exit 1 ;; esac
if [ "$mode" = "multi" ] && [ -n "$target" ]; then
    error "--mode multi and --target are mutually exclusive"; exit 1
fi
if [ "$mode" = "multi" ]; then
    case "$output_file" in *.md) ;; *) error "--mode multi requires --output-file ending in .md"; exit 1 ;; esac
fi

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

# --- Multi-mode: parallel dispatch to all available providers ---

if [ "$mode" = "multi" ]; then
    # --- Provider discovery ---
    if [ -n "${SPINE_ENVOY_PROVIDERS:-}" ]; then
        _providers=$(printf '%s' "$SPINE_ENVOY_PROVIDERS" | tr ',' ' ')
    else
        _providers="claude codex cursor"
    fi

    # --- Normalize: validate, deduplicate, exclude self ---
    _seen="" _launched=""
    for _p in $_providers; do
        # Unknown provider guard
        if [ ! -f "$_script_dir/run-${_p}.sh" ]; then
            printf 'Warning: unknown provider "%s", skipping\n' "$_p" >&2
            continue
        fi
        # Deduplicate
        case " $_seen " in *" $_p "*) continue ;; esac
        _seen="$_seen $_p"
        # Exclude self
        [ "$_p" = "$_self" ] && continue
        _launched="$_launched $_p"
    done

    # --- Zero-provider guard ---
    if [ -z "$_launched" ]; then
        error "No providers available (self=$_self, candidates:$_seen)"
        exit 1
    fi

    _base="${output_file%.md}"

    # --- Kill children on interrupt (NOT EXIT — fires during normal completion) ---
    _child_pids=""
    # shellcheck disable=SC2329  # invoked via trap
    _kill_children() {
        for _kill_pid in $_child_pids; do
            kill "$_kill_pid" 2>/dev/null || true
        done
    }
    trap '_kill_children' INT TERM

    # --- Parallel dispatch ---
    for _p in $_launched; do
        sh "$_script_dir/run-${_p}.sh" \
            --prompt-file "$prompt_file" \
            --output-file "${_base}.${_p}.md" \
            --stderr-log "${_base}.${_p}.log" \
            --timeout "$timeout_secs" \
            --tier "$tier" \
            >/dev/null &
        _child_pids="$_child_pids $!"
    done

    # --- Wait + collect exit codes (first-nonzero propagation) ---
    _aggregate=0
    for _pid in $_child_pids; do
        _rc=0
        wait "$_pid" || _rc=$?
        [ "$_aggregate" -eq 0 ] && _aggregate="$_rc"
    done

    # --- Manifest: print paths for successfully created output files ---
    for _p in $_launched; do
        [ -f "${_base}.${_p}.md" ] && printf '%s\n' "${_base}.${_p}.md"
    done

    exit "$_aggregate"
fi

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
