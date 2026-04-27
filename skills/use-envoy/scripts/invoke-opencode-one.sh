#!/bin/sh
# Invoke a single OpenCode worker with isolated XDG_DATA_HOME.
# Called by invoke-opencode.sh orchestrator for each model in the fanout.
# Exit: 0=success, 1=invocation failed, 2=timed out, 3=output validation failed

set -eu
umask 077

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: invoke-opencode-one.sh --prompt-file PATH --output-file PATH --stderr-log PATH --model MODEL [--effort high]

Single OpenCode worker with XDG_DATA_HOME isolation. Used by invoke-opencode.sh orchestrator.
EOF
}

# --- Argument parsing ---

prompt_file="" output_file="" stderr_log="" model="" effort="high"

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
        --model)        model="$2"; shift 2 ;;
        --effort)       effort="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              error "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

[ -n "$prompt_file" ] || { error "Missing --prompt-file"; usage; exit 1; }
[ -n "$output_file" ] || { error "Missing --output-file"; usage; exit 1; }
[ -n "$stderr_log" ]  || { error "Missing --stderr-log"; usage; exit 1; }
[ -n "$model" ]       || { error "Missing --model"; usage; exit 1; }
[ -f "$prompt_file" ] || { error "Prompt file not found: $prompt_file"; exit 1; }
[ -s "$prompt_file" ] || { error "Prompt file is empty: $prompt_file"; exit 1; }

# --- Shared functions ---

_script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=_common.sh
. "$_script_dir/_common.sh"
# shellcheck source=_opencode-common.sh
. "$_script_dir/_opencode-common.sh"

command -v jq >/dev/null 2>&1 || { error "jq required but not found"; exit 1; }

# --- XDG isolation ---
#
# Each worker gets its own XDG_DATA_HOME so opencode.db is per-process.
# This prevents SQLITE_BUSY and file-watcher cross-contamination (issue #4251).
#
_worker_xdg="$(mktemp -d)"
export XDG_DATA_HOME="$_worker_xdg"

# Combine _cleanup (from _common.sh) with XDG dir removal.
_cleanup_all() { _cleanup; rm -rf "$_worker_xdg"; }
trap _cleanup_all EXIT INT TERM

# --- Pre-flight ---

preflight_check

# --- Invoke single worker ---

opencode_invoke "$model" "$effort"

if [ "$_rc" -eq 124 ] || [ "$_rc" -eq 137 ]; then
    error "OpenCode CLI timed out after ${_opencode_timeout}s (model=$model)"; exit 2
fi
emit_auth_hint "run 'opencode providers login'"
handle_exit_code "OpenCode CLI ($model)"
stop_timer

# --- Extract ---

opencode_extract

# --- Validate + sanitize + assemble ---

validate_output

_meta_provider="OpenCode"
_meta_model="$model"
_meta_effort="$effort"
_meta_fallback_note=""

assemble_output
finalize_output
