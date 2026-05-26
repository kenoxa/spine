#!/bin/sh
# worktree.sh — Spine git-worktree lifecycle manager.
#
# Subcommands: create / list / remove / prune / sync / land
#
# macOS/APFS assumed for carry-over: cp -cR uses clonefile(2) for copy-on-write
# clones (instant, near-zero disk). On Linux cp -cR falls back to a regular copy.
#
# Usage: sh worktree.sh <subcommand> [args]

set -eu

# --- Helpers ---

die() {
    printf 'worktree: %s\n' "$*" >&2
    exit 1
}

# Distinct exit status for an agent-resolvable rebase conflict (generic die = 1).
# sync/land leave the rebase IN PROGRESS so an agent can resolve and continue —
# see references/conflict-resolution.md.
CONFLICT_EXIT=3

_conflict_exit() {
    # $1 = worktree abs path  ·  $2 = human message
    printf 'worktree: %s\n' "$2" >&2
    printf 'worktree-path: %s\n' "$1" >&2
    exit "$CONFLICT_EXIT"
}

# True when a rebase is mid-flight in the worktree at $1.
_rebase_in_progress() {
    [ -d "$(git -C "$1" rev-parse --path-format=absolute --git-path rebase-merge 2>/dev/null)" ] \
        || [ -d "$(git -C "$1" rev-parse --path-format=absolute --git-path rebase-apply 2>/dev/null)" ]
}

main_root() {
    # Capture output and exit code separately — POSIX sh has no pipefail, so
    # piping directly would swallow a git failure (awk exits 0 on empty input).
    wl_out=$(git worktree list --porcelain 2>/dev/null) \
        || die "git worktree list failed — not a git repository?"
    printf '%s\n' "$wl_out" | awk '/^worktree /{print $2; exit}'
}

valid_slug() {
    case "$1" in
        [a-z0-9]*) : ;;
        *) die "invalid slug '$1' — must match ^[a-z0-9][a-z0-9-]*\$" ;;
    esac
    case "$1" in
        *[!a-z0-9-]*) die "invalid slug '$1' — must match ^[a-z0-9][a-z0-9-]*\$" ;;
    esac
}

# --- Ignore guard: write anchored entries to common git dir's info/exclude ---
# Idempotent: appends $anchor to info/exclude only when the exact line is absent.
# Does NOT short-circuit via check-ignore: a directory-only rule (e.g. `.scratch/`)
# satisfies check-ignore against a real directory but not against a symlink with the
# same name, so we always ensure the anchored entry is present.

_ensure_excluded() {
    root="$1" anchor="$2"
    common=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null) \
        || die "git rev-parse --git-common-dir failed"

    # Make absolute if relative (linked worktrees return a relative path)
    case "$common" in
        /*) : ;;
        *) common="$root/$common" ;;
    esac

    exclude="$common/info/exclude"
    mkdir -p "$(dirname "$exclude")"
    if [ ! -f "$exclude" ]; then
        printf '' > "$exclude"
    fi

    # Idempotent append
    if ! grep -qxF "$anchor" "$exclude" 2>/dev/null; then
        printf '%s\n' "$anchor" >> "$exclude"
    fi
}

# --- Active session resolution (G1) ---
# Find the single in-progress session under .scratch/, if any, by reading
# session.json files. Returns 0 + prints session_id when exactly one active
# session exists; returns 2 when none, 3 when ambiguous (prints candidate ids
# on stderr in that case). Uses grep/sed only — avoids a JSON parser dependency.
_resolve_active_session() {
    root="$1"
    scratch="$root/.scratch"
    [ -d "$scratch" ] || return 2

    found_sid=""
    count=0
    # Avoid noisy glob when the pattern doesn't match
    for sjson in "$scratch"/*/session.json; do
        [ -f "$sjson" ] || continue
        status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$sjson" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        [ "$status" = "in_progress" ] || continue
        # attention_required:true disqualifies
        if grep -q '"attention_required"[[:space:]]*:[[:space:]]*true' "$sjson" 2>/dev/null; then
            continue
        fi
        sid=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$sjson" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        [ -n "$sid" ] || continue
        count=$((count + 1))
        if [ "$count" = "1" ]; then
            found_sid="$sid"
        else
            printf 'worktree: ambiguous active session: %s\n' "$sid" >&2
        fi
    done

    case "$count" in
        0) return 2 ;;
        1) printf '%s\n' "$found_sid"; return 0 ;;
        *) printf 'worktree: ambiguous active session: %s\n' "$found_sid" >&2; return 3 ;;
    esac
}

# Strip the trailing -<4-char> hash from a session_id to recover the slug.
# Session ids follow `<slug>-<4-hex>` per SPINE.md; openssl rand -hex 2 generates
# the hash. Match shape, not content.
_slug_from_session_id() {
    sid="$1"
    case "$sid" in
        *-????) printf '%s\n' "${sid%-????}" ;;
        *) die "session_id '$sid' does not match <slug>-<4hex> shape" ;;
    esac
}

# --- Read project skip-list ---
# Returns newline-separated paths (trailing / stripped).
_skip_set() {
    root="$1"
    skip_file="$root/.worktree-skip"

    printf '.worktrees\n.scratch\n'

    if [ -f "$skip_file" ]; then
        while IFS= read -r line; do
            case "$line" in
                ''|\#*) continue ;;
            esac
            # Strip trailing slash
            printf '%s\n' "${line%/}"
        done < "$skip_file"
    fi
}

# --- Subcommands ---

cmd_create() {
    slug=""
    refresh=0
    session_id=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --refresh) refresh=1; shift ;;
            --session=*) session_id="${1#--session=}"; shift ;;
            --session) shift; session_id="${1:-}"; [ -n "$session_id" ] || die "--session requires a value"; shift ;;
            -*) die "unknown flag '$1'" ;;
            *) slug="$1"; shift ;;
        esac
    done

    root=$(main_root)

    # G1: auto-derive slug from active session when not provided.
    # Precedence: explicit slug > --session=<id> > single in-progress session.json
    if [ -z "$slug" ]; then
        if [ -z "$session_id" ]; then
            if session_id=$(_resolve_active_session "$root" 2>/dev/null); then
                :
            else
                rc=$?
                case "$rc" in
                    2) die "create requires a slug argument (no active session found under .scratch/)" ;;
                    3) die "create requires a slug argument (multiple in_progress sessions under .scratch/ — pass --session=<id> or an explicit slug)" ;;
                    *) die "create requires a slug argument" ;;
                esac
            fi
        fi
        slug=$(_slug_from_session_id "$session_id")
        printf 'worktree: deriving slug=%s from session=%s\n' "$slug" "$session_id" >&2
    fi

    valid_slug "$slug"
    wt_parent="$root/.worktrees"

    # Ignore guard. The .scratch anchor has NO trailing slash on purpose: inside
    # a worktree .scratch is a symlink, and a trailing-slash pattern matches
    # directories only — git would leave the bridge symlink untracked-and-
    # unignored, and the remove clean-check would then refuse every worktree.
    _ensure_excluded "$root" "/.worktrees/"
    _ensure_excluded "$root" "/.scratch"

    if [ "$refresh" = "1" ]; then
        # Find existing worktree for this slug
        wt=""
        for d in "$wt_parent/$slug"-*/; do
            if [ -d "$d" ]; then
                wt="${d%/}"
                break
            fi
        done
        [ -n "$wt" ] || die "no worktree for slug '$slug' to refresh"
    else
        # Die if slug already used (dir or branch)
        for d in "$wt_parent/$slug"-*/; do
            if [ -d "$d" ]; then
                die "worktree or branch for slug '$slug' already exists — pass --refresh to re-copy carry-over, or remove it first"
            fi
        done
        if git -C "$root" show-ref --verify --quiet "refs/heads/$slug" 2>/dev/null; then
            die "worktree or branch for slug '$slug' already exists — pass --refresh to re-copy carry-over, or remove it first"
        fi

        # Create new worktree
        hash=$(openssl rand -hex 2)
        wt="$wt_parent/$slug-$hash"
        mkdir -p "$wt_parent"
        git -C "$root" worktree add "$wt" -b "$slug"

        # Session bridge
        mkdir -p "$root/.scratch"
        ln -s "$root/.scratch" "$wt/.scratch"
    fi

    # Carry-over: enumerate ignored top-level entries.
    # --ignored=matching collapses ignored directories to a single dir/ entry
    # so the skip-set comparison works and avoids per-file cp for large trees.
    # -c core.quotePath=false suppresses C-quoting so spaces/non-ASCII are safe.
    skip_list=$(_skip_set "$root")
    status_out=$(git -c core.quotePath=false -C "$root" status --porcelain --ignored=matching 2>/dev/null) \
        || die "git status failed"

    while IFS= read -r line; do
        case "$line" in
            '!! '*) e="${line#!! }" ;;
            *) continue ;;
        esac

        # git wraps paths containing spaces in literal double-quotes even with
        # core.quotePath=false (which only suppresses C-escaping of non-ASCII bytes).
        # Paths with tabs, quotes, or backslashes are also wrapped, but their
        # C-escaped inner bytes (\t, \", \\) are NOT decoded here — tracked as
        # known limitation. Unwrap the outer "..." pair for the common space case.
        case "$e" in
            '"'*'"') e="${e#\"}"; e="${e%\"}" ;;
        esac

        # Strip trailing slash (--ignored=matching emits dir/ entries)
        e="${e%/}"

        # Check against skip set
        if printf '%s\n' "$skip_list" | grep -qxF "$e"; then
            continue
        fi

        src="$root/$e"
        dest="$wt/$e"
        if [ "$refresh" = "1" ] && [ -e "$dest" ]; then
            rm -rf "$dest"
        fi
        mkdir -p "$(dirname "$dest")"
        cp -cR "$src" "$dest" || die "cp failed: $src → $dest"
    done <<STATUSEOF
$status_out
STATUSEOF

    if [ "$refresh" = "1" ]; then
        printf 'refreshed: %s\n' "$wt"
    else
        printf 'created: %s\n' "$wt"
    fi
}

cmd_list() {
    root=$(main_root)
    wt_parent="$root/.worktrees"

    # Capture output and exit code separately — same pattern as main_root (B4).
    wl_out=$(git -C "$root" worktree list --porcelain 2>/dev/null) \
        || die "git worktree list failed"

    printf '%s\n' "$wl_out" | {
        path=""
        head=""
        branch=""
        detached=0

        flush() {
            [ -z "$path" ] && return 0
            short=$(printf '%s' "$head" | cut -c1-8)
            label=""
            case "$path" in
                "$wt_parent/"*) label=" [spine]" ;;
            esac
            if [ "$detached" = "1" ]; then
                printf '%-50s  %-30s  %s%s\n' "$path" "(detached)" "$short" "$label"
            else
                printf '%-50s  %-30s  %s%s\n' "$path" "$branch" "$short" "$label"
            fi
        }

        while IFS= read -r line; do
            case "$line" in
                "worktree "*)
                    flush
                    path="${line#worktree }"
                    head=""
                    branch=""
                    detached=0
                    ;;
                "HEAD "*)
                    head="${line#HEAD }"
                    ;;
                "branch "*)
                    branch="${line#branch refs/heads/}"
                    ;;
                detached)
                    detached=1
                    ;;
            esac
        done
        flush
    }
}

cmd_remove() {
    [ $# -ge 1 ] || die "remove requires a worktree name or path"
    name="$1"
    root=$(main_root)

    # Resolve: absolute path or name under .worktrees/
    if [ -d "$name" ]; then
        wt="$name"
    else
        wt="$root/.worktrees/$name"
    fi
    [ -d "$wt" ] || die "no worktree directory found: $name"

    # Clean-check (no --ignored: carried artifacts + .scratch symlink invisible)
    status_out=$(git -C "$wt" status --porcelain 2>/dev/null) || die "git status failed in '$wt'"
    if [ -n "$status_out" ]; then
        printf '%s\n' "$status_out" >&2
        die "worktree '$name' has uncommitted or untracked changes — commit, stash, or discard, then retry"
    fi

    git -C "$root" worktree remove --force "$wt"
    printf 'removed: %s  (branch kept)\n' "$wt"
}

cmd_prune() {
    root=$(main_root)
    output=$(git -C "$root" worktree prune -v 2>&1) || die "git worktree prune failed"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
    else
        printf 'nothing to prune\n'
    fi
}

cmd_sync() {
    [ $# -ge 1 ] || die "sync requires a worktree name or path"
    name="$1"
    root=$(main_root)

    # Resolve: absolute path or name under .worktrees/
    if [ -d "$name" ]; then
        wt="$name"
    else
        wt="$root/.worktrees/$name"
    fi
    [ -d "$wt" ] || die "no worktree directory found: $name"
    wt=$(cd "$wt" && pwd -P) || die "cannot resolve worktree path: $name"

    main_branch=$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null) \
        || die "main checkout is in detached HEAD — cannot determine main branch"
    [ -n "$main_branch" ] || die "main checkout is in detached HEAD — cannot determine main branch"

    wt_branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null) \
        || die "worktree is in detached HEAD — sync requires a branch to rebase"
    [ -n "$wt_branch" ] || die "worktree is in detached HEAD — sync requires a branch to rebase"

    if ! git -C "$wt" rebase "$main_branch"; then
        if _rebase_in_progress "$wt"; then
            _conflict_exit "$wt" "rebase conflict in '$wt' — see references/conflict-resolution.md to resolve, or abort: git -C '$wt' rebase --abort"
        fi
        die "rebase onto '$main_branch' failed in '$wt' with no rebase in progress — inspect: git -C '$wt' status"
    fi

    printf 'synced: %s  (rebased onto %s)\n' "$wt" "$main_branch"
}

cmd_land() {
    [ $# -ge 1 ] || die "land requires a worktree name or path"
    name="$1"
    root=$(main_root)

    # Resolve: absolute path or name under .worktrees/
    if [ -d "$name" ]; then
        wt="$name"
    else
        wt="$root/.worktrees/$name"
    fi
    [ -d "$wt" ] || die "no worktree directory found: $name"
    wt=$(cd "$wt" && pwd -P) || die "cannot resolve worktree path: $name"
    [ "$wt" != "$root" ] || die "cannot land the main worktree"

    main_branch=$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null) \
        || die "main checkout is in detached HEAD — cannot determine main branch"
    [ -n "$main_branch" ] || die "main checkout is in detached HEAD — cannot determine main branch"

    wt_branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null) \
        || die "worktree is in detached HEAD — land requires a branch to rebase"
    [ -n "$wt_branch" ] || die "worktree is in detached HEAD — land requires a branch to rebase"

    # Step 1: rebase (before any destructive step)
    if ! git -C "$wt" rebase "$main_branch"; then
        if _rebase_in_progress "$wt"; then
            _conflict_exit "$wt" "rebase conflict in '$wt' — see references/conflict-resolution.md to resolve, or abort: git -C '$wt' rebase --abort"
        fi
        die "rebase onto '$main_branch' failed in '$wt' with no rebase in progress — inspect: git -C '$wt' status"
    fi

    # Step 2: fast-forward merge into main
    if ! git -C "$root" merge --ff-only "$wt_branch"; then
        die "merge --ff-only failed — '$wt_branch' could not be fast-forwarded into '$main_branch'"
    fi

    # Step 3: clean-check then force-remove the worktree
    status_out=$(git -C "$wt" status --porcelain 2>/dev/null) || die "git status failed in '$wt'"
    if [ -n "$status_out" ]; then
        die "'$wt_branch' was merged into '$main_branch' but '$wt' has unexpected uncommitted changes — land halted before removing the worktree. Inspect the changes, then finish manually: git -C '$root' worktree remove --force '$wt' && git -C '$root' branch -d '$wt_branch'"
    fi
    if ! git -C "$root" worktree remove --force "$wt"; then
        die "'$wt_branch' was merged into '$main_branch' but the worktree at '$wt' could not be removed — remove it manually: git -C '$root' worktree remove --force '$wt'"
    fi

    # Step 4: delete the branch (safe: merged in step 2, worktree gone in step 3)
    if ! git -C "$root" branch -d "$wt_branch"; then
        die "'$wt_branch' was merged into '$main_branch' and the worktree removed, but branch '$wt_branch' could not be deleted — delete it manually: git -C '$root' branch -d '$wt_branch'"
    fi

    printf 'landed: %s merged into %s; worktree and branch removed\n' "$wt_branch" "$main_branch"
}

# --- Usage ---

usage() {
    cat <<'EOF'
Usage: sh worktree.sh <subcommand> [args]

Subcommands:
  create [<slug>] [--session=<id>] [--refresh]
                             New branch + worktree at .worktrees/<slug>-<hash>/
                             Omit <slug> to derive it from the active session
                             under .scratch/. --session=<id> disambiguates.
  list                       Show all worktrees (marks Spine-managed with [spine])
  remove <name>              Clean-check then remove worktree dir (branch kept)
  prune                      Clear orphaned worktree admin files
  sync <name>                Rebase worktree branch onto current main (no fetch)
  land <name>                Rebase, merge into main, remove worktree and branch
EOF
}

# --- Dispatch ---

[ $# -ge 1 ] || { usage; exit 0; }

cmd="$1"
shift

case "$cmd" in
    create) cmd_create "$@" ;;
    list)   cmd_list   "$@" ;;
    remove) cmd_remove "$@" ;;
    prune)  cmd_prune  "$@" ;;
    sync)   cmd_sync   "$@" ;;
    land)   cmd_land   "$@" ;;
    ''|-h|--help|help) usage; exit 0 ;;
    *) die "unknown subcommand '$cmd' — run 'sh worktree.sh --help' for usage" ;;
esac
