#!/bin/sh
# run-queue supervisor — autonomous overnight task queue executor.
#
# Reads <queue-dir>/queue.yaml + per-handoff frontmatter, runs each task in a
# fresh `claude -p` child on a dedicated local branch, writes queue-report.md.
#
# Slice A: linear task order (input order). DAG resolution arrives in Slice B.
# Slice A: single iteration per task. Intra-task loop arrives in Slice C.
#
# Usage:
#   SPINE_QUEUE=1 sh run.sh <queue-dir>
#
# Exit codes:
#   0 — all tasks reached status=complete
#   1 — one or more tasks ended non-complete, or lint failed
#   2 — configuration / invocation error
#   3 — trip-wire fired (WOKE-ME-UP.md written); human review required
#   130 — SIGINT
#   143 — SIGTERM

set -eu

# --- Utility ---

_err()    { printf '%s\n' "$*" >&2; }
_stamp()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
_short()  { printf '%s' "${1:-}" | cut -c1-8; }

_usage() {
    cat <<'EOF' >&2
Usage: SPINE_QUEUE=1 sh run.sh <queue-dir>

Autonomous overnight task queue executor. Reads queue.yaml, validates via
queue-lint.sh, runs each task in a fresh claude -p child on branch
queue/<run_id>/<task_id>, writes queue-report.md.

Before invocation: set SPINE_QUEUE=1 to arm the permission-profile hook.
Missing or mis-set SPINE_QUEUE renders the hook silent (fail-open), so the
supervisor refuses to start without it.
EOF
}

# --- Argument parsing ---

[ $# -eq 1 ] || { _usage; exit 2; }
_qdir=$1

case "$_qdir" in /*) : ;; *) _qdir="$PWD/$_qdir" ;; esac
[ -d "$_qdir" ] || { _err "queue directory does not exist: $_qdir"; exit 2; }

# --- Recursion + environment guards ---

if [ "${SPINE_QUEUE_ACTIVE:-}" = "1" ]; then
    _err "nested run-queue dispatch blocked — already inside supervisor context"
    exit 2
fi
export SPINE_QUEUE_ACTIVE=1

if [ "${SPINE_QUEUE:-}" != "1" ]; then
    _err "SPINE_QUEUE must be set to 1 before invoking this supervisor."
    _err "Without it the PreToolUse guard hook is inert — the trust boundary is absent."
    _err "Usage: SPINE_QUEUE=1 sh $(basename "$0") <queue-dir>"
    exit 2
fi

# --- Tool preflight ---

for _t in yq jq git tsort; do
    command -v "$_t" >/dev/null 2>&1 || { _err "missing required tool: $_t"; exit 2; }
done
command -v claude >/dev/null 2>&1 || { _err "missing claude CLI"; exit 2; }

_script_dir=$(cd "$(dirname "$0")" && pwd)

# --- Enqueue lint ---

sh "$_script_dir/queue-lint.sh" "$_qdir" || {
    _err "enqueue lint failed — refusing to spawn any child process"
    exit 1
}

# --- Git sanity ---

_repo_root=$(cd "$_qdir" && git rev-parse --show-toplevel 2>/dev/null) || {
    _err "queue directory is not inside a git repo: $_qdir"
    exit 2
}
cd "$_repo_root"

if ! git diff-index --quiet HEAD --; then
    _err "repo has uncommitted changes — refusing to start. Commit or stash first."
    exit 2
fi

# --- Parse queue.yaml ---

_qjson=$(yq -o=json eval '.' "$_qdir/queue.yaml")
_run_id=$(printf '%s' "$_qjson" | jq -r '.run_id')
_base_branch=$(printf '%s' "$_qjson" | jq -r '.base_branch // empty')
_profile_rel=$(printf '%s' "$_qjson" | jq -r '.profile')

case "$_profile_rel" in
    /*) _profile_abs=$_profile_rel ;;
     *) _profile_abs="$_qdir/$_profile_rel" ;;
esac
[ -f "$_profile_abs" ] || { _err "profile.json not found: $_profile_abs"; exit 2; }

# Resolve base_rev once at supervisor entry (per handoff OQ2 + OQ3).
if [ -n "$_base_branch" ]; then
    _base_rev=$(git rev-parse "$_base_branch" 2>/dev/null) || {
        _err "cannot resolve base_branch '$_base_branch'"; exit 2
    }
else
    _base_rev=$(git rev-parse HEAD)
fi

_base_branch_display=${_base_branch:-HEAD}

# --- Precheck: no branch name collisions ---

_task_ids=$(printf '%s' "$_qjson" | jq -r '.tasks[].id')
_prev_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "$_base_rev")

for _id in $_task_ids; do
    _b="queue/$_run_id/$_id"
    if git show-ref --quiet --verify "refs/heads/$_b"; then
        _err "branch already exists: $_b — choose a different run_id or delete stale branches"
        exit 2
    fi
done

# --- Session state setup ---

_queue_log="$_qdir/queue-log.md"
_state_file="$_qdir/queue-state.json"
_woke="$_qdir/WOKE-ME-UP.md"

# Fresh run: truncate state and log (leave WOKE-ME-UP.md intact if present — it indicates a prior trip-wire the user hasn't addressed)
if [ -f "$_woke" ]; then
    _err "WOKE-ME-UP.md from a prior run is present at $_woke."
    _err "Review and remove it before starting a new run."
    exit 2
fi

printf '# Queue log — %s\n\nStarted %s on branch %s (base_rev %s).\n\n' \
    "$_run_id" "$(_stamp)" "$_base_branch_display" "$(_short "$_base_rev")" > "$_queue_log"

_qlog() { printf '%s  %s\n' "$(_stamp)" "$*" >> "$_queue_log"; }

_atomic_write() {
    # _atomic_write <dest> writes stdin to dest atomically via .tmp + mv.
    _dest=$1
    _tmp="${_dest}.tmp.$$"
    cat > "$_tmp"
    mv "$_tmp" "$_dest"
}

_write_state() {
    # _write_state — dump current state map atomically.
    printf '%s\n' "$_state_json" | jq '.' | _atomic_write "$_state_file"
}

# Initial state
_state_json=$(printf '%s' "$_qjson" | jq --arg rev "$_base_rev" --arg started "$(_stamp)" '{
    run_id: .run_id,
    started_utc: $started,
    base_rev: $rev,
    tasks: [.tasks[] | {id: .id, status: "pending", branch: null, head_rev: null, exit_reason: null, started_utc: null, ended_utc: null}]
}')
_write_state

# --- Cleanup trap (forward SIGINT/SIGTERM to child) ---

_child_pid=""
_cleanup_on_signal() {
    _sig=$1
    _qlog "supervisor received SIG${_sig}; forwarding to child pid=$_child_pid"
    if [ -n "$_child_pid" ]; then
        kill -TERM "$_child_pid" 2>/dev/null || true
        _deadline=$(( $(date +%s) + 30 ))
        while kill -0 "$_child_pid" 2>/dev/null && [ "$(date +%s)" -lt "$_deadline" ]; do
            sleep 1
        done
        kill -KILL "$_child_pid" 2>/dev/null || true
    fi
    _qlog "supervisor exiting due to SIG${_sig}"
    case "$_sig" in
        INT)  exit 130 ;;
        TERM) exit 143 ;;
    esac
}
trap '_cleanup_on_signal INT'  INT
trap '_cleanup_on_signal TERM' TERM

# --- Per-task execution ---

_update_task_state() {
    # _update_task_state <id> <key> <value-json>
    _state_json=$(printf '%s' "$_state_json" | jq --arg id "$1" --arg k "$2" --argjson v "$3" '
        .tasks = (.tasks | map(if .id == $id then .[$k] = $v else . end))
    ')
    _write_state
}

_run_one_task() {
    _id=$1
    _task_json=$(printf '%s' "$_qjson" | jq -c --arg id "$_id" '.tasks[] | select(.id == $id)')
    _handoff_rel=$(printf '%s' "$_task_json" | jq -r --arg id "$_id" '.handoff // ("handoff-" + $id + ".md")')
    _handoff_abs="$_qdir/$_handoff_rel"

    # Frontmatter
    _fm=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==2) exit; next} n==1{print}' "$_handoff_abs")
    _fm_json=$(printf '%s' "$_fm" | yq -o=json eval '.' -)

    _entry_skill=$(printf '%s' "$_fm_json" | jq -r '.entry_skill')
    _max_budget=$(printf '%s' "$_fm_json" | jq -r '.max_budget_usd // empty')
    _terminal_artifact=$(printf '%s' "$_fm_json" | jq -r '.terminal_artifact // empty')
    _terminal_check=$(printf '%s' "$_fm_json" | jq -r '.terminal_check // empty')

    _branch="queue/$_run_id/$_id"
    _task_session="queue-$_run_id-$_id"
    _task_scratch=".scratch/$_task_session"
    _task_iter_dir="$_task_scratch/iterations"

    mkdir -p "$_task_iter_dir"

    _qlog "task=$_id begin; branch=$_branch session=$_task_session"
    _update_task_state "$_id" branch      "\"$_branch\""
    _update_task_state "$_id" status      '"in_progress"'
    _update_task_state "$_id" started_utc "\"$(_stamp)\""

    # Branch
    git checkout -q -b "$_branch" "$_base_rev"

    # Body = handoff minus frontmatter
    _body_tmp=$(mktemp -t run-queue-body.XXXXXX)
    awk 'BEGIN{n=0; body=0} /^---[[:space:]]*$/{n++; if(n==2){body=1; next} next} body==1' \
        "$_handoff_abs" > "$_body_tmp"

    # Prompt: entry skill invocation + handoff body.
    _prompt_tmp=$(mktemp -t run-queue-prompt.XXXXXX)
    {
        printf 'Your session id is: %s\n' "$_task_session"
        printf 'Your scratch directory is: %s\n' "$_task_scratch"
        printf 'Write the terminal build-status.json to: %s/build-status.json\n\n' "$_task_scratch"
        printf 'Invoke %s with the following handoff as input:\n\n' "$_entry_skill"
        cat "$_body_tmp"
    } > "$_prompt_tmp"

    # Streaming: JSONL per iteration (Slice A = always iteration 1)
    _iter_jsonl="$_task_iter_dir/1.jsonl"
    _iter_stderr="$_task_iter_dir/1.stderr"

    # Build command
    set -- claude -p \
        --settings "$_profile_abs" \
        --permission-mode dontAsk \
        --output-format stream-json \
        --include-partial-messages \
        --verbose \
        --no-session-persistence
    if [ -n "$_max_budget" ]; then
        set -- "$@" --max-budget-usd "$_max_budget"
    fi

    # Spawn via a helper script that applies the streaming stack.
    # Child stdout (stream-json) → grep live JSON lines → tee jsonl → discard stdout.
    # stdbuf -oL handles macOS 64 KB pipe buffer cap.
    (
        export SPINE_QUEUE=1
        export SPINE_SESSION_ID="$_task_session"
        export SPINE_QUEUE_DIR="$_qdir"
        export SPINE_QUEUE_RUN_ID="$_run_id"
        export SPINE_QUEUE_TASK_ID="$_id"
        # Unset CLAUDECODE so child knows it's a fresh invocation
        unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_EXECPATH
        "$@" "$(cat "$_prompt_tmp")" 2> "$_iter_stderr" \
            | stdbuf -oL grep --line-buffered '^{' \
            | stdbuf -oL tee "$_iter_jsonl" > /dev/null
    ) &
    _child_pid=$!

    wait "$_child_pid" || true
    _child_pid=""

    rm -f "$_body_tmp" "$_prompt_tmp"

    # Trip-wire check FIRST — halts everything.
    if [ -f "$_woke" ]; then
        _qlog "task=$_id trip-wire — WOKE-ME-UP.md present; halting queue"
        _update_task_state "$_id" status      '"blocked"'
        _update_task_state "$_id" exit_reason '"trip-wire"'
        _update_task_state "$_id" ended_utc   "\"$(_stamp)\""
        _update_task_state "$_id" head_rev    "\"$(git rev-parse HEAD)\""
        return 3
    fi

    # Terminal check
    _task_status="unknown"
    _task_exit_reason="no-terminal-signal"

    if [ -n "$_terminal_artifact" ]; then
        # Resolve ${SESSION} template and relative paths.
        _ta_path=$(printf '%s' "$_terminal_artifact" | sed "s|\${SESSION}|$_task_session|g")
        case "$_ta_path" in
            /*) : ;;
            build-status.json) _ta_path="$_task_scratch/build-status.json" ;;
             *) _ta_path="$_repo_root/$_ta_path" ;;
        esac

        if [ -f "$_ta_path" ] && _bstatus=$(jq -er '.status' "$_ta_path" 2>/dev/null); then
            _task_status=$_bstatus
            _task_exit_reason=$(jq -r '.exit_reason // empty' "$_ta_path" 2>/dev/null)
            [ -z "$_task_exit_reason" ] && _task_exit_reason="artifact-status-only"
        else
            _task_status="blocked"
            _task_exit_reason="missing-terminal-artifact"
        fi
    elif [ -n "$_terminal_check" ]; then
        if sh -c "$_terminal_check" >/dev/null 2>&1; then
            _task_status="complete"
            _task_exit_reason="terminal-check-pass"
        else
            _task_status="blocked"
            _task_exit_reason="terminal-check-fail"
        fi
    fi

    _head_after=$(git rev-parse HEAD)
    _update_task_state "$_id" status      "\"$_task_status\""
    _update_task_state "$_id" exit_reason "\"$_task_exit_reason\""
    _update_task_state "$_id" ended_utc   "\"$(_stamp)\""
    _update_task_state "$_id" head_rev    "\"$_head_after\""

    _qlog "task=$_id end status=$_task_status exit_reason=$_task_exit_reason head=$(_short "$_head_after")"

    # Return to base for the next independent task.
    git checkout -q "$_base_rev"
    return 0
}

# --- Main loop ---

_overall_rc=0
for _id in $_task_ids; do
    _run_one_task "$_id" || _rc=$?
    _rc=${_rc:-0}
    if [ "$_rc" -eq 3 ]; then
        # Trip-wire: stop all further tasks.
        _overall_rc=3
        break
    elif [ "$_rc" -ne 0 ]; then
        _err "task runner failed unexpectedly (rc=$_rc); preserving state"
        _overall_rc=$_rc
        break
    fi
    unset _rc
done

# --- Final report ---

_write_report() {
    _report="$_qdir/queue-report.md"
    {
        printf '# Queue report — %s\n\n' "$_run_id"
        printf '- Started: %s\n' "$(printf '%s' "$_state_json" | jq -r '.started_utc')"
        printf '- Ended: %s\n' "$(_stamp)"
        printf '- Base rev: `%s` (%s)\n' "$(_short "$_base_rev")" "$_base_branch_display"

        if [ -f "$_woke" ]; then
            printf '\n> **Trip-wire fired.** See `WOKE-ME-UP.md`.\n'
        fi

        printf '\n## Summary\n\n| Task | Status | Branch | Head | Exit reason |\n|------|--------|--------|------|-------------|\n'
        printf '%s' "$_state_json" | jq -r '.tasks[] | "| \(.id) | \(.status) | `\(.branch // "-")` | `\((.head_rev // "-")[0:8])` | \(.exit_reason // "-") |"'

        printf '\n## Per-task detail\n\n'
        printf '%s' "$_state_json" | jq -r '.tasks[] | @base64' | while IFS= read -r _b64; do
            _t=$(printf '%s' "$_b64" | base64 -d)
            _tid=$(printf '%s' "$_t" | jq -r '.id')
            printf '### %s\n\n' "$_tid"
            printf '- status: %s\n' "$(printf '%s' "$_t" | jq -r '.status')"
            printf '- exit_reason: %s\n' "$(printf '%s' "$_t" | jq -r '.exit_reason // "-"')"
            printf '- branch: `%s`\n' "$(printf '%s' "$_t" | jq -r '.branch // "-"')"
            printf '- head_rev: `%s`\n' "$(printf '%s' "$_t" | jq -r '.head_rev // "-"')"
            printf '- started: %s\n' "$(printf '%s' "$_t" | jq -r '.started_utc // "-"')"
            printf '- ended: %s\n' "$(printf '%s' "$_t" | jq -r '.ended_utc // "-"')"
            _iters=".scratch/queue-$_run_id-$_tid/iterations"
            if [ -d "$_iters" ]; then
                printf '- iterations:\n'
                for _j in "$_iters"/*.jsonl; do
                    [ -f "$_j" ] || continue
                    printf '  - `%s`\n' "$_j"
                done
            fi
            printf '\n'
        done
    } > "$_report"
    _qlog "wrote $(basename "$_report")"
}

_write_report

if [ "$_overall_rc" -eq 3 ]; then
    _err "queue halted by trip-wire — see $_woke and $_qdir/queue-report.md"
fi

# Restore caller's branch if we know it.
case "$_prev_branch" in
    "$_base_rev"|"") : ;;
    *) git checkout -q "$_prev_branch" 2>/dev/null || true ;;
esac

exit "$_overall_rc"
