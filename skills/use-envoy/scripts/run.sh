#!/bin/sh
# Cross-provider envoy dispatcher.
# Detects current provider, picks target, delegates via fallback wrapper.
# Exit: propagates exit code from provider script.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: run.sh --hint claude|codex|cursor --prompt-file PATH --output-file PATH --stderr-log PATH [--tier frontier|standard|fast] [--target <provider>] [--mode single|multi]

Detect current provider, invoke opposite provider's CLI, fall back on failure.
EOF
}

# --- Argument parsing ---

hint="" prompt_file="" output_file="" stderr_log="" tier="standard" target="" mode="single"

while [ $# -gt 0 ]; do
    case "$1" in
        --hint)         hint="$2"; shift 2 ;;
        --prompt-file)  prompt_file="$2"; shift 2 ;;
        --output-file)  output_file="$2"; shift 2 ;;
        --stderr-log)   stderr_log="$2"; shift 2 ;;
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

# --- Strip assembly directive header from prompt file (defense-in-depth) ---
# Ref: use-envoy/SKILL.md "Dispatch Prompt Framing" template defines this header.
# The envoy agent should omit it (agents/envoy.md step 2), but strip if leaked.
if [ -f "$prompt_file" ]; then
    _first_line=$(head -n 1 "$prompt_file")
    case "$_first_line" in
        "Assemble a self-contained prompt"*)
            _sep_line=$(grep -n '^---[[:space:]]*$' "$prompt_file" | head -n 1 | cut -d: -f1)
            if [ -n "$_sep_line" ]; then
                tail -n +"$((_sep_line + 1))" "$prompt_file" > "${prompt_file}.tmp"
            else
                # No separator — strip just the directive line
                tail -n +2 "$prompt_file" > "${prompt_file}.tmp"
                printf 'Warning: assembly directive found without --- separator, stripped line 1 only\n' >&2
            fi
            mv "${prompt_file}.tmp" "$prompt_file"
            printf 'Notice: stripped assembly directive header from prompt file\n' >&2
            [ -s "$prompt_file" ] || { error "Prompt file empty after assembly-directive strip"; exit 1; }
            ;;
    esac
fi

# --- Strip file-write path instructions from prompt (defense-in-depth) ---
# Patterns frozen to current convention; CONTRIBUTING.md is the primary control.
if [ -f "$prompt_file" ]; then
    sed -E \
      -e 's/^Write to `[^`]+`\.? ?//' \
      -e '/^- Output path: `[^`]+`$/d' \
      "$prompt_file" > "${prompt_file}.tmp" && mv "${prompt_file}.tmp" "$prompt_file"
fi

# --- Detect self (env vars → hint → default) ---

_self=""
if printenv CLAUDECODE >/dev/null 2>&1; then
    _self=claude
elif [ "${CURSOR_AGENT:-}" = "1" ]; then
    _self=cursor
elif printenv CODEX_SANDBOX >/dev/null 2>&1; then
    _self=codex
elif [ "${QWEN_CODE:-}" = "1" ]; then
    _self=qwen
elif [ "${SPINE_ENVOY_COPILOT:-}" = "1" ]; then
    _self=copilot
fi
_self="${_self:-${hint:-codex}}"

# --- Multi-mode: parallel dispatch to all available providers ---

if [ "$mode" = "multi" ]; then
    # --- Provider discovery ---
    if [ -n "${SPINE_ENVOY_PROVIDERS:-}" ]; then
        _providers=$(printf '%s' "$SPINE_ENVOY_PROVIDERS" | tr ',' ' ')
    else
        _providers="claude codex cursor qwen"
    fi

    # --- Normalize: validate, deduplicate, exclude self ---
    _seen="" _launched=""
    for _p in $_providers; do
        # Unknown provider guard
        if [ ! -f "$_script_dir/invoke-${_p}.sh" ]; then
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

    # --- Parallel dispatch with per-slot fallback ---
    for _p in $_launched; do
        sh "$_script_dir/fallback.sh" \
            --self "$_self" --tier "$tier" --chain "copilot,cursor" \
            --prompt-file "$prompt_file" \
            --output-file "${_base}.${_p}.md" \
            --stderr-log "${_base}.${_p}.log" \
            -- "$_script_dir/invoke-${_p}.sh" \
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

_base="${output_file%.md}"

if [ -n "$target" ]; then
    [ "$target" != "$_self" ] || { error "--target '$target' matches self '$_self'"; exit 1; }
    if ! sh "$_script_dir/check-${target}.sh" >/dev/null 2>&1; then
        error "Target provider $target unavailable"; exit 1
    fi
    _out="${_base}.${target}.md"
    sh "$_script_dir/invoke-${target}.sh" \
        --prompt-file "$prompt_file" --output-file "$_out" \
        --stderr-log "$stderr_log" --tier "$tier"
    _rc=$?
    # stdout: actual output path
    [ "$_rc" -eq 0 ] && [ -f "$_out" ] && printf '%s\n' "$_out"
    exit "$_rc"
fi

# --- Pick target and fallback chain (never target self) ---

case "$_self" in
    claude)  _target=codex;  _chain="copilot,cursor" ;;
    codex)   _target=claude; _chain="copilot,cursor" ;;
    cursor)  _target=codex;  _chain="copilot,cursor" ;;
    qwen)    _target=codex;  _chain="copilot,cursor" ;;
    copilot) _target=claude; _chain="cursor,codex" ;;
    *)       _target=codex; _chain="copilot,cursor" ;;
esac

# --- Invoke via fallback wrapper ---
# Output naming: single-mode now uses {base}.{target}.md for consistency with multi-mode.

_out="${_base}.${_target}.md"

# shellcheck disable=SC2093
exec sh "$_script_dir/fallback.sh" \
    --self "$_self" --tier "$tier" --chain "$_chain" \
    --prompt-file "$prompt_file" \
    --output-file "$_out" \
    --stderr-log "$stderr_log" \
    -- "$_script_dir/invoke-${_target}.sh"
# Dead-code guard (exec replaces process)
error "exec failed"; exit 1
