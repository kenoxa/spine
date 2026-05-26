#!/usr/bin/env bats
# task-adapter.bats — Behavioral tests for hooks/_task_adapter.sh.

TA="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/_task_adapter.sh"

make_session() {
    local dir="$1"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@spine-test.local"
    git -C "$dir" config user.name "Spine Test"
    touch "$dir/.keep"
    git -C "$dir" add .keep
    git -C "$dir" commit -q -m "init"
    mkdir -p "$dir/.scratch/sess-test-abcd"
}

@test "task-adapter: claude-code detected via CLAUDECODE=1; task.adapter event written" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run env -i PATH="$PATH" CLAUDECODE=1 sh "$TA" "$session" frame design auto
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF "claude-code"

    # Audit event must have been appended
    [ -f "$session/events.jsonl" ]
    jq -e '.type=="task.adapter" and .payload.provider=="claude-code" and .payload.from_phase=="frame" and .payload.to_phase=="design" and .payload.trigger=="auto"' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}

@test "task-adapter: codex detected via CODEX_HOME" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run env -i PATH="$PATH" CODEX_HOME=/fake/codex sh "$TA" "$session" design build auto
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF "codex"
    jq -e '.payload.provider=="codex" and (.payload.action | test("update_plan"))' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}

@test "task-adapter: cursor detected via SPINE_PROVIDER_IS_CURSOR; session-log.md stub appended" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"
    # Pre-seed session-log.md so the cursor branch appends rather than skipping
    printf '# Session log\n' > "$session/session-log.md"

    run env -i PATH="$PATH" SPINE_PROVIDER_IS_CURSOR=1 sh "$TA" "$session" build complete auto
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF "cursor"
    grep -q 'task-adapter cursor stub' "$session/session-log.md"
    grep -q 'build→complete' "$session/session-log.md"

    rm -rf "$repo"
}

@test "task-adapter: opencode detected via OPENCODE_PROJECT_ROOT" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run env -i PATH="$PATH" OPENCODE_PROJECT_ROOT=/fake/oc sh "$TA" "$session" frame design auto
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF "opencode"
    jq -e '.payload.provider=="opencode"' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}

@test "task-adapter: unknown provider when no env signals present (no-op)" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run env -i PATH="$PATH" sh "$TA" "$session" frame design auto
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qxF "unknown"
    jq -e '.payload.provider=="unknown" and .payload.action=="no-op"' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}

@test "task-adapter: halt trigger overrides next-action message" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ta-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run env -i PATH="$PATH" CLAUDECODE=1 sh "$TA" "$session" build complete halt
    [ "$status" -eq 0 ]
    # halt path: action mentions blocked or completed-with-reason
    jq -e '.payload.trigger=="halt" and (.payload.action | test("blocked|reason"))' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}

@test "task-adapter: missing session dir is a fatal error" {
    run env -i PATH="$PATH" CLAUDECODE=1 sh "$TA" /nonexistent/path frame design auto
    [ "$status" -ne 0 ]
    printf '%s\n' "$output" | grep -qi 'session dir not found'
}

@test "task-adapter: missing args produce usage error" {
    run sh "$TA" /tmp
    [ "$status" -eq 2 ]
    printf '%s\n' "$output" | grep -qi 'usage'
}
