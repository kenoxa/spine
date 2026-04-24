#!/bin/sh
# queue-lint.sh — enqueue-time static validation of a run-queue queue directory.
# Exit 0 = valid (silent). Exit 1 = invalid (errors on stderr, counts on stdout).
# Refuses invalid queues before the supervisor spawns any process.
#
# Usage: queue-lint.sh <queue-dir>

set -eu

_err() { printf '%s\n' "$*" >&2; }

_usage() {
    cat <<'EOF' >&2
Usage: queue-lint.sh <queue-dir>

Validate a queue directory against the schema in
skills/run-queue/references/queue-schema.md.
EOF
}

[ $# -eq 1 ] || { _usage; exit 2; }
_qdir=$1

# --- Preconditions ---

[ -d "$_qdir" ]              || { _err "queue-lint: not a directory: $_qdir"; exit 1; }
[ -f "$_qdir/queue.yaml" ]    || { _err "queue-lint: missing queue.yaml in $_qdir"; exit 1; }

command -v yq >/dev/null 2>&1 || { _err "queue-lint: yq not found — install via brew (see SPINE.md routing)"; exit 2; }
command -v jq >/dev/null 2>&1 || { _err "queue-lint: jq not found"; exit 2; }

# --- Parse queue.yaml → JSON for jq-based inspection ---

_qjson=$(yq -o=json eval '.' "$_qdir/queue.yaml" 2>/dev/null) || {
    _err "queue-lint: queue.yaml parse error"
    yq -o=json eval '.' "$_qdir/queue.yaml" >/dev/null 2>&1 || yq eval '.' "$_qdir/queue.yaml" 2>&1 >/dev/null | head -5 >&2
    exit 1
}

_n_err=0
_record() { _err "queue-lint: $*"; _n_err=$((_n_err + 1)); }

# --- Top-level required fields ---

for _f in run_id tasks; do
    _v=$(printf '%s' "$_qjson" | jq -r --arg f "$_f" '.[$f] // empty')
    [ -z "$_v" ] && _record "queue.yaml missing required field: $_f"
done

_run_id=$(printf '%s' "$_qjson" | jq -r '.run_id // empty')
case "$_run_id" in
    ''|*' '*|*'/'*) [ -z "$_run_id" ] || _record "run_id contains invalid characters (no spaces or slashes): $_run_id" ;;
esac

# --- Profile (optional overlay) ---

_profile_path=$(printf '%s' "$_qjson" | jq -r '.profile // empty')
if [ -n "$_profile_path" ]; then
    case "$_profile_path" in
        /*) _profile_abs=$_profile_path ;;
         *) _profile_abs="$_qdir/$_profile_path" ;;
    esac
    if [ ! -f "$_profile_abs" ]; then
        _record "profile not found: $_profile_path (resolved: $_profile_abs)"
    elif ! jq -e . "$_profile_abs" >/dev/null 2>&1; then
        _record "profile not valid JSON: $_profile_path"
    fi
fi

# --- Tasks: unique ids, handoff files, frontmatter, dependency refs ---

_n_tasks=$(printf '%s' "$_qjson" | jq -r '.tasks | length // 0')
if [ "$_n_tasks" -eq 0 ]; then
    _record "queue.yaml has no tasks"
fi

_task_ids=$(printf '%s' "$_qjson" | jq -r '.tasks[]?.id // empty')

# Duplicate check
_dup=$(printf '%s\n' "$_task_ids" | sort | uniq -d)
[ -n "$_dup" ] && while IFS= read -r _d; do
    [ -n "$_d" ] && _record "duplicate task id: $_d"
done <<EOF
$_dup
EOF

# Per-task validation
_i=0
while [ "$_i" -lt "$_n_tasks" ]; do
    _task=$(printf '%s' "$_qjson" | jq -c --argjson i "$_i" '.tasks[$i]')
    _id=$(printf '%s' "$_task" | jq -r '.id // empty')
    _i=$((_i + 1))

    if [ -z "$_id" ]; then
        _record "tasks[$((_i - 1))] missing id"
        continue
    fi

    # Handoff path
    _handoff_rel=$(printf '%s' "$_task" | jq -r --arg id "$_id" '.handoff // ("handoff-" + $id + ".md")')
    _handoff_abs="$_qdir/$_handoff_rel"
    if [ ! -f "$_handoff_abs" ]; then
        _record "$_id: missing handoff file: $_handoff_rel"
        continue
    fi

    # Frontmatter — extract first YAML block between --- markers, starting at line 1.
    _fm=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==2) exit; next} n==1{print}' "$_handoff_abs")
    if [ -z "$_fm" ]; then
        _record "$_id: handoff has no frontmatter: $_handoff_rel"
        continue
    fi

    # Parse frontmatter via yq
    _fm_json=$(printf '%s' "$_fm" | yq -o=json eval '.' - 2>/dev/null) || {
        _record "$_id: handoff frontmatter parse error: $_handoff_rel"
        continue
    }

    # Required frontmatter fields
    for _req in task_id entry_skill; do
        _v=$(printf '%s' "$_fm_json" | jq -r --arg k "$_req" '.[$k] // empty')
        [ -z "$_v" ] && _record "$_id: frontmatter missing required: $_req"
    done

    # task_id must match queue.yaml id
    _fm_task_id=$(printf '%s' "$_fm_json" | jq -r '.task_id // empty')
    if [ -n "$_fm_task_id" ] && [ "$_fm_task_id" != "$_id" ]; then
        _record "$_id: frontmatter task_id '$_fm_task_id' does not match queue.yaml id"
    fi

    # One of terminal_check / terminal_artifact
    _tc=$(printf '%s' "$_fm_json" | jq -r '.terminal_check // empty')
    _ta=$(printf '%s' "$_fm_json" | jq -r '.terminal_artifact // empty')
    if [ -z "$_tc" ] && [ -z "$_ta" ]; then
        _record "$_id: frontmatter missing both terminal_check and terminal_artifact"
    fi
    if [ -n "$_tc" ] && [ -n "$_ta" ]; then
        _record "$_id: frontmatter sets both terminal_check and terminal_artifact (choose one)"
    fi

    # on_failure enum
    _of=$(printf '%s' "$_fm_json" | jq -r '.on_failure // empty')
    if [ -n "$_of" ]; then
        case "$_of" in
            stop|skip|retry_once) : ;;
            *) _record "$_id: invalid on_failure '$_of' (expected: stop|skip|retry_once)" ;;
        esac
    fi

    # max_iterations positive integer
    _mi=$(printf '%s' "$_fm_json" | jq -r '.max_iterations // empty')
    if [ -n "$_mi" ]; then
        case "$_mi" in
            ''|*[!0-9]*) _record "$_id: max_iterations must be a positive integer, got '$_mi'" ;;
            0)           _record "$_id: max_iterations must be > 0" ;;
        esac
    fi
done

# --- depends_on references existing task ids ---

_i=0
while [ "$_i" -lt "$_n_tasks" ]; do
    _task=$(printf '%s' "$_qjson" | jq -c --argjson i "$_i" '.tasks[$i]')
    _id=$(printf '%s' "$_task" | jq -r '.id // empty')
    _deps=$(printf '%s' "$_task" | jq -r '.depends_on[]? // empty')
    _i=$((_i + 1))
    [ -z "$_deps" ] && continue

    while IFS= read -r _dep; do
        [ -z "$_dep" ] && continue
        if ! printf '%s\n' "$_task_ids" | grep -Fxq -- "$_dep"; then
            _record "$_id: unknown dep: $_dep"
        fi
        if [ "$_dep" = "$_id" ]; then
            _record "$_id: self-dependency"
        fi
    done <<EOF
$_deps
EOF
done

# --- Cycle detection via tsort (Slice B will also do transitive checks) ---

if command -v tsort >/dev/null 2>&1 && [ "$_n_tasks" -gt 0 ]; then
    _edges=$(printf '%s' "$_qjson" | jq -r '
        .tasks[] as $t
        | ($t.depends_on // [])[]
        | . + " " + $t.id
    ')
    if [ -n "$_edges" ]; then
        _tsort_err=$(printf '%s\n' "$_edges" | tsort 2>&1 >/dev/null || true)
        if printf '%s' "$_tsort_err" | grep -q 'cycle'; then
            _record "cycle in queue.yaml depends_on — tsort: $(printf '%s' "$_tsort_err" | tr '\n' ' ')"
        fi
    fi
fi

# --- Exit ---

if [ "$_n_err" -gt 0 ]; then
    _err "queue-lint: $_n_err error(s)"
    exit 1
fi
exit 0
