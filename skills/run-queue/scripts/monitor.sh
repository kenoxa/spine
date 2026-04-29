#!/bin/sh
# monitor.sh — delta-aware queue-state monitor for run-queue.
#
# Usage:
#   sh monitor.sh <queue-dir> [--watch] [--interval N]
#
# Exit codes:
#   0 — normal execution (first-run or delta printed; watch-mode loop completed)
#   1 — queue-state.json missing, invalid JSON, or missing run_id
#   2 — trip-wire fired (WOKE-ME-UP.md present) or --watch loop broken

set -eu

# --- Helpers ---

_err()   { printf '%s\n' "$*" >&2; }
_stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_hms()   { date -u +%H:%M:%S; }

# TTY-aware ANSI sequences (only when stdout is a real TTY and color is allowed).
_ansi() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ]; then
        printf '%s' "$1"
    fi
}

_clear()   { _ansi '\033[2J'; _ansi '\033[H'; }
_reset()   { _ansi '\033[0m'; }
_bold()    { _ansi '\033[1m'; }
_dim()     { _ansi '\033[2m'; }
_red()     { _ansi '\033[31m'; }
_green()   { _ansi '\033[32m'; }
_yellow()  { _ansi '\033[33m'; }
_blue()    { _ansi '\033[34m'; }
_cyan()    { _ansi '\033[36m'; }

# --- Argument parsing ---

_qdir=""
_watch=0
_interval=30

while [ $# -gt 0 ]; do
    case "$1" in
        --watch)  _watch=1 ;;
        --interval)
            shift
            [ $# -eq 0 ] && { _err "monitor: --interval requires a number"; exit 2; }
            _interval=$1
            ;;
        --interval[0-9]*)
            # Handle --interval30 (no space).
            _interval=$(printf '%s' "$1" | sed 's/--interval//')
            ;;
        -*)
            _err "monitor: unknown option: $1"; exit 2 ;;
        *)
            [ -n "$_qdir" ] && { _err "monitor: unexpected argument: $1"; exit 2; }
            _qdir=$1
            ;;
    esac
    shift
done

[ -z "$_qdir" ] && { _err "Usage: sh monitor.sh <queue-dir> [--watch] [--interval N]"; exit 2; }

case "$_qdir" in /*) : ;; *) _qdir="$PWD/$_qdir" ;; esac
[ -d "$_qdir" ] || { _err "monitor: queue directory does not exist: $_qdir"; exit 1; }

_state_file="$_qdir/queue-state.json"
_woke_file="$_qdir/WOKE-ME-UP.md"
_snap_dir="/tmp"

# Minimum interval guard.
case "$_interval" in
    ''|*[!0-9]*|0) _interval=30 ;;
    *) [ "$_interval" -lt 1 ] && _interval=1 ;;
esac

# --- Tool check ---

command -v jq >/dev/null 2>&1 || { _err "monitor: missing required tool: jq"; exit 1; }

# --- Snapshot helpers ---

_atomic_write() {
    # _atomic_write <dest> writes stdin to dest atomically via .tmp + mv.
    _dest=$1
    _tmp="${_dest}.tmp.$$"
    if ! cat > "$_tmp"; then
        rm -f "$_tmp"
        return 1
    fi
    if ! mv "$_tmp" "$_dest"; then
        rm -f "$_tmp"
        return 1
    fi
}

_snapshot_path() {
    # Prints snapshot path for given run_id.
    # Use $PPID (parent shell) so repeated invocations from the same
    # terminal share a snapshot. Falls back to $$ if $PPID is unavailable.
    _ppid=${PPID:-$$}
    printf '%s/spine-monitor-%s-%s.json' "$_snap_dir" "$1" "$_ppid"
}

_write_snapshot() {
    # _write_snapshot <snap_path> <state_json>
    _sp=$1
    _sj=$2
    # Build task dict: map id→{status,outcome,exit_reason}; preserve nulls.
    _tasks=$(printf '%s' "$_sj" | jq -c '
        .tasks[] | {
            key: .id,
            value: {
                status,
                outcome,
                exit_reason
            }
        }
    ' | jq -s 'from_entries')
    printf '%s\n' "$_sj" | jq --argjson tasks "$_tasks" --arg last "$(_stamp)" '{
        schema: 1,
        last_seen: $last,
        tasks: $tasks
    }' | _atomic_write "$_sp"
}

# --- Read state ---

_read_state() {
    [ -f "$_state_file" ] || { _err "monitor: queue-state.json not found in $_qdir"; return 1; }
    _state_json=$(jq '.' "$_state_file" 2>/dev/null) || { _err "monitor: queue-state.json is not valid JSON"; return 1; }
    _run_id=$(printf '%s' "$_state_json" | jq -r '.run_id // empty')
    [ -z "$_run_id" ] && { _err "monitor: queue-state.json missing run_id"; return 1; }
    return 0
}

# --- Trip-wire check ---
# Returns 0 if clear, 1 if trip-wire fired (prints content and exits 2).

check_tripwire() {
    if [ -f "$_woke_file" ]; then
        _bold; _red
        printf '\n===== TRIP-WIRE FIRED =====\n'
        _reset
        cat "$_woke_file"
        _bold; _red
        printf '===========================\n\n'
        _reset
        return 1
    fi
    return 0
}

# --- Render full table (first run, no snapshot) ---

render_full() {
    _bold; _blue
    printf 'Queue %s — full state\n' "$_run_id"
    _reset
    printf '%-12s %-14s %-10s %-10s %s\n' 'TASK' 'STATUS' 'OUTCOME' 'EXIT REASON' 'BRANCH'
    printf '%.0s-' '' 12; printf ' '; printf '%.0s-' '' 14; printf ' '; printf '%.0s-' '' 10; printf ' '; printf '%.0s-' '' 10; printf ' %s\n' 'BRANCH'
    printf '%s' "$_state_json" | jq -r '.tasks[] |
        "\(.id)|\(.status)|\(.outcome // "-")|\(.exit_reason // "-")|\(.branch // "-")"
    ' | while IFS='|' read -r _id _status _outcome _exit_reason _branch; do
        printf '%-12s %-14s %-10s %-10s %s\n' "$_id" "$_status" "$_outcome" "$_exit_reason" "$_branch"
    done
}

# --- Render delta table ---

render_delta() {
    # $1 = prev_json (snapshot), $2 = curr_json (current state)
    _prev=$1
    _curr=$2

    # Build delta: task id + prev status/outcome/exit_reason + curr status/outcome/exit_reason
    # Filter: only include tasks where at least one of (status, outcome, exit_reason) genuinely changed.
    # Uses || "" on curr to normalize null→"" so null comparison works correctly against snapshot values.
    _changes=$(printf '%s' "$_curr" | jq -c --argjson prev "$_prev" '
        [.tasks[] | {
            id: .id,
            prev_status: ($prev.tasks[.id].status // null),
            prev_outcome: ($prev.tasks[.id].outcome // null),
            prev_exit:    ($prev.tasks[.id].exit_reason // null),
            curr_status:  (.status // null),
            curr_outcome: (.outcome // null),
            curr_exit:    (.exit_reason // null)
        }] |
        map(select(
            (.prev_status   // null) != (.curr_status  // null) or
            (.prev_outcome  // null) != (.curr_outcome // null) or
            (.prev_exit     // null) != (.curr_exit    // null)
        ))
    ')

    _count=$(printf '%s' "$_changes" | jq 'length')
    if [ "$_count" -eq 0 ] && [ "$_watch" = 0 ]; then
        _dim
        printf 'No changes detected.\n'
        _reset
        return 0
    fi

    if [ "$_count" -eq 0 ]; then
        return 0
    fi

    _bold; _cyan
    printf 'Queue %s — changed tasks (+%s)\n' "$_run_id" "$_count"
    _reset
    printf '%-12s %-14s %-10s %-10s → %-14s %-10s %s\n' \
        'TASK' 'PREV STATUS' 'PREV OUTCOME' 'PREV EXIT' 'CURR STATUS' 'CURR OUTCOME' 'CURR EXIT'
    printf '%.0s-' '' 12; printf ' '; printf '%.0s-' '' 14; printf ' '; printf '%.0s-' '' 10; printf ' '; \
         printf '%.0s-' '' 10; printf ' → '; printf '%.0s-' '' 14; printf ' '; printf '%.0s-' '' 10; printf ' %s\n' 'CURR EXIT'

    printf '%s' "$_changes" | jq -r '.[] |
        select(.prev_status != null) |
        "\(.id)|\(.prev_status // "-")|\(.prev_outcome // "-")|\(.prev_exit // "-")|\(.curr_status // "-")|\(.curr_outcome // "-")|\(.curr_exit // "-")"
    ' | while IFS='|' read -r _id _pstatus _poutcome _pexit _cstatus _coutcome _cexit; do
        printf '%-12s %-14s %-10s %-10s → ' "$_id" "$_pstatus" "$_poutcome" "$_pexit"
        case "$_cstatus" in
            complete) _green; printf '%-14s ' "$_cstatus" ;;
            blocked|skipped) _red; printf '%-14s ' "$_cstatus" ;;
            in_progress) _yellow; printf '%-14s ' "$_cstatus" ;;
            *) printf '%-14s ' "$_cstatus" ;;
        esac
        _reset
        printf '%-10s %s\n' "$_coutcome" "$_cexit"
    done

    # Summary line.
    _summary=$(printf '%s' "$_changes" | jq -r '
        reduce .[] as $t
        ({merged: 0, complete: 0, failed: 0, other: 0};
         if ($t.curr_status == "merged") then
            .merged += 1
         elif ($t.curr_status == "complete") then
            .complete += 1
         elif ($t.curr_status == "blocked" or $t.curr_status == "skipped") then
            .failed += 1
         else
            .other += 1
         end) |
         to_entries |
         map(select(.value > 0) | "\(.key)=\(.value)") |
         join(", ")
    ')
    printf '\n%s\n' "$_summary"
}

# --- Queue completion check ---
# Returns 0 if not complete, 1 if all tasks are in terminal states.

all_terminal() {
    _ats=$(printf '%s' "$_state_json" | jq -r '
        .tasks[] | .status | IN("pending","in_progress","pending_retry") | not
    ' | grep false | wc -l | tr -d ' ')
    [ "$_ats" -eq 0 ]
}

# --- Watch mode footer ---

render_footer() {
    _now=$(_hms)
    _next=$(date -u -d "+${_interval} seconds" +%H:%M:%S 2>/dev/null || {
        # Fallback for BSD date (macOS).
        _next_s=$(( $(date +%s) + _interval ))
        date -r "$_next_s" +%H:%M:%S 2>/dev/null || printf '??:??:??'
    })
    _dim
    printf '\nLast updated: %s | Next poll: %s (Ctrl-C to exit)\n' "$_now" "$_next"
    _reset
}

# --- Watch loop ---

watch_loop() {
    _first=1
    while :; do
        # Check trip-wire at top of each iteration.
        check_tripwire || exit 2

        _read_state || exit 1

        if [ -n "$_snap_path" ] && [ -f "$_snap_path" ]; then
            _prev_snap=$(jq '.' "$_snap_path" 2>/dev/null) || _prev_snap=""
        else
            _prev_snap=""
        fi

        if [ "$_first" = 1 ] || [ -z "$_prev_snap" ]; then
            _first=0
            if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ]; then
                _clear
            fi
            render_full
        else
            render_delta "$_prev_snap" "$_state_json"
        fi

        _write_snapshot "$_snap_path" "$_state_json" || true

        # Check queue completion.
        if all_terminal; then
            _bold; _green
            printf '\nQueue complete — all tasks reached terminal states.\n'
            _reset
            exit 0
        fi

        render_footer

        # Signal-trap-aware sleep.
        # We use a short sleep loop so that INT/TERM interrupts promptly.
        _sleep_remaining=$_interval
        while [ "$_sleep_remaining" -gt 0 ]; do
            _sl=$_sleep_remaining
            [ "$_sl" -gt 1 ] && _sl=1
            sleep "$_sl" 2>/dev/null || { exit 130; }
            _sleep_remaining=$((_sleep_remaining - 1))
        done
    done
}

# --- Main ---

trap 'exit 130' INT
trap 'exit 143' TERM

_read_state || exit 1

_snap_path=$(_snapshot_path "$_run_id")

# Check trip-wire before any output.
check_tripwire || exit 2

if [ "$_watch" = 1 ]; then
    watch_loop
fi

# Single-shot mode.
if [ -n "$_snap_path" ] && [ -f "$_snap_path" ]; then
    _prev_snap=$(jq '.' "$_snap_path" 2>/dev/null) || _prev_snap=""
else
    _prev_snap=""
fi

if [ -z "$_prev_snap" ]; then
    render_full
else
    render_delta "$_prev_snap" "$_state_json"
fi

_write_snapshot "$_snap_path" "$_state_json" || true
exit 0
