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

# --- GNU tool detection (Homebrew coreutils preferred on macOS) ---
# Fail-secure: missing GNU realpath → deny with diagnostic at first Edit/Write call.
# On macOS with Homebrew coreutils: grealpath. On Linux: realpath (GNU default).
for _bin in realpath; do
    if command -v "g${_bin}" >/dev/null 2>&1; then
        eval "_GNU_${_bin}=g${_bin}"
    elif command -v "$_bin" >/dev/null 2>&1 && "$_bin" --version 2>&1 | grep -q GNU; then
        eval "_GNU_${_bin}=$_bin"
    else
        # Cannot canonicalize paths → deny at first Edit/Write tool call.
        eval "_GNU_${_bin}="
    fi
done

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
    [ -z "$_qdir" ] && return 0
    [ ! -d "$_qdir" ] && return 0
    printf '%s  guard: %s\n' "$(_stamp)" "$*" >> "$_qdir/queue-log.md" 2>/dev/null || true
}

_woke() {
    # Create or append to WOKE-ME-UP.md — stops the run at the next supervisor check.
    _reason=$1
    _detail=$2
    [ -z "$_qdir" ] && return 0
    [ ! -d "$_qdir" ] && return 0
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

# --- Profile.json cached once per hook invocation (may be absent) ---
_profile_path="$_qdir/profile.json"
_profile_json=""
if [ -f "$_profile_path" ]; then
    _profile_json=$(jq -c . "$_profile_path" 2>/dev/null) || _profile_json=""
fi

# --- Per-tool inspection ---

case "$_tool" in

Bash)
    _cmd=$(printf '%s' "$_input" | jq -r '.tool_input.command // empty')
    [ -z "$_cmd" ] && exit 0
    # Normalize: collapse newlines/tabs, strip leading rtk proxy prefix.
    _cmd_norm=$(printf '%s' "$_cmd" | tr '\n\t' '  ' | sed 's/^rtk //')

    # Built-in deny patterns — two layers:
    # 1. Substring pre-check catches chained forms (e.g. `foo && git push`)
    #    where the tokenizer would only see the first command.
    # 2. Tokenized scan catches option-bearing forms the substring misses
    #    (e.g. `git --git-dir=/other push`, `git -c K=V push`).

    # Layer 1: fast substring pre-check (B2 + F4 blast coverage for chained cmds)
    #
    # Dual-layer deny: unbounded substring catches chain/wrap/quote-prefix forms
    # (e.g. `(git push)`, `bash -c "git push"`, `/usr/bin/git push`, `foo && git push`);
    # tokenizer (_is_blocked_git) catches option-bearing forms where `git` and the
    # blocked subcommand are non-adjacent (e.g. `git --git-dir=/X push`).
    #
    # Known limitation: fully-obfuscated program tokens (`"git" push`, `$(which git)
    # push`) bypass both layers because the literal substring `git push` does not
    # appear and the tokenizer's first-word check rejects non-literal `git`. The
    # supervisor adds a git-config belt (url.disabled:///.pushInsteadOf) in the child
    # spawn env so push attempts fail at git itself regardless of hook bypass.
    # See skills/run-queue/references/permission-profile.md for the trust model.
    case "$_cmd_norm" in
        *"git push"*)         _deny "git-push-blocked"         "$_cmd_norm" ;;
        *"git send-pack"*)    _deny "git-send-pack-blocked"    "$_cmd_norm" ;;
        *"git bundle"*)       _deny "git-bundle-blocked"       "$_cmd_norm" ;;
        *"git format-patch"*) _deny "git-format-patch-blocked" "$_cmd_norm" ;;
        *"git -C "*)          _deny "git-C-sidestep-blocked"   "$_cmd_norm" ;;
    esac

    # Layer 2: tokenized scan — catches option-bearing bypasses (B2 + F4)
    # Skip leading VAR=value env-var assignments; then expect "git" as program.
    _is_blocked_git() {
        _cmd_in=$1
        # shellcheck disable=SC2086  # intentional word-split on normalized command
        set -- $_cmd_in
        while [ $# -gt 0 ]; do
            case "$1" in
                *=*) shift ;;
                *) break ;;
            esac
        done
        [ "${1:-}" = "git" ] || return 1
        shift
        for _a in "$@"; do
            case "$_a" in
                push|send-pack|bundle|format-patch|-C)
                    printf '%s' "$_a"; return 0 ;;
                --git-dir=*)  printf 'git-dir';   return 0 ;;
                --work-tree=*) printf 'work-tree'; return 0 ;;
            esac
        done
        return 1
    }
    if _blocked_arg=$(_is_blocked_git "$_cmd_norm"); then
        _deny "git-${_blocked_arg}-blocked" "$_cmd_norm"
    fi

    # Optional profile.json: extra_deny list.
    if [ -n "$_profile_json" ]; then
        _n=$(printf '%s' "$_profile_json" | jq -r '.extra_deny | length // 0')
        _i=0
        while [ "$_i" -lt "$_n" ]; do
            _rule=$(printf '%s' "$_profile_json" | jq -c --argjson i "$_i" '.extra_deny[$i]')
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

    # Fail-secure: require GNU realpath for canonicalization (B1 + B3).
    # Without it we cannot safely resolve `..` traversal or symlinks.
    [ -n "${_GNU_realpath:-}" ] || _deny "missing-gnu-realpath" "brew install coreutils"

    # Resolve to absolute first (relative paths joined to repo root)
    case "$_path" in
        /*) _abs=$_path ;;
         *) _abs="$_repo_root/$_path" ;;
    esac

    # Canonicalize: resolves `..` traversal (B1) AND follows symlinks (B3).
    # `-m` allows non-existent path components (needed for Write-to-new-file).
    _canon=$("$_GNU_realpath" -m -- "$_abs" 2>/dev/null) || \
        _deny "realpath-failed" "$_abs"
    _canon_root=$("$_GNU_realpath" -m -- "$_repo_root" 2>/dev/null) || \
        _deny "realpath-repo-root-failed" "$_repo_root"

    # Is the canonicalized path inside the canonicalized repo root?
    case "$_canon" in
        "$_canon_root"/*|"$_canon_root") exit 0 ;;
    esac

    # Check allow_out_of_repo from profile.json (entries also canonicalized)
    if [ -n "$_profile_json" ]; then
        _i=0
        _n=$(printf '%s' "$_profile_json" | jq -r '.allow_out_of_repo | length // 0')
        while [ "$_i" -lt "$_n" ]; do
            _allow=$(printf '%s' "$_profile_json" | jq -r --argjson i "$_i" '.allow_out_of_repo[$i]')
            _i=$((_i + 1))
            _allow_canon=$("$_GNU_realpath" -m -- "$_allow" 2>/dev/null) || continue
            case "$_canon" in
                "$_allow_canon"/*|"$_allow_canon") exit 0 ;;
            esac
        done
    fi

    _deny "out-of-repo-write" "$_abs (resolved: $_canon)"
    ;;

esac

exit 0
