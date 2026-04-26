#!/bin/sh
# run-queue supervisor — autonomous overnight task queue executor.
#
# Reads <queue-dir>/queue.yaml + per-handoff frontmatter, runs each task in a
# fresh `claude -p` child on a dedicated local branch, writes queue-report.md.
#
# Slice B: DAG-ordered execution via tsort; per-task on_failure policy
#          (stop/skip/retry_once); merge-based branch derivation for dependents.
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
[ -d "$_qdir" ] || { _err "supervisor: queue directory does not exist: $_qdir"; exit 2; }

# --- Recursion + environment guards ---

if [ "${SPINE_QUEUE_ACTIVE:-}" = "1" ]; then
    _err "supervisor: nested run-queue dispatch blocked — already inside supervisor context"
    exit 2
fi
export SPINE_QUEUE_ACTIVE=1

if [ "${SPINE_QUEUE:-}" != "1" ]; then
    _err "supervisor: SPINE_QUEUE must be set to 1 before invoking this supervisor."
    _err "supervisor: Without it the PreToolUse guard hook is inert — the trust boundary is absent."
    _err "supervisor: Usage: SPINE_QUEUE=1 sh $(basename "$0") <queue-dir>"
    exit 2
fi

# --- Tool preflight ---

for _t in yq jq git tsort; do
    command -v "$_t" >/dev/null 2>&1 || { _err "supervisor: missing required tool: $_t"; exit 2; }
done
command -v claude >/dev/null 2>&1 || { _err "supervisor: missing claude CLI"; exit 2; }

# GNU coreutils binary selection for pipeline line-buffering.
# On macOS (Homebrew), gstdbuf is Homebrew-native; on Linux, stdbuf is coreutils default.
if command -v gstdbuf >/dev/null 2>&1; then
    _stdbuf=gstdbuf
elif command -v stdbuf >/dev/null 2>&1 && stdbuf --version 2>&1 | grep -q GNU; then
    _stdbuf=stdbuf
else
    _err "supervisor: missing required tool: stdbuf (install via: brew install coreutils)"
    exit 2
fi

_script_dir=$(cd "$(dirname "$0")" && pwd)

# shellcheck source=../../use-envoy/scripts/_rate_limit.sh
. "$_script_dir/../../use-envoy/scripts/_rate_limit.sh" 2>/dev/null || {
    _err "supervisor: missing shared helper _rate_limit.sh (expected at skills/use-envoy/scripts/_rate_limit.sh)"
    exit 2
}

# --- Enqueue lint ---

sh "$_script_dir/queue-lint.sh" "$_qdir" || {
    _err "supervisor: enqueue lint failed — refusing to spawn any child process"
    exit 1
}

# --- Git sanity ---

_repo_root=$(cd "$_qdir" && git rev-parse --show-toplevel 2>/dev/null) || {
    _err "supervisor: queue directory is not inside a git repo: $_qdir"
    exit 2
}
cd "$_repo_root"

if ! git diff-index --quiet HEAD --; then
    _err "supervisor: repo has uncommitted changes — refusing to start. Commit or stash first."
    exit 2
fi

# --- Parse queue.yaml ---

_qjson=$(yq -o=json eval '.' "$_qdir/queue.yaml")
_run_id=$(printf '%s' "$_qjson" | jq -r '.run_id')
_base_branch=$(printf '%s' "$_qjson" | jq -r '.base_branch // empty')
_profile_rel=$(printf '%s' "$_qjson" | jq -r '.profile // empty')

# profile.json is optional — hook falls back to built-in defaults when absent.
_profile_abs=""
if [ -n "$_profile_rel" ]; then
    case "$_profile_rel" in
        /*) _profile_abs=$_profile_rel ;;
         *) _profile_abs="$_qdir/$_profile_rel" ;;
    esac
    [ -f "$_profile_abs" ] || { _err "supervisor: profile.json referenced but not found: $_profile_abs"; exit 2; }
    jq -e . "$_profile_abs" >/dev/null 2>&1 || { _err "supervisor: profile.json not valid JSON: $_profile_abs"; exit 2; }
fi

# backoff_cap_ms — intra-task rate-limit backoff ceiling. Default 7200000 ms (2 h).
_backoff_cap_ms=$(printf '%s' "$_qjson" | jq -r '.backoff_cap_ms // 7200000')
case "$_backoff_cap_ms" in
    ''|*[!0-9]*) _err "supervisor: backoff_cap_ms must be a positive integer (got '$_backoff_cap_ms')"; exit 2 ;;
esac
if [ "$_backoff_cap_ms" -lt 1000 ]; then
    _err "supervisor: backoff_cap_ms must be >= 1000 (got '$_backoff_cap_ms'); use the default 7200000 or a larger value"
    exit 2
fi
_backoff_cap_sec=$(( _backoff_cap_ms / 1000 ))

# Skill-bundled assets: hook script + settings overlay template.
# The skill is self-contained — no dependency on project-level hooks.json
# or opencode registration.
_skill_root=$(cd "$_script_dir/.." && pwd)
_queue_hook="$_script_dir/guard-queue-shell.sh"
_overlay_tmpl="$_skill_root/settings-overlay.tmpl.json"

for _f in "$_queue_hook" "$_overlay_tmpl"; do
    [ -e "$_f" ] || { _err "supervisor: missing run-queue asset: $_f"; exit 2; }
done
[ -x "$_queue_hook" ] || { _err "supervisor: run-queue hook not executable: $_queue_hook"; exit 2; }

# Resolve base_rev once at supervisor entry (per handoff OQ2 + OQ3).
if [ -n "$_base_branch" ]; then
    _base_rev=$(git rev-parse "$_base_branch" 2>/dev/null) || {
        _err "supervisor: cannot resolve base_branch '$_base_branch'"; exit 2
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
        _err "supervisor: branch already exists: $_b — choose a different run_id or delete stale branches"
        exit 2
    fi
done

# --- Session state setup ---

_queue_log="$_qdir/queue-log.md"
_state_file="$_qdir/queue-state.json"
_woke="$_qdir/WOKE-ME-UP.md"

# Fresh run: truncate state and log (leave WOKE-ME-UP.md intact if present — it indicates a prior trip-wire the user hasn't addressed)
if [ -f "$_woke" ]; then
    _err "supervisor: WOKE-ME-UP.md from a prior run is present at $_woke."
    _err "supervisor: Review and remove it before starting a new run."
    exit 2
fi

# Render the settings overlay with the absolute path to the guard hook.
# Written into the queue-dir so multiple concurrent queue runs against
# different directories do not collide.
_overlay_rendered="$_qdir/.run-queue-settings.json"
sed "s|@@GUARD_PATH@@|$_queue_hook|g" "$_overlay_tmpl" > "$_overlay_rendered"
jq -e . "$_overlay_rendered" >/dev/null 2>&1 || {
    _err "supervisor: failed to render settings overlay (bad template or jq)"
    exit 2
}

printf '# Queue log — %s\n\nStarted %s on branch %s (base_rev %s).\n\n' \
    "$_run_id" "$(_stamp)" "$_base_branch_display" "$(_short "$_base_rev")" > "$_queue_log"

_qlog() { printf '%s  %s\n' "$(_stamp)" "$*" >> "$_queue_log"; }

_atomic_write() {
    # _atomic_write <dest> writes stdin to dest atomically via .tmp + mv.
    _dest=$1
    _tmp="${_dest}.tmp.$$"
    if ! cat > "$_tmp"; then
        rm -f "$_tmp"
        _err "supervisor: atomic_write: failed to write tmp file for $_dest"
        return 1
    fi
    if ! mv "$_tmp" "$_dest"; then
        rm -f "$_tmp"
        _err "supervisor: atomic_write: failed to promote $_tmp → $_dest"
        return 1
    fi
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
    tasks: [.tasks[] | {id: .id, status: "pending", branch: null, head_rev: null, exit_reason: null, started_utc: null, ended_utc: null, attempts: 0}]
}')
_write_state

# --- Report writer (defined early so the signal trap can call it) ---

_write_report() {
    _report="$_qdir/queue-report.md"
    {
        printf '# Queue report — %s\n\n' "$_run_id"
        printf -- '- Started: %s\n' "$(printf '%s' "$_state_json" | jq -r '.started_utc')"
        printf -- '- Ended: %s\n' "$(_stamp)"
        printf -- '- Base rev: `%s` (%s)\n' "$(_short "$_base_rev")" "$_base_branch_display"

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
            printf -- '- status: %s\n' "$(printf '%s' "$_t" | jq -r '.status')"
            printf -- '- exit_reason: %s\n' "$(printf '%s' "$_t" | jq -r '.exit_reason // "-"')"
            printf -- '- branch: `%s`\n' "$(printf '%s' "$_t" | jq -r '.branch // "-"')"
            printf -- '- head_rev: `%s`\n' "$(printf '%s' "$_t" | jq -r '.head_rev // "-"')"
            printf -- '- started: %s\n' "$(printf '%s' "$_t" | jq -r '.started_utc // "-"')"
            printf -- '- ended: %s\n' "$(printf '%s' "$_t" | jq -r '.ended_utc // "-"')"
            _iters=".scratch/queue-$_run_id-$_tid/iterations"
            if [ -d "$_iters" ]; then
                printf -- '- iterations:\n'
                for _j in "$_iters"/*.jsonl; do
                    [ -f "$_j" ] || continue
                    printf -- '  - `%s`\n' "$_j"
                done
            fi
            printf '\n'
        done
    } | _atomic_write "$_report"
    _qlog "wrote $(basename "$_report")"
}

# --- Cleanup trap (forward SIGINT/SIGTERM to child) ---

_child_pid=""
_current_task_id=""

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
    # State updates and report are best-effort — do not let a disk
    # failure during shutdown swallow the exit 130/143 that follows.
    set +e
    if [ -n "$_current_task_id" ]; then
        _update_task_state "$_current_task_id" status      '"blocked"'
        _update_task_state "$_current_task_id" exit_reason "\"signal-$_sig\""
        _update_task_state "$_current_task_id" ended_utc   "\"$(_stamp)\""
        _update_task_state "$_current_task_id" head_rev    "\"$(git rev-parse HEAD 2>/dev/null || echo -)\""
    fi
    _finalize_stale_pending_retries 2>/dev/null || true
    _write_report 2>/dev/null || true
    case "$_prev_branch" in
        "$_base_rev"|"") : ;;
        *) git checkout -q "$_prev_branch" 2>/dev/null || true ;;
    esac
    set -e
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

_spawn_child() {
    # _spawn_child <prompt_path> <iter_jsonl> <iter_stderr> <task_timeout> [claude-cmd-args...]
    # Runs the child in a subshell with full env isolation, waits for it, and
    # sets _child_rc. Sets _child_pid before wait so the signal trap can forward.
    _sc_prompt=$1; _sc_jsonl=$2; _sc_stderr=$3; _sc_timeout=$4
    shift 4

    # Streaming stack: child stdout (stream-json) → live jq → tee per-iteration jsonl.
    # stdbuf -oL works around the macOS 64 KB pipe buffer cap.
    (
        export SPINE_QUEUE=1
        export SPINE_SESSION_ID="$_rot_task_session"
        export SPINE_QUEUE_DIR="$_qdir"
        export SPINE_QUEUE_RUN_ID="$_run_id"
        export SPINE_QUEUE_TASK_ID="$_rot_id"
        export SPINE_QUEUE_REPO_ROOT="$_repo_root"

        # Push-disabled belt: even if a pattern-matching hook is bypassed,
        # git itself refuses to push because pushInsteadOf rewrites the
        # protocol to a URL that git cannot resolve. Env-scoped to this
        # subshell — no repo config mutation, no cleanup required on exit.
        # Covers both HTTPS (origin pushurls like https://github.com/...)
        # and SSH (git@github.com:...) by matching both scheme prefixes.
        export GIT_CONFIG_COUNT=2
        export GIT_CONFIG_KEY_0="url.disabled:///.pushInsteadOf"
        export GIT_CONFIG_VALUE_0="https://"
        export GIT_CONFIG_KEY_1="url.disabled:///.pushInsteadOf"
        export GIT_CONFIG_VALUE_1="git@"

        # Credentials must not prompt — child has no stdin for the prompt.
        export GIT_TERMINAL_PROMPT=0
        export GIT_ASKPASS=/bin/false

        # Env hygiene: shed the outer claude-code identity so the child is a
        # fresh session, not a re-entry.
        unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_EXECPATH \
              CURSOR_AGENT CODEX_SANDBOX OPENCODE

        # shellcheck disable=SC2086  # timeout wraps "$@"; quoting preserved via set --
        timeout --kill-after=10 "$_sc_timeout" "$@" \
            < "$_sc_prompt" \
            2> "$_sc_stderr" \
          | "$_stdbuf" -oL grep --line-buffered '^{' \
          | "$_stdbuf" -oL tee "$_sc_jsonl" > /dev/null
    ) &
    _child_pid=$!

    _child_rc=0
    wait "$_child_pid" || _child_rc=$?
    _child_pid=""
}

_classify_terminal_status() {
    # _classify_terminal_status <terminal_artifact> <terminal_check> <task_session> <task_scratch> <repo_root>
    # Sets _task_status and _task_exit_reason in the caller's scope.
    _cts_artifact=$1; _cts_check=$2; _cts_session=$3; _cts_scratch=$4; _cts_root=$5

    _task_status="unknown"
    _task_exit_reason="no-terminal-signal"

    if [ -n "$_cts_artifact" ]; then
        # Resolve ${SESSION} template and relative paths.
        _ta_path=$(printf '%s' "$_cts_artifact" | sed "s|\${SESSION}|$_cts_session|g")
        case "$_ta_path" in
            /*) : ;;
            build-status.json) _ta_path="$_cts_scratch/build-status.json" ;;
             *) _ta_path="$_cts_root/$_ta_path" ;;
        esac

        if [ -f "$_ta_path" ] && _bstatus=$(jq -er '.status' "$_ta_path" 2>/dev/null); then
            case "$_bstatus" in
                complete|partial|blocked|in_progress)
                    _task_status=$_bstatus
                    _task_exit_reason=$(jq -r '.exit_reason // empty' "$_ta_path" 2>/dev/null)
                    [ -z "$_task_exit_reason" ] && _task_exit_reason="artifact-status-only"
                    ;;
                *)
                    _task_status="blocked"
                    _task_exit_reason="invalid-terminal-status"
                    ;;
            esac
        else
            _task_status="blocked"
            _task_exit_reason="missing-terminal-artifact"
        fi
    elif [ -n "$_cts_check" ]; then
        if sh -c "$_cts_check" >/dev/null 2>&1; then
            _task_status="complete"
            _task_exit_reason="terminal-check-pass"
        else
            _task_status="blocked"
            _task_exit_reason="terminal-check-fail"
        fi
    fi
}

_rot_compute_backoff() {
    # _rot_compute_backoff <streak> <base_sec> <cap_sec> — prints sleep seconds to stdout.
    # Uses iterative doubling (POSIX sh; no ** operator).
    # streak=1 → base; streak=2 → base*2; etc., capped at cap_sec.
    _rcb_n=$1
    _rcb_base=$2
    _rcb_cap=$3
    _rcb_sleep=$_rcb_base
    _rcb_i=1
    while [ "$_rcb_i" -lt "$_rcb_n" ] && [ "$_rcb_sleep" -lt "$_rcb_cap" ]; do
        _rcb_sleep=$((_rcb_sleep * 2))
        _rcb_i=$((_rcb_i + 1))
    done
    [ "$_rcb_sleep" -gt "$_rcb_cap" ] && _rcb_sleep=$_rcb_cap
    printf '%s\n' "$_rcb_sleep"
}

_rot_build_prompt() {
    # _rot_build_prompt <iter> <body_path> — writes a prompt to a tmp file and prints its path.
    # Reads _rot_* vars from caller scope (_rot_task_session, _rot_task_scratch,
    # _rot_entry_skill, _rot_id, _rot_max_iter, _rot_attempts, _rot_task_iter_dir,
    # _rot_branch, _rot_prev_status, _rot_prev_reason, _rot_prev_stamp).
    _rbp_iter=$1
    _rbp_body=$2
    _rbp_tmp=$(mktemp -t run-queue-prompt.XXXXXX)

    if [ "$_rbp_iter" -ge 2 ]; then
        _rbp_prior_jsonl="$_rot_task_iter_dir/${_rot_attempts}-$((_rbp_iter - 1)).jsonl"
        _rbp_sha=$(git rev-parse --short HEAD 2>/dev/null || echo -)
        {
            printf '## Continuing task %s (iteration %s of %s)\n' \
                "$_rot_id" "$_rbp_iter" "$_rot_max_iter"
            printf 'Prior iteration ended at %s with status=%s, exit_reason=%s.\n' \
                "$_rot_prev_stamp" "$_rot_prev_status" "$_rot_prev_reason"
            printf 'Session-log (if exists): %s/session-log.md\n' "$_rot_task_scratch"
            printf 'Prior iteration transcript: %s\n' "$_rbp_prior_jsonl"
            printf 'Branch: %s (current HEAD: %s)\n' "$_rot_branch" "$_rbp_sha"
            printf '\nContinue per the original handoff body below. Pick up where the prior iteration stopped — do not restart from scratch.\n\n'
            printf -- '---\n\n'
            printf 'Your session id is: %s\n' "$_rot_task_session"
            printf 'Your scratch directory is: %s\n' "$_rot_task_scratch"
            printf 'Write the terminal build-status.json to: %s/build-status.json\n\n' "$_rot_task_scratch"
            printf 'Invoke %s with the following handoff as input:\n\n' "$_rot_entry_skill"
            cat "$_rbp_body"
        } > "$_rbp_tmp"
    else
        {
            printf 'Your session id is: %s\n' "$_rot_task_session"
            printf 'Your scratch directory is: %s\n' "$_rot_task_scratch"
            printf 'Write the terminal build-status.json to: %s/build-status.json\n\n' "$_rot_task_scratch"
            printf 'Invoke %s with the following handoff as input:\n\n' "$_rot_entry_skill"
            cat "$_rbp_body"
        } > "$_rbp_tmp"
    fi

    printf '%s\n' "$_rbp_tmp"
}

_rot_halt_trip_wire() {
    # _rot_halt_trip_wire <log_msg> — writes trip-wire state and returns 3.
    # Reads caller scope: _rot_id, _rot_iter, _rot_prompt_tmp (optional).
    # Writes caller scope via _update_task_state: status, exit_reason, ended_utc, head_rev.
    # Writes _current_task_id="" (clear).
    rm -f "${_rot_prompt_tmp:-}"
    _qlog "task=$_rot_id iter=$_rot_iter $1"
    _update_task_state "$_rot_id" status      '"blocked"'
    _update_task_state "$_rot_id" exit_reason '"trip-wire"'
    _update_task_state "$_rot_id" ended_utc   "\"$(_stamp)\""
    _update_task_state "$_rot_id" head_rev    "\"$(git rev-parse HEAD 2>/dev/null || echo -)\""
    _current_task_id=""
    return 3
}

_rot_rate_limit_retry() {
    # _rot_rate_limit_retry "$@" — inner rate-limit retry loop for one iteration.
    # Reads caller scope: _rot_id, _rot_iter, _rot_attempts, _rot_prompt_tmp,
    #   _rot_iter_jsonl, _rot_iter_stderr, _rot_task_timeout, _rot_rl_count,
    #   _rot_rl_base_sec, _backoff_cap_sec, _woke.
    # Writes caller scope: _rot_rl_count (incremented per rate-limit; reset to 0 on success).
    # Returns: 0 = non-rate-limit spawn completed; 3 = trip-wire detected (caller propagates).
    while : ; do
        _qlog "task=$_rot_id iter=$_rot_iter attempt=$_rot_attempts spawn"
        _spawn_child "$_rot_prompt_tmp" "$_rot_iter_jsonl" "$_rot_iter_stderr" "$_rot_task_timeout" "$@"

        case "$_child_rc" in
            124|137) _qlog "task=$_rot_id iter=$_rot_iter child timed out after ${_rot_task_timeout}s" ;;
        esac

        # Trip-wire check FIRST — invariant #3, supersedes rate-limit sleep.
        if [ -f "$_woke" ]; then
            _rot_halt_trip_wire "trip-wire detected post-spawn; halting before rate-limit check"
            return 3
        fi

        if is_fast_failure "$_rot_iter_stderr"; then
            _rot_rl_count=$((_rot_rl_count + 1))
            _rot_rl_sleep=$(_rot_compute_backoff "$_rot_rl_count" "$_rot_rl_base_sec" "$_backoff_cap_sec")
            _qlog "task=$_rot_id iter=$_rot_iter rate-limit detected (streak=$_rot_rl_count); sleeping ${_rot_rl_sleep}s"
            sleep "$_rot_rl_sleep"
            # Check trip-wire after sleep — sleep could be hours.
            if [ -f "$_woke" ]; then
                _rot_halt_trip_wire "trip-wire detected after rate-limit sleep; halting"
                return 3
            fi
            continue   # retry SAME iteration (no counter advance)
        fi
        _rot_rl_count=0   # reset on non-rate-limit completion
        break
    done
    return 0
}

_rot_iterate() {
    # _rot_iterate — intra-task loop: spawn child per iteration until terminal or exhausted.
    # Returns: 0 = ran (status written); 3 = trip-wire halt.
    #
    # Reads caller-scope vars:
    #   _rot_* (from _run_one_task): _rot_id, _rot_fm_json, _rot_attempts,
    #     _rot_task_session, _rot_task_scratch, _rot_task_iter_dir,
    #     _rot_task_timeout, _rot_terminal_artifact, _rot_terminal_check,
    #     _rot_body_tmp, _rot_branch, _rot_entry_skill.
    #   Non-prefixed globals: _woke, _child_rc, _backoff_cap_sec, _repo_root.
    #   Env: SPINE_QUEUE_RL_BASE_SEC (test-mode override; default 120).
    # Writes caller-scope vars (direct assignment or via _update_task_state):
    #   _task_status, _task_exit_reason, _rot_prev_status, _rot_prev_reason,
    #   _rot_prev_stamp, _rot_iter, _rot_rl_count, _rot_rl_base_sec,
    #   _rot_prompt_tmp.
    #   Trip-wire state (_current_task_id clear, status/exit_reason) delegated to
    #   _rot_halt_trip_wire; _rot_rl_count management delegated to _rot_rate_limit_retry.

    # max_iterations from frontmatter — default 10 per spec C6 + queue-schema.
    _rot_max_iter=$(printf '%s' "$_rot_fm_json" | jq -r '.max_iterations // 10')
    case "$_rot_max_iter" in
        ''|*[!0-9]*) _rot_max_iter=10 ;;   # defensive; lint should have caught
    esac

    _rot_iter=0
    _rot_rl_count=0
    _rot_prev_status="pending"
    _rot_prev_reason=""
    _rot_prev_stamp=""
    # Rate-limit base (env override for test-mode; production default 120 s).
    _rot_rl_base_sec=${SPINE_QUEUE_RL_BASE_SEC:-120}
    case "$_rot_rl_base_sec" in
        ''|*[!0-9]*|0)
            _err "supervisor: SPINE_QUEUE_RL_BASE_SEC must be a positive integer (got '$_rot_rl_base_sec')"
            exit 2
            ;;
    esac

    while [ "$_rot_iter" -lt "$_rot_max_iter" ]; do
        _rot_iter=$((_rot_iter + 1))
        _rot_iter_jsonl="$_rot_task_iter_dir/${_rot_attempts}-${_rot_iter}.jsonl"
        _rot_iter_stderr="$_rot_task_iter_dir/${_rot_attempts}-${_rot_iter}.stderr"

        # Build per-iteration prompt; iteration 1 = original; iterations >= 2 prepend resumption header.
        _rot_prompt_tmp=$(_rot_build_prompt "$_rot_iter" "$_rot_body_tmp")

        # Inner rate-limit retry loop — does NOT advance iteration counter.
        _rot_rate_limit_retry "$@" || return 3
        rm -f "$_rot_prompt_tmp"

        # Trip-wire check — supersedes on_failure.
        if [ -f "$_woke" ]; then
            _rot_halt_trip_wire "trip-wire — WOKE-ME-UP.md present; halting queue"
            return 3
        fi

        # Classify and decide loop action.
        _classify_terminal_status \
            "$_rot_terminal_artifact" "$_rot_terminal_check" \
            "$_rot_task_session" "$_rot_task_scratch" "$_repo_root"

        # Preserve status/reason/timestamp for next iteration's resumption header.
        _rot_prev_status="$_task_status"
        _rot_prev_reason="$_task_exit_reason"
        _rot_prev_stamp=$(_stamp)

        case "$_task_status" in
            complete|blocked) break ;;      # terminal — stop looping
            partial|in_progress|unknown) ;; # non-terminal — keep looping
            # "unknown" mid-loop means no terminal signal yet; keep iterating.
            # Only at loop-exhaustion does unknown become blocked/max-iterations-exceeded.
        esac
    done

    # If loop exhausted without terminal, mark blocked/max-iterations-exceeded.
    if [ "$_rot_iter" -ge "$_rot_max_iter" ] \
            && [ "$_task_status" != "complete" ] \
            && [ "$_task_status" != "blocked" ]; then
        _task_status="blocked"
        _task_exit_reason="max-iterations-exceeded"
    fi
}

_run_one_task() {
    # _run_one_task <id> [parent-branch ...]
    # Creates branch, optionally merges parent branches, runs intra-task loop, tears down.
    # Returns: 0 = ran (task may be blocked/complete), 3 = trip-wire halt.
    # Sets _task_status and _task_exit_reason in caller scope via _update_task_state.
    # Uses _rot_* prefix to avoid clobbering the outer main-loop iteration variable _id.
    _rot_id=$1
    shift
    # Remaining args are parent branches to merge (may be empty).
    _rot_parent_branches="$*"

    _current_task_id="$_rot_id"
    _rot_task_json=$(printf '%s' "$_qjson" | jq -c --arg id "$_rot_id" '.tasks[] | select(.id == $id)')
    _rot_handoff_rel=$(printf '%s' "$_rot_task_json" | jq -r --arg id "$_rot_id" '.handoff // ("handoff-" + $id + ".md")')
    _rot_handoff_abs="$_qdir/$_rot_handoff_rel"

    # Frontmatter
    _rot_fm=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==2) exit; next} n==1{print}' "$_rot_handoff_abs")
    _rot_fm_json=$(printf '%s' "$_rot_fm" | yq -o=json eval '.' -)

    _rot_entry_skill=$(printf '%s' "$_rot_fm_json" | jq -r '.entry_skill')
    _rot_terminal_artifact=$(printf '%s' "$_rot_fm_json" | jq -r '.terminal_artifact // empty')
    _rot_terminal_check=$(printf '%s' "$_rot_fm_json" | jq -r '.terminal_check // empty')

    _rot_branch="queue/$_run_id/$_rot_id"
    _rot_task_session="queue-$_run_id-$_rot_id"
    _rot_task_scratch=".scratch/$_rot_task_session"
    _rot_task_iter_dir="$_rot_task_scratch/iterations"

    mkdir -p "$_rot_task_iter_dir"

    # Increment attempt counter.
    _rot_attempts=$(printf '%s' "$_state_json" | jq -r --arg id "$_rot_id" '
        .tasks[] | select(.id == $id) | .attempts // 0
    ')
    _rot_attempts=$((_rot_attempts + 1))
    _update_task_state "$_rot_id" attempts    "$_rot_attempts"

    _qlog "task=$_rot_id begin attempt=$_rot_attempts; branch=$_rot_branch session=$_rot_task_session"
    _update_task_state "$_rot_id" branch      "\"$_rot_branch\""
    _update_task_state "$_rot_id" status      '"in_progress"'
    _update_task_state "$_rot_id" started_utc "\"$(_stamp)\""

    # Branch: always fork from base_rev, then merge parent branches if any.
    git checkout -q -b "$_rot_branch" "$_base_rev"

    if [ -n "$_rot_parent_branches" ]; then
        _rot_merge_msg="queue/$_run_id merge deps for $_rot_id"
        # shellcheck disable=SC2086  # _rot_parent_branches is space-separated; word-split intended
        if ! git merge --no-ff -m "$_rot_merge_msg" $_rot_parent_branches 2>/dev/null; then
            # Conflict — abort, mark blocked, restore base, signal caller.
            git merge --abort 2>/dev/null || true
            git checkout -q "$_base_rev"
            git branch -D "$_rot_branch" 2>/dev/null || true
            _update_task_state "$_rot_id" status      '"blocked"'
            _update_task_state "$_rot_id" exit_reason '"dep-merge-conflict"'
            _update_task_state "$_rot_id" ended_utc   "\"$(_stamp)\""
            _qlog "task=$_rot_id blocked due to dep-merge-conflict"
            _current_task_id=""
            return 0
        fi
        _qlog "task=$_rot_id merged parent branches: $_rot_parent_branches"
    fi

    # Body = handoff minus frontmatter (shared across all iterations via _rot_body_tmp).
    _rot_body_tmp=$(mktemp -t run-queue-body.XXXXXX)
    awk 'BEGIN{n=0; body=0} /^---[[:space:]]*$/{n++; if(n==2){body=1; next} next} body==1' \
        "$_rot_handoff_abs" > "$_rot_body_tmp"

    # Build command — layer the queue overlay via --settings (registers guard hook).
    # stdin prompt feed; env hygiene; timeout+kill-after bound runaway tasks.
    set -- claude --print \
        --settings "$_overlay_rendered" \
        --permission-mode dontAsk \
        --output-format stream-json \
        --include-partial-messages \
        --verbose \
        --no-session-persistence

    # Per-task liveness cap — overnight run should not hang on a stuck child.
    # Matches envoy's 1h default; queue tasks may run longer so we bump to 2h.
    _rot_task_timeout=${SPINE_QUEUE_TASK_TIMEOUT:-7200}

    # Run the intra-task loop (spawn + classify, up to max_iterations).
    _rot_iterate "$@" || {
        _rot_iterate_rc=$?
        rm -f "$_rot_body_tmp"
        return "$_rot_iterate_rc"
    }

    rm -f "$_rot_body_tmp"

    # Write final state after loop completes.
    _rot_head_after=$(git rev-parse HEAD)
    _update_task_state "$_rot_id" status      "\"$_task_status\""
    _update_task_state "$_rot_id" exit_reason "\"$_task_exit_reason\""
    _update_task_state "$_rot_id" ended_utc   "\"$(_stamp)\""
    _update_task_state "$_rot_id" head_rev    "\"$_rot_head_after\""

    _qlog "task=$_rot_id end status=$_task_status exit_reason=$_task_exit_reason head=$(_short "$_rot_head_after")"

    # Return to base for the next task.
    git checkout -q "$_base_rev"
    _current_task_id=""
    return 0
}

# --- DAG helpers ---

_resolve_topo_order() {
    # _resolve_topo_order — builds edge list from queue.yaml and runs tsort.
    # Emits topological order on stdout (roots first).
    # Self-edges ("id id") ensure roots appear in output even without any deps.
    # Exits 1 on cycle (lint should have caught it; this is defense-in-depth).
    # BSD tsort (macOS) exits 0 on cycles but prints "cycle" on stderr — mirror the
    # lint pattern from queue-lint.sh to catch this portably.
    _rto_edges=$(printf '%s' "$_qjson" | jq -r '
        .tasks[] as $t
        | if ($t.depends_on // []) == [] then
              "\($t.id) \($t.id)"
          else
              ($t.depends_on[]) + " " + $t.id
          end
    ')
    _rto_tsort_err=$(printf '%s\n' "$_rto_edges" | tsort 2>&1 >/dev/null || true)
    _rto_topo=$(printf '%s\n' "$_rto_edges" | tsort 2>/dev/null) || {
        _err "supervisor: tsort cycle detected at runtime — lint should have caught this"
        return 1
    }
    if printf '%s' "$_rto_tsort_err" | grep -q 'cycle'; then
        _err "supervisor: cycle detected in topology at runtime (lint should have caught this)"
        return 1
    fi
    printf '%s\n' "$_rto_topo"
}

_get_on_failure() {
    # _get_on_failure <id> — prints on_failure value for task (default: stop).
    _gof_id=$1
    _gof_hrel=$(printf '%s' "$_qjson" | jq -r --arg id "$_gof_id" '
        .tasks[] | select(.id == $id) | .handoff // ("handoff-" + $id + ".md")
    ')
    _gof_habs="$_qdir/$_gof_hrel"
    _gof_fm=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==2) exit; next} n==1{print}' "$_gof_habs")
    _gof_of=$(printf '%s' "$_gof_fm" | yq -o=json eval '.' - 2>/dev/null | jq -r '.on_failure // empty')
    printf '%s' "${_gof_of:-stop}"
}

_get_task_status() {
    # _get_task_status <id> — prints current status from state.
    printf '%s' "$_state_json" | jq -r --arg id "$1" '
        .tasks[] | select(.id == $id) | .status
    '
}

_get_task_branch() {
    # _get_task_branch <id> — prints branch name from state (empty if no branch).
    printf '%s' "$_state_json" | jq -r --arg id "$1" '
        .tasks[] | select(.id == $id) | .branch // empty
    '
}

_get_dep_ids() {
    # _get_dep_ids <id> — prints newline-separated depends_on ids.
    printf '%s' "$_qjson" | jq -r --arg id "$1" '
        .tasks[] | select(.id == $id) | (.depends_on // [])[]
    '
}

_resolve_blocked_parent_verdict() {
    # _resolve_blocked_parent_verdict <dep_status> <dep_on_failure> — classifies a
    # blocked parent's contribution to the dependent's verdict.
    # Sets _rbpv_verdict: "block" | "skip".
    # Called only when dep_status == "blocked"; on_failure drives the outcome.
    # retry_once+blocked means retry already exhausted → treat as stop (block).
    _rbpv_status=$1
    _rbpv_of=$2
    case "$_rbpv_of" in
        skip)
            # blocked+skip → dependent skips; lower precedence than block.
            _rbpv_verdict="skip"
            ;;
        *)
            # retry_once exhausted, stop (default), or unrecognised → hard block.
            _rbpv_verdict="block"
            ;;
    esac
}

_check_parent_states() {
    # _check_parent_states <id> — inspects all parent statuses in two passes; sets:
    #   _cps_verdict: "run" | "block" | "skip" | "pending_retry_wait"
    #   _cps_parent_branches: space-separated complete/partial parent branch names to merge
    # Returns 0 always (verdict is via globals).
    #
    # Precedence (highest to lowest): pending_retry_wait > block > skip > run.
    # _cps_parent_branches is always populated from complete/partial parents regardless
    # of verdict — a retry dependent may need it after the flush resolves.
    #
    # retry_once+blocked is treated as block (retry already exhausted its chance).
    _cps_id=$1
    _cps_deps=$(_get_dep_ids "$_cps_id")
    _cps_verdict="run"
    _cps_parent_branches=""
    _cps_has_pending_retry=0
    _cps_has_block=0
    _cps_has_skip=0

    if [ -z "$_cps_deps" ]; then
        return 0
    fi

    # Pass 1 — collect flags and complete parent branches.
    while IFS= read -r _cps_dep; do
        [ -z "$_cps_dep" ] && continue
        _cps_dep_status=$(_get_task_status "$_cps_dep")
        _cps_dep_of=$(_get_on_failure "$_cps_dep")

        case "$_cps_dep_status" in
            pending_retry)
                _cps_has_pending_retry=1
                ;;
            blocked)
                _resolve_blocked_parent_verdict "$_cps_dep_status" "$_cps_dep_of"
                case "$_rbpv_verdict" in
                    skip)  _cps_has_skip=1 ;;
                    block) _cps_has_block=1 ;;
                esac
                ;;
            skipped)
                _cps_has_skip=1
                ;;
            complete|partial)
                _cps_dep_branch=$(_get_task_branch "$_cps_dep")
                if [ -n "$_cps_dep_branch" ]; then
                    _cps_parent_branches="${_cps_parent_branches:+$_cps_parent_branches }$_cps_dep_branch"
                fi
                ;;
        esac
    done <<EOF
$_cps_deps
EOF

    # Pass 2 — explicit precedence: pending_retry_wait > block > skip > run.
    if [ "$_cps_has_pending_retry" -eq 1 ]; then
        _cps_verdict="pending_retry_wait"
    elif [ "$_cps_has_block" -eq 1 ]; then
        _cps_verdict="block"
    elif [ "$_cps_has_skip" -eq 1 ]; then
        _cps_verdict="skip"
    else
        _cps_verdict="run"
    fi
}

_mark_task_skipped() {
    # _mark_task_skipped <id> <exit_reason>
    _update_task_state "$1" status      '"skipped"'
    _update_task_state "$1" exit_reason "\"$2\""
    _update_task_state "$1" ended_utc   "\"$(_stamp)\""
    _qlog "task=$1 skipped exit_reason=$2"
}

_mark_task_blocked() {
    # _mark_task_blocked <id> <exit_reason>
    _update_task_state "$1" status      '"blocked"'
    _update_task_state "$1" exit_reason "\"$2\""
    _update_task_state "$1" ended_utc   "\"$(_stamp)\""
    _qlog "task=$1 blocked exit_reason=$2"
}

_do_retry() {
    # _do_retry <id> <tasks_since_fail> — flush a pending_retry task.
    # Returns: 0 = ran (final status in state), 3 = trip-wire.
    _dr_id=$1
    _dr_tasks_since=$2
    _dr_branch=$(_get_task_branch "$_dr_id")

    # Resolve parent branches for the retry (same parents as attempt 1 —
    # they haven't changed, but we re-derive to get their current branch names).
    _check_parent_states "$_dr_id"
    _dr_parent_branches="$_cps_parent_branches"

    # Clear the pending_retry branch so _run_one_task can re-create it.
    # The original branch from attempt 1 is deleted first.
    if [ -n "$_dr_branch" ] && git show-ref --quiet --verify "refs/heads/$_dr_branch"; then
        git branch -D "$_dr_branch" 2>/dev/null || true
    fi
    # Reset state so _run_one_task can write a new branch entry.
    _update_task_state "$_dr_id" branch  'null'
    _update_task_state "$_dr_id" status  '"pending"'

    # Lazy backoff: if no siblings ran between the first fail and this retry,
    # sleep 30s to avoid hammering the same resource immediately.
    if [ "$_dr_tasks_since" -eq 0 ]; then
        _qlog "task=$_dr_id retry backoff 30s (no siblings ran since first attempt)"
        sleep 30
    fi

    # shellcheck disable=SC2086  # _dr_parent_branches is space-separated; word-split intended
    _run_one_task "$_dr_id" $_dr_parent_branches || return $?
    _dr_final_status=$(_get_task_status "$_dr_id")

    if [ "$_dr_final_status" = "blocked" ]; then
        # Only rewrite exit_reason to retry-exhausted for runtime/terminal-check failures.
        # Preserve merge-conflict, signal, and trip-wire reasons — those are already definitive.
        _dr_cur_reason=$(printf '%s' "$_state_json" | jq -r --arg id "$_dr_id" '
            .tasks[] | select(.id == $id) | .exit_reason // empty
        ')
        case "$_dr_cur_reason" in
            terminal-check-fail|missing-terminal-artifact|artifact-status-only|no-terminal-signal)
                _mark_task_blocked "$_dr_id" "retry-exhausted"
                _qlog "task=$_dr_id retry-exhausted (both attempts blocked)"
                ;;
            *)
                # Preserve: dep-merge-conflict, trip-wire, signal-*, or any other definitive reason.
                _qlog "task=$_dr_id retry also blocked; preserving exit_reason=$_dr_cur_reason"
                ;;
        esac
    fi
    return 0
}

_flush_pending_retries() {
    # _flush_pending_retries — run any remaining pending_retry tasks at end of loop.
    # Returns 3 if trip-wire fires; propagates non-zero rc from _do_retry otherwise.
    _fpr_rc=0
    _fpr_ids=$(printf '%s' "$_state_json" | jq -r '
        .tasks[] | select(.status == "pending_retry") | .id
    ')
    [ -z "$_fpr_ids" ] && return 0

    while IFS= read -r _fpr_id; do
        [ -z "$_fpr_id" ] && continue
        _qlog "task=$_fpr_id flushing pending_retry (no dependents)"
        _do_retry "$_fpr_id" 0 || {
            _fpr_rc=$?
            [ "$_fpr_rc" -eq 3 ] && return 3
        }
    done <<EOF
$_fpr_ids
EOF
    return "$_fpr_rc"
}

_finalize_stale_pending_retries() {
    # _finalize_stale_pending_retries — safety sweep before report on abnormal exit.
    # Marks any remaining pending_retry tasks as blocked/retry-not-flushed.
    # Does NOT attempt to run retries — the queue is abandoning further work.
    _fspr_ids=$(printf '%s' "$_state_json" | jq -r '
        .tasks[] | select(.status == "pending_retry") | .id
    ')
    [ -z "$_fspr_ids" ] && return 0

    while IFS= read -r _fspr_id; do
        [ -z "$_fspr_id" ] && continue
        _update_task_state "$_fspr_id" status      '"blocked"'
        _update_task_state "$_fspr_id" exit_reason '"retry-not-flushed"'
        _update_task_state "$_fspr_id" ended_utc   "\"$(_stamp)\""
        _qlog "task=$_fspr_id finalized stale pending_retry as blocked/retry-not-flushed"
    done <<EOF
$_fspr_ids
EOF
}

# --- Main loop ---

_overall_rc=0

# Build topological order (exits 1 on cycle).
_topo_order=$(_resolve_topo_order) || { _overall_rc=1; }

if [ "$_overall_rc" -eq 0 ]; then
    # _tasks_completed_since tracks work done since the last pending_retry mark,
    # used to decide whether to apply the 30s backoff on retry.
    _tasks_completed_since=0

    for _id in $_topo_order; do
        _rot_rc=0   # reset per iteration to avoid latent rc leak from prior task
        # Check if this task is in the queue at all (tsort may echo root self-edges).
        _id_in_queue=$(printf '%s' "$_qjson" | jq -r --arg id "$_id" '
            .tasks[] | select(.id == $id) | .id
        ')
        [ -z "$_id_in_queue" ] && continue

        # Skip tasks already resolved (e.g. from a prior retry flush).
        _cur_status=$(_get_task_status "$_id")
        case "$_cur_status" in
            complete|partial|blocked|skipped) continue ;;
        esac

        # Inspect parent states.
        _check_parent_states "$_id"

        case "$_cps_verdict" in
            block)
                _mark_task_blocked "$_id" "transitive-block"
                # Synthetic cascade — no actual spawn; do NOT increment _tasks_completed_since.
                # The 30s backoff for retry_once depends on real spawns only.
                continue
                ;;
            skip)
                _mark_task_skipped "$_id" "dependency-failed-skip"
                # Synthetic cascade — no actual spawn; do NOT increment _tasks_completed_since.
                continue
                ;;
            pending_retry_wait)
                # Find which parent is pending_retry and flush it first.
                _dep_ids=$(_get_dep_ids "$_id")
                while IFS= read -r _dep; do
                    [ -z "$_dep" ] && continue
                    _dep_status=$(_get_task_status "$_dep")
                    if [ "$_dep_status" = "pending_retry" ]; then
                        _do_retry "$_dep" "$_tasks_completed_since" || {
                            _rc_retry=$?
                            if [ "$_rc_retry" -eq 3 ]; then
                                _overall_rc=3
                                break 2
                            fi
                            if [ "$_rc_retry" -ne 0 ]; then
                                _err "supervisor: _do_retry failed unexpectedly (rc=$_rc_retry); preserving state"
                                _overall_rc=$_rc_retry
                                break 2
                            fi
                        }
                        _tasks_completed_since=0
                        # Check trip-wire after retry.
                        [ -f "$_woke" ] && { _overall_rc=3; break 2; }
                    fi
                done <<EOF
$_dep_ids
EOF
                # Re-evaluate parent states after retry.
                _check_parent_states "$_id"
                case "$_cps_verdict" in
                    block) _mark_task_blocked "$_id" "transitive-block"; continue ;;
                    skip)  _mark_task_skipped "$_id" "dependency-failed-skip"; continue ;;
                esac
                ;;
        esac

        # Run the task.
        # shellcheck disable=SC2086  # _cps_parent_branches is space-separated; word-split is intentional
        _run_one_task "$_id" $_cps_parent_branches || _rot_rc=$?
        _rot_rc=${_rot_rc:-0}

        if [ "$_rot_rc" -eq 3 ] || [ -f "$_woke" ]; then
            _overall_rc=3
            break
        fi

        if [ "$_rot_rc" -ne 0 ]; then
            _err "supervisor: task runner failed unexpectedly (rc=$_rot_rc); preserving state"
            _overall_rc=$_rot_rc
            break
        fi

        # Check on_failure for retry_once.
        _ran_status=$(_get_task_status "$_id")
        _ran_of=$(_get_on_failure "$_id")
        _ran_reason=$(printf '%s' "$_state_json" | jq -r --arg id "$_id" '
            .tasks[] | select(.id == $id) | .exit_reason // empty
        ')
        _ran_attempts=$(printf '%s' "$_state_json" | jq -r --arg id "$_id" '
            .tasks[] | select(.id == $id) | .attempts // 0
        ')
        # Guard: retry_once only applies when blocked on first attempt AND the failure
        # is not a deterministic dep-merge-conflict (retrying a conflict is wasteful).
        if [ "$_ran_status" = "blocked" ] && [ "$_ran_of" = "retry_once" ] \
                && [ "$_ran_attempts" -lt 2 ] && [ "$_ran_reason" != "dep-merge-conflict" ]; then
            _update_task_state "$_id" status '"pending_retry"'
            _qlog "task=$_id blocked on attempt 1; marked pending_retry (lazy retry before first dependent)"
            _tasks_completed_since=0
        else
            _tasks_completed_since=$((_tasks_completed_since + 1))
        fi
    done
fi

# Flush any pending_retry tasks with no dependents (happy path only — runs retries).
if [ "$_overall_rc" -eq 0 ]; then
    _flush_pending_retries || _overall_rc=$?
fi

# Unconditional sweep: finalize any pending_retry tasks that were not flushed
# (abnormal termination — trip-wire or unexpected rc). Marks them blocked/retry-not-flushed
# so the final report never shows transient pending_retry status.
_finalize_stale_pending_retries

# --- Final report ---

_write_report

if [ "$_overall_rc" -eq 3 ]; then
    _err "supervisor: queue halted by trip-wire — see $_woke and $_qdir/queue-report.md"
fi

# Restore caller's branch if we know it.
case "$_prev_branch" in
    "$_base_rev"|"") : ;;
    *) git checkout -q "$_prev_branch" 2>/dev/null || true ;;
esac

exit "$_overall_rc"
