#!/usr/bin/env bats
# terminal-gate.bats — Behavioral tests for run-curate's terminal-gate driver.

TG="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/terminal-gate.sh"

make_session() {
    local dir="$1"
    git -C "$dir" init -q
    git -C "$dir" config user.email "t@t.t"
    git -C "$dir" config user.name "t"
    touch "$dir/.keep"
    git -C "$dir" add .keep
    git -C "$dir" commit -q -m i
    mkdir -p "$dir/.scratch/sess-curate-abcd"
}

@test "terminal-gate: minimal session — writes report skeleton with required sections" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-tg-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-curate-abcd"

    run sh "$TG" "$session"
    [ "$status" -eq 0 ]
    [ "$output" = "$session/curate-report.md" ]

    [ -f "$session/curate-report.md" ]
    grep -q '# Curate Report' "$session/curate-report.md"
    grep -q '## Source artifacts' "$session/curate-report.md"
    grep -q '## Decisions captured' "$session/curate-report.md"
    grep -q '## Knowledge candidates' "$session/curate-report.md"
    grep -q '## Mainthread synthesis slot' "$session/curate-report.md"
    grep -q 'sess-curate-abcd' "$session/curate-report.md"

    rm -rf "$repo"
}

@test "terminal-gate: present artifacts marked (present, N bytes); missing marked MISSING" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-tg-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-curate-abcd"

    printf '# Frame artifact\n' > "$session/frame-artifact.md"

    run sh "$TG" "$session"
    [ "$status" -eq 0 ]

    grep -q 'Frame artifact.*present' "$session/curate-report.md"
    grep -q 'Design artifact.*MISSING' "$session/curate-report.md"

    rm -rf "$repo"
}

@test "terminal-gate: decisions extracted from Phase Trace markdown table" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-tg-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-curate-abcd"

    cat > "$session/session-log.md" <<'EOF'
# Log
## Phase Trace
| Phase | Mode | Decision | Notes |
|-------|------|----------|-------|
| Classify | zero-dispatch | intent=interrogate | direct mode |
| Build init | zero-dispatch | branch=main, clean tree | no-op |
EOF

    run sh "$TG" "$session"
    [ "$status" -eq 0 ]

    grep -qF '**Classify** (zero-dispatch) — intent=interrogate' "$session/curate-report.md"
    grep -qF '**Build init** (zero-dispatch) — branch=main, clean tree' "$session/curate-report.md"

    rm -rf "$repo"
}

@test "terminal-gate: surfaces knowledge_candidate markers from artifacts" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-tg-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-curate-abcd"

    cat > "$session/frame-artifact.md" <<'EOF'
# Frame
- something: knowledge_candidate: yes — worth promoting later
EOF

    run sh "$TG" "$session"
    [ "$status" -eq 0 ]

    grep -q 'found in.*frame-artifact.md' "$session/curate-report.md"
    grep -q 'knowledge_candidate: yes' "$session/curate-report.md"

    rm -rf "$repo"
}

@test "terminal-gate: missing session dir is a fatal error" {
    run sh "$TG" /nonexistent/session/path
    [ "$status" -ne 0 ]
    printf '%s\n' "$output" | grep -qi 'session dir not found'
}

@test "terminal-gate: missing arg produces usage error" {
    run sh "$TG"
    [ "$status" -eq 2 ]
    printf '%s\n' "$output" | grep -qi 'usage'
}

@test "terminal-gate: does NOT touch source artifacts (read-only)" {
    local repo session
    repo=$(cd "$(mktemp -d /tmp/spine-test-tg-XXXXXX)" && pwd -P)
    make_session "$repo"
    session="$repo/.scratch/sess-curate-abcd"

    printf 'original frame\n' > "$session/frame-artifact.md"
    local before
    before=$(shasum "$session/frame-artifact.md" | awk '{print $1}')

    run sh "$TG" "$session"
    [ "$status" -eq 0 ]

    local after
    after=$(shasum "$session/frame-artifact.md" | awk '{print $1}')
    [ "$before" = "$after" ]

    rm -rf "$repo"
}
