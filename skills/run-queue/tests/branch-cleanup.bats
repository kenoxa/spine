#!/usr/bin/env bats
# Acceptance tests for branch_cleanup feature.
# Corresponds to .scratch/deferred-handoffs/branch-auto-cleanup.md

load test_helper

# ---------------------------------------------------------------------------
# Test 1: branch_cleanup: after_success, all tasks merge → no branches remain
# ---------------------------------------------------------------------------
@test "after_success deletes all merged task branches and integration branch" {
    setup_repo "run-1"
    create_task_branch "run-1" "task-a" merged
    create_task_branch "run-1" "task-b" merged

    local state
    state='{"tasks":[
        {"id":"task-a","status":"merged","branch":"queue/run-1/task-a"},
        {"id":"task-b","status":"merged","branch":"queue/run-1/task-b"}
    ]}'

    git checkout -q "$MAIN_BRANCH"
    _run_branch_cleanup "after_success" "$state" "$INTEGRATION_BRANCH"

    assert_branch_missing "queue/run-1/task-a"
    assert_branch_missing "queue/run-1/task-b"
    assert_branch_missing "$INTEGRATION_BRANCH"
}

# ---------------------------------------------------------------------------
# Test 2: branch_cleanup: never → all branches remain
# ---------------------------------------------------------------------------
@test "never preserves all task branches and integration branch" {
    setup_repo "run-2"
    create_task_branch "run-2" "task-a" merged
    create_task_branch "run-2" "task-b" merged

    local state
    state='{"tasks":[
        {"id":"task-a","status":"merged","branch":"queue/run-2/task-a"},
        {"id":"task-b","status":"merged","branch":"queue/run-2/task-b"}
    ]}'

    git checkout -q "$MAIN_BRANCH"
    _run_branch_cleanup "never" "$state" "$INTEGRATION_BRANCH"

    assert_branch_exists "queue/run-2/task-a"
    assert_branch_exists "queue/run-2/task-b"
    assert_branch_exists "$INTEGRATION_BRANCH"
}

# ---------------------------------------------------------------------------
# Test 3: branch_cleanup: after_success, one blocked → blocked retained, merged deleted
# ---------------------------------------------------------------------------
@test "after_success deletes merged branches but retains blocked branches" {
    setup_repo "run-3"
    create_task_branch "run-3" "task-a" merged
    create_task_branch "run-3" "task-b"        # blocked — not merged

    local state
    state='{"tasks":[
        {"id":"task-a","status":"merged","branch":"queue/run-3/task-a"},
        {"id":"task-b","status":"blocked","branch":"queue/run-3/task-b"}
    ]}'

    git checkout -q "$MAIN_BRANCH"
    _run_branch_cleanup "after_success" "$state" "$INTEGRATION_BRANCH"

    assert_branch_missing "queue/run-3/task-a"
    assert_branch_exists "queue/run-3/task-b"
}
