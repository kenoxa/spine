#!/bin/sh
# Invoke OpenCode (generic best-of-breed) via OpenCode CLI headlessly for cross-provider envoy.
# Multi-model orchestrator: resolves tier → fanout[] → parallel dispatch with XDG isolation.
# Exit: 0=≥1 worker succeeded, 1=all workers failed, 2=interrupted (provider-specific), 3=output validation failed

echo "DEBUG: script started argv=$0" >&2
set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: invoke-opencode.sh --prompt-file PATH --output-file PATH --stderr-log PATH [--tier frontier|standard|fast]

Invoke OpenCode (generic best-of-breed) via OpenCode CLI headlessly with sanitized environment.
Multi-model parallel dispatch with per-worker XDG_DATA_HOME isolation.
EOF
}

# --- Argument parsing ---

prompt_file="" output_file="" stderr_log="" tier="standard" fallback_for=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
        --tier)         tier="$2"; shift 2 ;;
        --fallback-for) fallback_for="$2"; shift 2 ;;
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

command -v jq >/dev/null 2>&1 || { error "jq required but not found"; exit 1; }
echo "DEBUG: after jq check" >&2

# --- Detect OpenCode tier (Go subscription vs Free) ---

_oc_tier="opencode-free"  # default to free
if timeout 10 opencode models opencode-go 2>/dev/null | grep -q .; then
    _oc_tier="opencode"
fi
echo "DEBUG: after oc_tier=$_oc_tier" >&2

# --- Tier-aware model selection ---

resolve_tier "$tier" "$_oc_tier"
echo "DEBUG: after resolve_tier fanout=$_tier_fanout" >&2

# --- Check env overrides (format: model[:effort]) ---
# When an override is set, it replaces the fanout with a single model.
_envoy_val=""
case "$tier" in
    frontier) _envoy_val="${SPINE_ENVOY_FRONTIER_OPENCODE:-${SPINE_ENVOY_OPENCODE:-}}" ;;
    fast)     _envoy_val="${SPINE_ENVOY_FAST_OPENCODE:-${SPINE_ENVOY_OPENCODE:-}}" ;;
    *)        _envoy_val="${SPINE_ENVOY_STANDARD_OPENCODE:-${SPINE_ENVOY_OPENCODE:-}}" ;;
esac

_stderr_base="${output_file%.md}"

# Pre-flight on shared state
preflight_check
echo "DEBUG: after preflight" >&2

# --- Dispatch ---

if [ -n "$_envoy_val" ]; then
    # --- Env override: single-model path (no fanout) ---
    _model="${_envoy_val%%:*}"
    _effort="${_envoy_val#*:}"
    [ "$_effort" = "$_model" ] && _effort="$_tier_effort"

    # Use slug naming for consistency with multi-model
    _slug=$(printf '%s' "$_model" | sed 's|^opencode-go/||; s|/|-|g')
    _out="${_stderr_base}.${_slug}.md"

    sh "$_script_dir/invoke-opencode-one.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$_out" \
        --stderr-log "$stderr_log" \
        --model "$_model" \
        --effort "$_effort"

    _rc=$?
    [ "$_rc" -eq 0 ] && printf '%s\n' "$_out"
    exit "$_rc"
fi

# --- Multi-model fanout ---

# Count models in fanout
_worker_count=0
for _m in $_tier_fanout; do
    _worker_count=$((_worker_count + 1))
done

if [ "$_worker_count" -eq 1 ]; then
    # N=1: single-worker — use slug naming (same codepath as N≥1, list semantics)
    _slug=$(printf '%s' "$_tier_primary" | sed 's|^opencode-go/||; s|/|-|g')
    _worker_file="${_stderr_base}.${_slug}.md"

    sh "$_script_dir/invoke-opencode-one.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$_worker_file" \
        --stderr-log "$stderr_log" \
        --model "$_tier_primary" \
        --effort "$_tier_effort"

    _rc=$?
    [ "$_rc" -eq 0 ] && [ -s "$_worker_file" ] && printf '%s\n' "$_worker_file"
    exit "$_rc"
fi

# N≥1: parallel dispatch with XDG isolation per worker
echo "DEBUG: before fanout worker_count=$_worker_count" >&2

_worker_pids=""
_worker_files=""

for _model in $_tier_fanout; do
    # Derive slug: strip opencode-go/ prefix, replace / with - (defense-in-depth)
    _slug=$(printf '%s' "$_model" | sed 's|^opencode-go/||; s|/|-|g')
    _worker_file="${_stderr_base}.${_slug}.md"
    _worker_log="${_stderr_base}.${_slug}.log"

    sh "$_script_dir/invoke-opencode-one.sh" \
        --prompt-file "$prompt_file" \
        --output-file "$_worker_file" \
        --stderr-log "$_worker_log" \
        --model "$_model" \
        --effort "$_tier_effort" &
    _worker_pids="$_worker_pids $!"
    _worker_files="$_worker_files $_worker_file"

    # Stagger startup 250ms (SHOULD — reduces SQLITE_BUSY risk)
    if [ "$_worker_count" -gt 1 ]; then
        sleep 0.25
    fi
done

# Wait for all workers
echo "DEBUG: before wait pids=$_worker_pids" >&2
for _pid in $_worker_pids; do
    wait "$_pid" 2>/dev/null || true
done

# Emit successful output paths to stdout
_success_count=0
for _f in $_worker_files; do
    if [ -f "$_f" ] && [ -s "$_f" ]; then
        printf '%s\n' "$_f"
        _success_count=$((_success_count + 1))
    fi
done

# Aggregate stderr from all workers into the main stderr log
{
    for _f in "${_stderr_base}."*.log; do
        [ -f "$_f" ] || continue
        printf '--- worker: %s ---\n' "$(basename "$_f" .log)"
        cat "$_f"
        echo ""
    done
} > "$stderr_log" 2>/dev/null || true

# ≥1 worker succeeded → exit 0; all failed → exit 1
if [ "$_success_count" -ge 1 ]; then
    exit 0
fi
error "All OpenCode workers failed"
exit 1
