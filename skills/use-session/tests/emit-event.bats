#!/usr/bin/env bats
# emit-event.bats — Behavioral tests for emit-event.sh.
# Self-contained: each test runs in an isolated mktemp session dir.

EE="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/emit-event.sh"

# make_session <dir> — initialise an empty session directory inside a fresh git repo.
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

@test "emit-event: first event lands with seq=1 and required fields" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ee-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run sh "$EE" "$session" phase.boundary '{"from_phase":null,"to_phase":"frame","artifact_path":".scratch/sess-test-abcd/frame-artifact.md","trigger":"auto"}'
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -q 'seq=1 type=phase.boundary'

    [ -f "$session/events.jsonl" ]
    local line
    line=$(head -1 "$session/events.jsonl")
    printf '%s\n' "$line" | jq -e '.schema_version==1 and .session_id=="sess-test-abcd" and .seq==1 and .type=="phase.boundary"' >/dev/null
    printf '%s\n' "$line" | jq -e '.actor.id and .actor.role and .branch and .worktree_path and .ts' >/dev/null
    printf '%s\n' "$line" | jq -e '.payload.from_phase==null and .payload.to_phase=="frame" and .payload.trigger=="auto"' >/dev/null

    rm -rf "$repo"
}

@test "emit-event: monotonic seq across multiple appends" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ee-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    sh "$EE" "$session" session.start '{"mode":"goal"}' >/dev/null
    sh "$EE" "$session" phase.boundary '{"from_phase":"frame","to_phase":"design","artifact_path":"a.md","trigger":"auto"}' >/dev/null
    sh "$EE" "$session" phase.boundary '{"from_phase":"design","to_phase":"build","artifact_path":"b.md","trigger":"auto"}' >/dev/null

    [ "$(wc -l < "$session/events.jsonl" | tr -d ' ')" = "3" ]
    # Seq must be 1,2,3 in order
    local seqs
    seqs=$(jq -s 'map(.seq)' "$session/events.jsonl")
    [ "$seqs" = "[
  1,
  2,
  3
]" ]

    rm -rf "$repo"
}

@test "emit-event: refuses non-JSON payload" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ee-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    run sh "$EE" "$session" phase.boundary 'not json'
    [ "$status" -ne 0 ]
    printf '%s\n' "$output" | grep -qi 'not valid json'
    [ ! -f "$session/events.jsonl" ]

    rm -rf "$repo"
}

@test "emit-event: SPINE_ACTOR_ID overrides default actor.id" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ee-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    SPINE_ACTOR_ID="claude-main-xyz" SPINE_ACTOR_ROLE="writer" \
        sh "$EE" "$session" phase.boundary '{"from_phase":"build","to_phase":"complete","artifact_path":"s.json","trigger":"auto"}' >/dev/null

    local actor
    actor=$(jq -r '.actor.id' "$session/events.jsonl")
    [ "$actor" = "claude-main-xyz" ]

    rm -rf "$repo"
}

@test "emit-event: missing session-dir is a fatal error" {
    run sh "$EE" /nonexistent/session/path phase.boundary '{}'
    [ "$status" -ne 0 ]
    printf '%s\n' "$output" | grep -qi 'session dir not found'
}

@test "emit-event: terminal phase.boundary carries trigger=halt and reason" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-ee-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-test-abcd"

    sh "$EE" "$session" phase.boundary '{"from_phase":"build","to_phase":"complete","artifact_path":"s.json","trigger":"halt","reason":"review-cap"}' >/dev/null

    jq -e '.payload.trigger=="halt" and .payload.reason=="review-cap"' "$session/events.jsonl" >/dev/null

    rm -rf "$repo"
}
