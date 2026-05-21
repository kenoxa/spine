#!/usr/bin/env bats
# worktree.bats — Behavioral tests for worktree.sh.
# Self-contained: does NOT load test_helper; carries its own make_repo helper.
# Each test runs in an isolated mktemp dir, cleaned up on exit.
#
# Also serves as mandatory Slice 2 preflight: case 10 exercises the _project.sh
# Slice 1 fix (worktree root resolution from inside a script-created worktree).

# Path to the script under test (relative to this file's directory)
WT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/worktree.sh"
# Path to hooks dir for Slice 1 tie-in test
HOOKS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../hooks" && pwd)"

# make_repo <dir> — initialise a minimal committed git repo in <dir>,
# add a gitignored .env.local and a gitignored node_modules/ dir.
make_repo() {
    local dir="$1"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@spine-test.local"
    git -C "$dir" config user.name "Spine Test"
    # Isolate the suite from the user's global git config: a global
    # rebase.autostash=true would autostash a dirty worktree and let a rebase
    # that should refuse instead complete — making dirty-tree negative tests
    # non-deterministic. Pin it false repo-locally; all worktrees share this.
    git -C "$dir" config rebase.autostash false
    git -C "$dir" config rebase.backend merge
    git -C "$dir" config merge.conflictStyle merge
    git -C "$dir" config rerere.enabled false
    # Tracked file
    touch "$dir/.keep"
    git -C "$dir" add .keep
    git -C "$dir" commit -q -m "init"
    # .gitignore
    printf '.env.local\nnode_modules/\n' > "$dir/.gitignore"
    git -C "$dir" add .gitignore
    git -C "$dir" commit -q -m "add .gitignore"
    # Gitignored working state
    printf 'SECRET=test\n' > "$dir/.env.local"
    mkdir -p "$dir/node_modules/fake-pkg"
    touch "$dir/node_modules/fake-pkg/index.js"
}

created_worktree_dir() {
    local output="$1"
    local slug="$2"
    local wt_dir
    wt_dir=$(printf '%s\n' "$output" | sed -n 's/^created: //p' | head -1)
    if [ -z "$wt_dir" ]; then
        printf '%s worktree not found — create failed\n' "$slug" >&2
        return 1
    fi
    printf '%s\n' "$wt_dir"
}

spine_worktree_dir() {
    local repo="$1"
    local slug="$2"
    local wt_dir
    wt_dir=$(ls -d "$repo/.worktrees/$slug-"*/ 2>/dev/null | head -1)
    wt_dir="${wt_dir%/}"
    if [ -z "$wt_dir" ]; then
        printf '%s worktree not found — create failed\n' "$slug" >&2
        return 1
    fi
    printf '%s\n' "$wt_dir"
}

write_hostile_git_config() {
    local path="$1"
    {
        printf '[rebase]\n'
        printf '\tautostash = true\n'
        printf '\tbackend = apply\n'
        printf '[merge]\n'
        printf '\tconflictStyle = diff3\n'
        printf '[rerere]\n'
        printf '\tenabled = true\n'
    } > "$path"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 1: create → worktree dir exists at .worktrees/<slug>-<4hex>/, .git is a file
# ─────────────────────────────────────────────────────────────────────────────
@test "create: worktree dir at .worktrees/<slug>-<hash>/, .git is a file" {
    local repo
    # Resolve symlinks so git's resolved path matches our $repo (SF5)
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create myfeat
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "myfeat")
    [ -d "$wt_dir" ]

    # Name matches pattern .worktrees/myfeat-<4hex>
    case "$wt_dir" in
        "$repo/.worktrees/myfeat-"????) : ;;
        *) false ;;
    esac

    # .git inside worktree is a file (gitdir: pointer)
    [ -f "$wt_dir/.git" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 2: create → /.worktrees/ and /.scratch/ anchored in .git/info/exclude
# ─────────────────────────────────────────────────────────────────────────────
@test "create: ignore guard writes /.worktrees/ and /.scratch to info/exclude" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create myslug
    [ "$status" -eq 0 ]

    local exclude
    exclude=$(git -C "$repo" rev-parse --git-common-dir)
    case "$exclude" in /*) : ;; *) exclude="$repo/$exclude" ;; esac
    exclude="$exclude/info/exclude"

    grep -qxF '/.worktrees/' "$exclude"
    grep -qxF '/.scratch'    "$exclude"

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 3: create → .scratch inside worktree is a symlink resolving to main .scratch
# ─────────────────────────────────────────────────────────────────────────────
@test "create: .scratch in worktree symlinks to main repo .scratch" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create bridge
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "bridge")

    # Must be a symlink
    [ -L "$wt_dir/.scratch" ]

    # Must resolve to main repo's .scratch
    local target
    target=$(readlink "$wt_dir/.scratch")
    # Resolve to absolute if relative
    case "$target" in
        /*) : ;;
        *) target="$(cd "$(dirname "$wt_dir/.scratch")" && cd "$target" && pwd)" ;;
    esac
    [ "$target" = "$repo/.scratch" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 4: create → .env.local carried over; .worktrees/ NOT nested on 2nd create
# Two sequential creates: the nesting invariant only manifests on the second.
# ─────────────────────────────────────────────────────────────────────────────
@test "create: .env.local carried over; no nested .worktrees in worktree (2nd create)" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"

    # First create
    run sh "$WT" create carryover
    [ "$status" -eq 0 ]
    local wt1_dir
    wt1_dir=$(created_worktree_dir "$output" "carryover")
    [ -f "$wt1_dir/.env.local" ]
    [ ! -d "$wt1_dir/.worktrees" ]

    # Second create: must not carry the first worktree into the second
    run sh "$WT" create carryover2
    [ "$status" -eq 0 ]
    local wt2_dir
    wt2_dir=$(created_worktree_dir "$output" "carryover2")

    # .env.local must be present in second worktree
    [ -f "$wt2_dir/.env.local" ]

    # .worktrees/ must NOT be nested inside the second worktree (hard invariant)
    [ ! -d "$wt2_dir/.worktrees" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 5: create duplicate slug → non-zero exit, error mentions --refresh
# ─────────────────────────────────────────────────────────────────────────────
@test "create duplicate slug: non-zero exit, error mentions --refresh" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    sh "$WT" create dupe >/dev/null 2>&1

    run sh "$WT" create dupe
    [ "$status" -ne 0 ]

    # Error output must mention --refresh
    printf '%s\n' "$output" | grep -q -- '--refresh'

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 6: list → output contains created worktree path with [spine]
# ─────────────────────────────────────────────────────────────────────────────
@test "list: output contains created worktree path with [spine]" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    sh "$WT" create listme >/dev/null 2>&1

    run sh "$WT" list
    [ "$status" -eq 0 ]

    # Output must contain the worktree path under .worktrees/ with [spine] label
    printf '%s\n' "$output" | grep -q "$repo/.worktrees/listme-"
    printf '%s\n' "$output" | grep -q '\[spine\]'

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 7: remove of a clean worktree → exit 0, dir gone, branch still exists
# ─────────────────────────────────────────────────────────────────────────────
@test "remove: clean worktree removed; dir gone; branch kept" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    sh "$WT" create torm >/dev/null 2>&1
    local wt_dir
    wt_dir=$(spine_worktree_dir "$repo" "torm")

    # A fresh worktree must be clean per `git status --porcelain`: the .scratch
    # bridge symlink and every carried gitignored artifact must be ignored, or
    # the remove clean-check refuses. Pins the /.scratch anchor having no
    # trailing slash — a trailing slash would not match the bridge symlink.
    run git -C "$wt_dir" status --porcelain
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run sh "$WT" remove "$wt_dir"
    [ "$status" -eq 0 ]

    # Directory must be gone
    [ ! -d "$wt_dir" ]

    # Branch must still exist
    git -C "$repo" show-ref --verify --quiet "refs/heads/torm"

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 8: remove with real uncommitted tracked edit → non-zero exit, dir kept
# ─────────────────────────────────────────────────────────────────────────────
@test "remove: uncommitted tracked edit blocks removal" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    sh "$WT" create dirty >/dev/null 2>&1
    local wt_dir
    wt_dir=$(spine_worktree_dir "$repo" "dirty")

    # Make a real tracked edit inside the worktree
    printf 'change\n' >> "$wt_dir/.keep"

    run sh "$WT" remove "$wt_dir"
    [ "$status" -ne 0 ]

    # Directory must still be present
    [ -d "$wt_dir" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 9: prune → exit 0
# ─────────────────────────────────────────────────────────────────────────────
@test "prune: exits 0" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" prune
    [ "$status" -eq 0 ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 10: Slice 1 tie-in — _project.sh resolves root from inside a script-created worktree
# (mandatory preflight: hook exercised inside a real worktree.sh-created worktree)
# ─────────────────────────────────────────────────────────────────────────────
@test "Slice 1: _project.sh resolves worktree root from inside a script-created worktree" {
    [ -f "$HOOKS_DIR/_project.sh" ] || skip "_project.sh not found at $HOOKS_DIR"

    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    sh "$WT" create hooktest >/dev/null 2>&1
    local wt_dir
    wt_dir=$(spine_worktree_dir "$repo" "hooktest")

    # .git inside the worktree must be a file for the fix to apply
    [ -f "$wt_dir/.git" ] || skip "worktree .git is not a file — unexpected environment"

    # Create a concrete file inside the worktree for _project.sh to walk from
    touch "$wt_dir/probe-file.txt"

    run sh "$HOOKS_DIR/_project.sh" "$wt_dir/probe-file.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "$wt_dir" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 11: create → space-named gitignored dir carried over intact
# (regression guard: git quote-wrap of space paths must be stripped before cp)
# A space in the ignored dir name causes git to wrap it in "..." in --porcelain
# output. Verifies that the quote-unwrap in the carry-over loop resolves correctly.
# ─────────────────────────────────────────────────────────────────────────────
@test "create: space-named gitignored dir carried over intact" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    # Add a space-named gitignored dir with a file inside
    printf 'build output/\n' >> "$repo/.gitignore"
    git -C "$repo" add .gitignore
    git -C "$repo" commit -q -m "ignore build output/"
    mkdir -p "$repo/build output"
    touch "$repo/build output/artifact.bin"

    cd "$repo"
    run sh "$WT" create spacetest
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "spacetest")

    # The space-named dir and its contents must be present in the worktree
    [ -f "$wt_dir/build output/artifact.bin" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 12: create + remove succeed when .scratch/ dir already exists and a
# directory-only ignore rule for .scratch/ is in place (regression for [B]).
# Case D from the A–E probe matrix: check-ignore matches the real .scratch dir
# but not the worktree's .scratch symlink, so the symlink-safe /.scratch anchor
# must be written unconditionally (not skipped by an early-return).
# ─────────────────────────────────────────────────────────────────────────────
@test "remove: succeeds when pre-existing .scratch dir + directory-only ignore rule" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    # Add a directory-only .scratch/ ignore rule (the precondition for case D)
    printf '.scratch/\n' >> "$repo/.gitignore"
    git -C "$repo" add .gitignore
    git -C "$repo" commit -q -m "ignore .scratch/ (dir-only rule)"

    # Pre-create a real .scratch/ directory before the first worktree create
    mkdir -p "$repo/.scratch"

    cd "$repo"
    run sh "$WT" create scratchtest
    [ "$status" -eq 0 ]

    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "scratchtest")

    # The worktree must be clean: the .scratch symlink must be ignored (not ??)
    run git -C "$wt_dir" status --porcelain
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    # remove must succeed (exit 0) — this was the failing case when check-ignore
    # early-returned and the /.scratch anchor was never written
    run sh "$WT" remove "$wt_dir"
    [ "$status" -eq 0 ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 13: sync happy path — worktree branch rebased onto main's new commit
# ─────────────────────────────────────────────────────────────────────────────
@test "sync: happy path — worktree branch rebased onto main's new commit" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create syncfeat
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "syncfeat")

    # Commit a change on the worktree branch (edit a unique file)
    printf 'wt-change\n' > "$wt_dir/wt-file.txt"
    git -C "$wt_dir" add wt-file.txt
    git -C "$wt_dir" commit -q -m "worktree commit"

    # Advance main with a non-conflicting commit (edit a different file)
    printf 'main-change\n' > "$repo/main-file.txt"
    git -C "$repo" add main-file.txt
    git -C "$repo" commit -q -m "main advance commit"
    local main_head
    main_head=$(git -C "$repo" rev-parse HEAD)

    run sh "$WT" sync "$wt_dir"
    [ "$status" -eq 0 ]

    # Worktree branch must now be based on main's new commit
    git -C "$wt_dir" merge-base --is-ancestor "$main_head" HEAD

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 14: sync conflict — exit code 3, error mentions rebase and abort
# ─────────────────────────────────────────────────────────────────────────────
@test "sync: conflict — exit code 3, error mentions rebase and abort" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create syncconflict
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "syncconflict")

    # Edit the same line in the same file on the worktree branch
    printf 'version-wt\n' > "$wt_dir/.keep"
    git -C "$wt_dir" add .keep
    git -C "$wt_dir" commit -q -m "wt edit .keep"

    # Edit the same file differently on main
    printf 'version-main\n' > "$repo/.keep"
    git -C "$repo" add .keep
    git -C "$repo" commit -q -m "main edit .keep"

    run sh "$WT" sync "$wt_dir"
    [ "$status" -eq 3 ]

    # SF5: prove the rebase is left IN PROGRESS (rebase-merge dir must exist)
    [ -d "$(git -C "$wt_dir" rev-parse --path-format=absolute --git-path rebase-merge)" ]

    # SF4 contract: output must contain a worktree-path: line
    printf '%s\n' "$output" | grep -q 'worktree-path:'

    # Abort the in-progress rebase so the worktree is clean for rm -rf
    git -C "$wt_dir" rebase --abort 2>/dev/null || true

    # Error output must mention rebase and abort
    printf '%s\n' "$output" | grep -qi 'rebase'
    printf '%s\n' "$output" | grep -qi 'abort'

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 14b: sync non-conflict rebase failure → exit 1, not 3
# A dirty worktree (uncommitted tracked change) causes git rebase to refuse
# before starting — no rebase-merge dir is created.
# ─────────────────────────────────────────────────────────────────────────────
@test "sync: non-conflict rebase failure exits 1, not 3; no rebase-merge dir" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create syncnonfail
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "syncnonfail")

    # Commit a change on the worktree branch
    printf 'wt-change\n' > "$wt_dir/wt-file.txt"
    git -C "$wt_dir" add wt-file.txt
    git -C "$wt_dir" commit -q -m "worktree commit"

    # Advance main with a non-conflicting commit
    printf 'main-change\n' > "$repo/main-file.txt"
    git -C "$repo" add main-file.txt
    git -C "$repo" commit -q -m "main advance commit"

    # Make the worktree dirty (unstaged tracked change) so rebase refuses to start
    printf 'unstaged-change\n' >> "$wt_dir/wt-file.txt"

    run sh "$WT" sync "$wt_dir"
    [ "$status" -eq 1 ]

    # Must NOT have a rebase-merge dir (no rebase was started)
    rebase_merge_dir=$(git -C "$wt_dir" rev-parse --path-format=absolute --git-path rebase-merge 2>/dev/null) || true
    [ ! -d "$rebase_merge_dir" ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 15: land happy path — main fast-forwarded, worktree dir gone, branch gone
# ─────────────────────────────────────────────────────────────────────────────
@test "land: happy path — main fast-forwarded, worktree dir gone, branch gone" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create landfeat
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "landfeat")

    # Commit a change on the worktree branch
    printf 'land-change\n' > "$wt_dir/land-file.txt"
    git -C "$wt_dir" add land-file.txt
    git -C "$wt_dir" commit -q -m "land feature commit"

    run sh "$WT" land "$wt_dir"
    [ "$status" -eq 0 ]

    # main must include the feature commit
    git -C "$repo" log --oneline | grep -q "land feature commit"

    # Worktree directory must be gone
    [ ! -d "$wt_dir" ]

    # Branch must be gone
    run git -C "$repo" show-ref --verify --quiet "refs/heads/landfeat"
    [ "$status" -ne 0 ]

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 16: land rebase-conflict halt — main unchanged, worktree dir kept, branch kept
# ─────────────────────────────────────────────────────────────────────────────
@test "land: rebase-conflict halt — main unchanged, worktree and branch preserved" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create landhalt
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "landhalt")

    # Edit the same line in the same file on the worktree branch
    printf 'version-wt\n' > "$wt_dir/.keep"
    git -C "$wt_dir" add .keep
    git -C "$wt_dir" commit -q -m "wt edit .keep for land"

    # Edit the same file differently on main — creates a rebase conflict
    printf 'version-main\n' > "$repo/.keep"
    git -C "$repo" add .keep
    git -C "$repo" commit -q -m "main edit .keep for land"
    local main_head
    main_head=$(git -C "$repo" rev-parse HEAD)

    run sh "$WT" land "$wt_dir"
    [ "$status" -eq 3 ]

    # SF5: prove the rebase is left IN PROGRESS (rebase-merge dir must exist)
    [ -d "$(git -C "$wt_dir" rev-parse --path-format=absolute --git-path rebase-merge)" ]

    # SF4 contract: output must contain a worktree-path: line
    printf '%s\n' "$output" | grep -q 'worktree-path:'

    # Abort the in-progress rebase so the worktree is clean for rm -rf
    git -C "$wt_dir" rebase --abort 2>/dev/null || true

    # main HEAD must be unchanged
    [ "$(git -C "$repo" rev-parse HEAD)" = "$main_head" ]

    # Worktree directory must still exist
    [ -d "$wt_dir" ]

    # Branch must still exist
    git -C "$repo" show-ref --verify --quiet "refs/heads/landhalt"

    rm -rf "$repo"
}

# ─────────────────────────────────────────────────────────────────────────────
# Land guard and failure-path coverage
# ─────────────────────────────────────────────────────────────────────────────

# Test 17: land step-3 clean-check failure
# An untracked file added to the worktree after a successful rebase+merge causes
# step 3 to fail. Assert that: exit is 1, message mentions uncommitted changes,
# AND the feature commit was already merged into main (partial-land state).
# Note: merge --ff-only failure (race between rebase and merge) is only reachable
# by injecting between steps — not cleanly testable without process-level hooks.
@test "land: step-3 clean-check failure — exit 1, feature already in main" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create landcleanfail
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "landcleanfail")

    # Commit a change on the worktree branch
    printf 'clean-check-test\n' > "$wt_dir/feat-file.txt"
    git -C "$wt_dir" add feat-file.txt
    git -C "$wt_dir" commit -q -m "feat: clean-check test commit"

    # Plant an untracked file in the worktree BEFORE land runs.
    # After rebase (no-op — no divergence) and ff-merge succeed, step 3's
    # git status --porcelain will see this file and refuse.
    printf 'untracked\n' > "$wt_dir/untracked-file.txt"

    run sh "$WT" land "$wt_dir"
    [ "$status" -eq 1 ]

    # Message must mention uncommitted changes
    printf '%s\n' "$output" | grep -qi 'uncommitted'

    # Message must state main was already merged (partial-land state: step 2 completed before step 3 failed)
    printf '%s\n' "$output" | grep -q 'was merged into'

    # Message must name the manual recovery command (operator must be able to finish manually)
    printf '%s\n' "$output" | grep -q 'worktree remove --force'

    # The feature commit must already be in main (step 2 succeeded before step 3 failed)
    git -C "$repo" log --oneline | grep -q "feat: clean-check test commit"

    rm -rf "$repo"
}

# Test 18: land main-worktree guard — exit 1, message mentions main worktree
@test "land: cannot land the main worktree — exit 1" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" land "$repo"
    [ "$status" -eq 1 ]

    printf '%s\n' "$output" | grep -qi 'cannot land the main worktree'

    run sh "$WT" land "$repo/"
    [ "$status" -eq 1 ]

    printf '%s\n' "$output" | grep -qi 'cannot land the main worktree'

    run sh "$WT" land .
    [ "$status" -eq 1 ]

    printf '%s\n' "$output" | grep -qi 'cannot land the main worktree'

    rm -rf "$repo"
}

# Test 19: land detached-HEAD guard — exit 1, message mentions detached HEAD
@test "land: worktree in detached HEAD — exit 1" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    make_repo "$repo"

    cd "$repo"
    run sh "$WT" create landdetach
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "landdetach")

    # Detach the worktree HEAD
    git -C "$wt_dir" checkout --detach 2>/dev/null

    run sh "$WT" land "$wt_dir"
    [ "$status" -eq 1 ]

    printf '%s\n' "$output" | grep -qi 'detached'

    rm -rf "$repo"
}

# Test 20: hostile global rebase/merge config cannot change conflict shape
@test "sync: hostile global rebase and merge config isolated by repo config" {
    local repo
    repo=$(cd "$(mktemp -d /tmp/spine-test-wt-XXXXXX)" && pwd -P)
    local hostile_config="$repo/hostile.gitconfig"
    write_hostile_git_config "$hostile_config"
    GIT_CONFIG_GLOBAL="$hostile_config" make_repo "$repo"

    cd "$repo"
    run env GIT_CONFIG_GLOBAL="$hostile_config" sh "$WT" create hostileconflict
    [ "$status" -eq 0 ]
    local wt_dir
    wt_dir=$(created_worktree_dir "$output" "hostileconflict")

    printf 'version-wt\n' > "$wt_dir/.keep"
    git -C "$wt_dir" add .keep
    git -C "$wt_dir" commit -q -m "wt edit under hostile config"

    printf 'version-main\n' > "$repo/.keep"
    git -C "$repo" add .keep
    git -C "$repo" commit -q -m "main edit under hostile config"

    run env GIT_CONFIG_GLOBAL="$hostile_config" sh "$WT" sync "$wt_dir"
    [ "$status" -eq 3 ]

    # Repo-local rebase.backend=merge must beat global rebase.backend=apply.
    [ -d "$(git -C "$wt_dir" rev-parse --path-format=absolute --git-path rebase-merge)" ]

    # Repo-local merge.conflictStyle=merge must beat global diff3 markers.
    ! grep -q '^|||||||' "$wt_dir/.keep"

    git -C "$wt_dir" rebase --abort 2>/dev/null || true
    rm -rf "$repo"
}
