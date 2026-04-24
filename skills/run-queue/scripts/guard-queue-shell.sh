#!/bin/sh
# guard-queue-shell.sh — PreToolUse hook for run-queue overnight runs.
#
# Registered via settings overlay (skills/run-queue/settings-overlay.tmpl.json)
# passed on claude -p --settings by the supervisor. Inert outside queue runs
# (env-gated on SPINE_QUEUE=1) as defense-in-depth — the overlay scoping alone
# already limits when it fires.
#
# Adds only what overnight-autonomous execution needs beyond the user's global
# settings: deny all git push, deny out-of-repo writes, deny git -C sidestep.
# Recursive rm, docker escapes, curl uploads etc. remain governed by the user's
# global PreToolUse hook.
#
# Output contract: emits `permissionDecision: deny` JSON on block + exits 2.
# Fail-open (exit 0) only on missing-jq; every other failure path is deny.

set -eu

# --- Env gate ---
# Skill-scoped overlay already limits when this runs, but we gate again so a
# leaked registration cannot fire the queue hook in an interactive session.
[ "${SPINE_QUEUE:-}" = "1" ] || exit 0

# --- Hard deps ---
command -v jq >/dev/null 2>&1 || exit 0   # jq missing: fail-open with no action

# --- Required queue-context env ---

_missing=
[ -n "${SPINE_QUEUE_DIR:-}" ]     || _missing="$_missing SPINE_QUEUE_DIR"
[ -n "${SPINE_QUEUE_RUN_ID:-}" ]  || _missing="$_missing SPINE_QUEUE_RUN_ID"
[ -n "${SPINE_QUEUE_TASK_ID:-}" ] || _missing="$_missing SPINE_QUEUE_TASK_ID"
[ -n "${SPINE_QUEUE_REPO_ROOT:-}" ] || _missing="$_missing SPINE_QUEUE_REPO_ROOT"

_qdir=${SPINE_QUEUE_DIR:-}
_repo_root=${SPINE_QUEUE_REPO_ROOT:-}
_task=${SPINE_QUEUE_TASK_ID:-unknown}
_run=${SPINE_QUEUE_RUN_ID:-unknown}

# --- Output helpers ---

_stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_qlog_line() {
    # Append a single audit line to queue-log.md in the queue-dir.
    # Safe with concurrent writes inside a single task (one writer per task).
    [ -z "$_qdir" ] || [ ! -d "$_qdir" ] && return 0
    printf '%s  guard: %s\n' "$(_stamp)" "$*" >> "$_qdir/queue-log.md" 2>/dev/null || true
}

_woke() {
    # Create or append to WOKE-ME-UP.md — stops the run at the next supervisor check.
    _reason=$1
    _detail=$2
    [ -z "$_qdir" ] || [ ! -d "$_qdir" ] && return 0
    _woke_file="$_qdir/WOKE-ME-UP.md"
    if [ ! -f "$_woke_file" ]; then
        {
            printf '# Trip-wire — %s\n\n' "$_run"
            printf '> A permission guard fired. The queue has halted. Review the deny and decide.\n\n'
        } > "$_woke_file"
    fi
    {
        printf '## %s · task=%s\n\n' "$(_stamp)" "$_task"
        printf -- '- Reason: %s\n' "$_reason"
        printf -- '- Detail: `%s`\n' "$_detail"
        [ -n "${_agent_id:-}" ] && printf -- '- Agent: `%s` (type=%s)\n' "$_agent_id" "${_agent_type:-unknown}"
        printf '\n'
    } >> "$_woke_file"
}

_deny() {
    # _deny <short-reason> <full-detail>
    _qlog_line "DENY task=$_task tool=$_tool reason=$1 detail=$2"
    _woke "$1" "$2"
    # shellcheck disable=SC2016  # jq -n takes the template literally
    jq -n --arg r "run-queue guard: $1" '{
        "hookSpecificOutput":{
            "hookEventName":"PreToolUse",
            "permissionDecision":"deny",
            "permissionDecisionReason":$r
        }
    }'
    printf 'BLOCKED: %s\n' "$1" >&2
    exit 2
}

# --- Fail-secure on missing context ---

if [ -n "$_missing" ]; then
    _tool="(pre-parse)"
    _deny "missing-queue-context" "env vars missing:$_missing"
fi

# --- Parse stdin envelope ---

_input=$(cat)
_tool=$(printf '%s' "$_input" | jq -r '.tool_name // empty')
_agent_id=$(printf '%s' "$_input" | jq -r '.agent_id // empty')
_agent_type=$(printf '%s' "$_input" | jq -r '.agent_type // empty')

# --- Per-tool inspection ---

case "$_tool" in

Bash)
    _cmd=$(printf '%s' "$_input" | jq -r '.tool_input.command // empty')
    [ -z "$_cmd" ] && exit 0
    # Normalize: collapse newlines/tabs, strip leading rtk proxy prefix.
    _cmd_norm=$(printf '%s' "$_cmd" | tr '\n\t' '  ' | sed 's/^rtk //')

    # Built-in deny patterns.
    case "$_cmd_norm" in
        *"git push"*)
            _deny "git-push-blocked" "$_cmd_norm" ;;
        *"git -C "*)
            _deny "git-C-sidestep-blocked" "$_cmd_norm" ;;
    esac

    # Optional profile.json: extra_deny list.
    _profile="$_qdir/profile.json"
    if [ -f "$_profile" ] && jq -e . "$_profile" >/dev/null 2>&1; then
        _n=$(jq -r '.extra_deny | length // 0' "$_profile" 2>/dev/null)
        _i=0
        while [ "$_i" -lt "$_n" ]; do
            _rule=$(jq -c --argjson i "$_i" '.extra_deny[$i]' "$_profile")
            _i=$((_i + 1))
            _match=$(printf '%s' "$_rule" | jq -r '.match // empty')
            [ "$_match" != "Bash" ] && continue
            _pref=$(printf '%s' "$_rule" | jq -r '.command_prefix // empty')
            _regex=$(printf '%s' "$_rule" | jq -r '.command_regex // empty')
            _reason=$(printf '%s' "$_rule" | jq -r '.reason // "extra-deny"')
            if [ -n "$_pref" ]; then
                case "$_cmd_norm" in
                    "$_pref"*) _deny "$_reason" "$_cmd_norm" ;;
                esac
            fi
            if [ -n "$_regex" ] && printf '%s' "$_cmd_norm" | grep -qE "$_regex"; then
                _deny "$_reason" "$_cmd_norm"
            fi
        done
    fi
    ;;

Edit|Write|NotebookEdit)
    _path=$(printf '%s' "$_input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -z "$_path" ] && exit 0

    # Resolve to absolute
    case "$_path" in
        /*) _abs=$_path ;;
         *) _abs="${SPINE_QUEUE_CHILD_CWD:-$_repo_root}/$_path" ;;
    esac

    # Is it inside the repo root?
    case "$_abs" in
        "$_repo_root"/*|"$_repo_root") exit 0 ;;
    esac

    # Check allow_out_of_repo from profile.json
    _profile="$_qdir/profile.json"
    if [ -f "$_profile" ] && jq -e . "$_profile" >/dev/null 2>&1; then
        _i=0
        _n=$(jq -r '.allow_out_of_repo | length // 0' "$_profile" 2>/dev/null)
        while [ "$_i" -lt "$_n" ]; do
            _allow=$(jq -r --argjson i "$_i" '.allow_out_of_repo[$i]' "$_profile")
            _i=$((_i + 1))
            case "$_abs" in
                "$_allow"*) exit 0 ;;
            esac
        done
    fi

    _deny "out-of-repo-write" "$_abs"
    ;;

esac

exit 0
