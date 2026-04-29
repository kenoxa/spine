# Shared BATS helpers for run-queue supervisor tests.
# Load bats-support and bats-assert from Homebrew.

BATS_LIB="${TEST_BREW_PREFIX:-$(brew --prefix 2>/dev/null)}/lib"
[[ -d "$BATS_LIB/bats-support" ]] || { echo "BATS: bats-support not found — brew install bats-support bats-assert" >&2; exit 1; }

load "$BATS_LIB/bats-support/load.bash"
load "$BATS_LIB/bats-assert/load.bash"

RUN_QUEUE_SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")"/scripts && pwd)"

# Replicates run.sh:_int_branch_cleanup logic for isolated testing.
# Usage: _run_branch_cleanup <mode> <state_json> <integration_branch>
_run_branch_cleanup() {
    local _mode="$1"
    local _state_json="$2"
    local _integration_branch="$3"

    [ "$_mode" = "after_success" ] || return 0

    local _merged
    _merged=$(printf '%s' "$_state_json" | jq -r '.tasks[] | select(.status == "merged") | .branch // empty')
    while IFS= read -r _branch; do
        [ -z "$_branch" ] && continue
        if git show-ref --quiet --verify "refs/heads/$_branch"; then
            git branch -D "$_branch" 2>/dev/null || true
        fi
    done <<EOF
$_merged
EOF

    if git show-ref --quiet --verify "refs/heads/$_integration_branch"; then
        git branch -D "$_integration_branch" 2>/dev/null || true
    fi
}

# Create a temp git repo with a main branch and optional integration branch.
# Sets REPO_DIR, MAIN_BRANCH, INTEGRATION_BRANCH.
# Usage: setup_repo <run_id>
setup_repo() {
    local run_id="$1"
    REPO_DIR="$BATS_TMPDIR/repo-$$-$run_id"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    echo "init" > file && git add file && git commit -qm init
    MAIN_BRANCH=$(git branch --show-current)
    INTEGRATION_BRANCH="queue/$run_id/result"
    git checkout -q -b "$INTEGRATION_BRANCH"
    git checkout -q "$MAIN_BRANCH"
}

# Create a task branch with a commit and optionally merge it into integration.
# Usage: create_task_branch <run_id> <task_id> [merged]
create_task_branch() {
    local run_id="$1"
    local task_id="$2"
    local merged="${3:-}"
    local branch="queue/$run_id/$task_id"

    git checkout -q -b "$branch"
    echo "$task_id" > "${task_id}.txt"
    git add "${task_id}.txt"
    git commit -qm "$task_id"
    git checkout -q "$MAIN_BRANCH"

    if [ "$merged" = "merged" ]; then
        git checkout -q "$INTEGRATION_BRANCH"
        git merge -q --no-ff -m "merge $task_id" "$branch"
        git checkout -q "$MAIN_BRANCH"
    fi
}

# Assert a branch exists.
assert_branch_exists() {
    local branch="$1"
    git show-ref --quiet --verify "refs/heads/$branch"
}

# Assert a branch does not exist.
assert_branch_missing() {
    local branch="$1"
    ! git show-ref --quiet --verify "refs/heads/$branch"
}
