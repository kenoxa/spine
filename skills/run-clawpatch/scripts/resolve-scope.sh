#!/bin/sh
# resolve-scope.sh — Resolve a run-clawpatch scope selector to a single git ref.
#
# Prints exactly one line on success: a resolved commit sha/ref, or the literal
# UNSCOPED. Read-only — reads git history and .clawpatch/reports/ mtimes only;
# never writes .clawpatch state.
#
# Usage:
#   resolve-scope.sh --since <ref>
#   resolve-scope.sh --days <n>
#   resolve-scope.sh --last-run
#   resolve-scope.sh --all-open
#   resolve-scope.sh                  # default: --last-run
#
# Unrelated knobs (--jobs, --include-dirty, ...) are ignored, so the caller may
# pass the full argument list verbatim.
#
# Precedence when several are present: --since > --days > --last-run > --all-open.
#
# Exit 0 = resolved (ref or UNSCOPED printed).
# Exit 2 = usage error (missing/invalid value).
# Exit 3 = invalid explicit --since ref (caller named a commit that does not
#          exist) — a halt signal, never a silent fallback to unscoped.

set -eu

REPORTS_DIR=".clawpatch/reports"

since=""
days=""
last_run=0
all_open=0

while [ $# -gt 0 ]; do
    case "$1" in
        --since)
            [ $# -ge 2 ] || { printf 'resolve-scope: --since requires a ref\n' >&2; exit 2; }
            since="$2"; shift 2 ;;
        --days)
            [ $# -ge 2 ] || { printf 'resolve-scope: --days requires a number\n' >&2; exit 2; }
            days="$2"; shift 2 ;;
        --last-run) last_run=1; shift ;;
        --all-open) all_open=1; shift ;;
        *) shift ;;
    esac
done

# --- Precedence: explicit ref wins ---
if [ -n "$since" ]; then
    if git rev-parse --verify --quiet "${since}^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$since"
        exit 0
    fi
    printf 'resolve-scope: --since ref not found: %s\n' "$since" >&2
    exit 3
fi

# --- Relative window ---
if [ -n "$days" ]; then
    case "$days" in
        ''|*[!0-9]*) printf 'resolve-scope: --days needs a non-negative integer: %s\n' "$days" >&2; exit 2 ;;
    esac
    # Fail-secure guard for git approxidate's pre-epoch break: a window reaching
    # at or before the Unix epoch (1970) cannot contain any commit, and git
    # silently DROPS an unparseable pre-epoch relative date — returning HEAD, an
    # inverted full-repo scope. Resolve such windows to UNSCOPED directly. The
    # comparison (days >= days-since-epoch) avoids overflow and stays safe even
    # if it ever fires early: the fallback is UNSCOPED, never the full repo.
    now_epoch=$(date -u +%s 2>/dev/null || printf 0)
    if [ "$now_epoch" -gt 0 ] && [ "$days" -ge "$(( now_epoch / 86400 ))" ]; then
        printf 'UNSCOPED\n'
        exit 0
    fi
    ref=$(git rev-list -1 --before="${days} days ago" HEAD 2>/dev/null || true)
    [ -n "$ref" ] && { printf '%s\n' "$ref"; exit 0; }
    printf 'UNSCOPED\n'
    exit 0
fi

# --- Explicit all-open (only when last-run was not also requested) ---
if [ "$all_open" -eq 1 ] && [ "$last_run" -eq 0 ]; then
    printf 'UNSCOPED\n'
    exit 0
fi

# --- Default: since the last Clawpatch run (newest report mtime → ref) ---
newest=$(ls -t "$REPORTS_DIR"/* 2>/dev/null | head -1 || true)
if [ -n "$newest" ] && [ -f "$newest" ]; then
    # Epoch mtime — BSD (stat -f %m) then GNU (stat -c %Y).
    mtime=$(stat -f %m "$newest" 2>/dev/null || stat -c %Y "$newest" 2>/dev/null || true)
    if [ -n "$mtime" ]; then
        # Epoch → ISO-8601 UTC — BSD (date -r) then GNU (date -d @epoch).
        iso=$(date -u -r "$mtime" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d "@$mtime" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)
        if [ -n "$iso" ]; then
            ref=$(git rev-list -1 --before="$iso" HEAD 2>/dev/null || true)
            [ -n "$ref" ] && { printf '%s\n' "$ref"; exit 0; }
        fi
    fi
fi

printf 'UNSCOPED\n'
exit 0
