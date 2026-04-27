#!/bin/sh
# queue-lint.sh — enqueue-time static validation of a run-queue queue directory.
# Exit 0 = valid (silent). Exit 1 = invalid (errors on stderr, counts on stdout).
# Refuses invalid queues before the supervisor spawns any process.
#
# Usage: queue-lint.sh <queue-dir>

set -eu

# Locale guard for byte-level validation. POSIX `case` charset patterns
# consult LC_CTYPE in locale-aware shells; validators below pair this
# with explicit allowlists. See docs/shell-validator-locale-guard.md.
LC_ALL=C

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
    '') _record "run_id missing" ;;
    *..*) _record "run_id may not contain '..' (git refname rule): $_run_id" ;;
    *.git) _record "run_id may not end with '.git': $_run_id" ;;
    .*) _record "run_id may not start with '.' (git refname rule): $_run_id" ;;
    *[[:space:]]*) _record "run_id may not contain whitespace: $_run_id" ;;
    *'/'*) _record "run_id may not contain '/': $_run_id" ;;
    *[!A-Za-z0-9._-]*) _record "run_id contains chars outside [A-Za-z0-9._-]: $_run_id" ;;
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

# --- Queue-level pipeline fields (optional) ---

# review_check — queue-level default; bool; true|false
_q_rc=$(printf '%s' "$_qjson" | jq -r '.review_check // empty')
if [ -n "$_q_rc" ]; then
    case "$_q_rc" in
        true|false) : ;;
        *) _record "queue.yaml: invalid review_check '$_q_rc' (expected: true|false)" ;;
    esac
fi

# review_depth — queue-level default; string-enum
_q_rd=$(printf '%s' "$_qjson" | jq -r '.review_depth // empty')
if [ -n "$_q_rd" ]; then
    case "$_q_rd" in
        *[[:space:]]*)
            _record "queue.yaml: review_depth contains whitespace" ;;
        *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
            _record "queue.yaml: review_depth contains shell metachars (\`\$|;&><\\ not permitted)" ;;
    esac
    if [ ${#_q_rd} -gt 64 ]; then
        _record "queue.yaml: review_depth exceeds 64 characters"
    fi
    case "$_q_rd" in
        *[!A-Za-z0-9_-]*)
            _record "queue.yaml: review_depth contains characters outside allowed set [A-Za-z0-9_-]" ;;
    esac
    case "$_q_rd" in
        focused|standard|deep) : ;;
        *) _record "queue.yaml: invalid review_depth '$_q_rd' (expected: focused|standard|deep)" ;;
    esac
fi

# merge_policy — queue-level default; string-enum
_q_mp=$(printf '%s' "$_qjson" | jq -r '.merge_policy // empty')
if [ -n "$_q_mp" ]; then
    case "$_q_mp" in
        *[[:space:]]*)
            _record "queue.yaml: merge_policy contains whitespace" ;;
        *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
            _record "queue.yaml: merge_policy contains shell metachars (\`\$|;&><\\ not permitted)" ;;
    esac
    if [ ${#_q_mp} -gt 64 ]; then
        _record "queue.yaml: merge_policy exceeds 64 characters"
    fi
    case "$_q_mp" in
        *[!A-Za-z0-9_-]*)
            _record "queue.yaml: merge_policy contains characters outside allowed set [A-Za-z0-9_-]" ;;
    esac
    case "$_q_mp" in
        auto|manual) : ;;
        *) _record "queue.yaml: invalid merge_policy '$_q_mp' (expected: auto|manual)" ;;
    esac
fi

# branch_cleanup — queue-level ONLY; string-enum
_q_bc=$(printf '%s' "$_qjson" | jq -r '.branch_cleanup // empty')
if [ -n "$_q_bc" ]; then
    case "$_q_bc" in
        *[[:space:]]*)
            _record "queue.yaml: branch_cleanup contains whitespace" ;;
        *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
            _record "queue.yaml: branch_cleanup contains shell metachars (\`\$|;&><\\ not permitted)" ;;
    esac
    if [ ${#_q_bc} -gt 64 ]; then
        _record "queue.yaml: branch_cleanup exceeds 64 characters"
    fi
    case "$_q_bc" in
        *[!A-Za-z0-9_-]*)
            _record "queue.yaml: branch_cleanup contains characters outside allowed set [A-Za-z0-9_-]" ;;
    esac
    case "$_q_bc" in
        after_success|never) : ;;
        *) _record "queue.yaml: invalid branch_cleanup '$_q_bc' (expected: after_success|never)" ;;
    esac
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

    # task_id may not contain whitespace — spaces break _cps_parent_branches space-splitting
    case "$_id" in
        *[[:space:]]*) _record "$_id: task_id may not contain whitespace (breaks parent-branch splitting)" ;;
    esac

    # One of terminal_check / terminal_artifact
    _tc=$(printf '%s' "$_fm_json" | jq -r '.terminal_check // empty')
    _ta=$(printf '%s' "$_fm_json" | jq -r '.terminal_artifact // empty')
    if [ -z "$_tc" ] && [ -z "$_ta" ]; then
        _record "$_id: frontmatter missing both terminal_check and terminal_artifact"
    fi
    if [ -n "$_tc" ] && [ -n "$_ta" ]; then
        _record "$_id: frontmatter sets both terminal_check and terminal_artifact (choose one)"
    fi
    if [ -n "$_tc" ]; then
        case "$_tc" in
            *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
                _record "$_id: terminal_check contains shell metachars (\`\$|;&><\\ not permitted): $_tc" ;;
        esac
        # Newline check — $'\n' is a bash extension; compare stripped vs original
        _tc_stripped=$(printf '%s' "$_tc" | tr -d '\n')
        if [ "$_tc_stripped" != "$_tc" ]; then
            _record "$_id: terminal_check contains newline"
        fi
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

    # model — optional; flat string; provider-scoped runtime selector for the spawned child
    _mo=$(printf '%s' "$_fm_json" | jq -r '.model // empty')
    if [ -n "$_mo" ]; then
        case "$_mo" in
            *[[:space:]]*)
                _record "$_id: model contains whitespace" ;;
            *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
                _record "$_id: model contains shell metachars (\`\$|;&><\\ not permitted)" ;;
        esac
        if [ ${#_mo} -gt 128 ]; then
            _record "$_id: model exceeds 128 characters"
        fi
        case "$_mo" in
            *[!A-Za-z0-9._:/\[\]_-]*)
                _record "$_id: model contains characters outside allowed set [A-Za-z0-9._:/[]_-]" ;;
        esac
    fi

    # review_check — optional bool; per-handoff override; accepts true|false only
    _rc=$(printf '%s' "$_fm_json" | jq -r '.review_check // empty')
    if [ -n "$_rc" ]; then
        case "$_rc" in
            true|false) : ;;
            *) _record "$_id: invalid review_check '$_rc' (expected: true|false)" ;;
        esac
    fi

    # review_depth — optional string-enum; per-handoff override
    _rd=$(printf '%s' "$_fm_json" | jq -r '.review_depth // empty')
    if [ -n "$_rd" ]; then
        case "$_rd" in
            *[[:space:]]*)
                _record "$_id: review_depth contains whitespace" ;;
            *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
                _record "$_id: review_depth contains shell metachars (\`\$|;&><\\ not permitted)" ;;
        esac
        if [ ${#_rd} -gt 64 ]; then
            _record "$_id: review_depth exceeds 64 characters"
        fi
        case "$_rd" in
            *[!A-Za-z0-9_-]*)
                _record "$_id: review_depth contains characters outside allowed set [A-Za-z0-9_-]" ;;
        esac
        case "$_rd" in
            focused|standard|deep) : ;;
            *) _record "$_id: invalid review_depth '$_rd' (expected: focused|standard|deep)" ;;
        esac
    fi

    # merge_policy — optional string-enum; per-handoff override
    _mp=$(printf '%s' "$_fm_json" | jq -r '.merge_policy // empty')
    if [ -n "$_mp" ]; then
        case "$_mp" in
            *[[:space:]]*)
                _record "$_id: merge_policy contains whitespace" ;;
            *'`'*|*'$'*|*'|'*|*';'*|*'&'*|*'>'*|*'<'*|*\\*)
                _record "$_id: merge_policy contains shell metachars (\`\$|;&><\\ not permitted)" ;;
        esac
        if [ ${#_mp} -gt 64 ]; then
            _record "$_id: merge_policy exceeds 64 characters"
        fi
        case "$_mp" in
            *[!A-Za-z0-9_-]*)
                _record "$_id: merge_policy contains characters outside allowed set [A-Za-z0-9_-]" ;;
        esac
        case "$_mp" in
            auto|manual) : ;;
            *) _record "$_id: invalid merge_policy '$_mp' (expected: auto|manual)" ;;
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

# --- Cycle detection via tsort ---
# Lint emits only real dep edges ("dep id") — self-edges are not needed here
# because tsort cycle output doesn't require root inclusion. In contrast,
# run.sh's _resolve_topo_order emits self-edges ("id id") for roots to ensure
# they appear in tsort output when they have no dependents.

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
