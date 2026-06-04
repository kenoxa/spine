#!/usr/bin/env bats
# resolve-scope.bats — Behavioral tests for resolve-scope.sh.
# Self-contained: no test_helper. Each test runs in an isolated mktemp repo with
# two commits pinned to fixed past dates (A=2020-01-01, B=2020-06-01, HEAD=B) so
# resolution is deterministic regardless of wall-clock time.

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/resolve-scope.sh"

setup() {
    REPO="$(mktemp -d)"
    git -C "$REPO" init -q
    git -C "$REPO" config user.email "test@spine-test.local"
    git -C "$REPO" config user.name "Spine Test"
    : > "$REPO/a.txt"
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" \
        git -C "$REPO" commit -q -m "A"
    A_SHA="$(git -C "$REPO" rev-parse HEAD)"
    : > "$REPO/b.txt"
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="2020-06-01T00:00:00" GIT_COMMITTER_DATE="2020-06-01T00:00:00" \
        git -C "$REPO" commit -q -m "B"
    B_SHA="$(git -C "$REPO" rev-parse HEAD)"
    cd "$REPO"
}

teardown() {
    rm -rf "$REPO"
}

@test "--since with a valid ref prints the ref verbatim" {
    run sh "$SCRIPT" --since "$A_SHA"
    [ "$status" -eq 0 ]
    [ "$output" = "$A_SHA" ]
}

@test "--since with an unknown ref halts (exit 3)" {
    run sh "$SCRIPT" --since deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
    [ "$status" -eq 3 ]
}

@test "--since with no value is a usage error (exit 2)" {
    run sh "$SCRIPT" --since
    [ "$status" -eq 2 ]
}

@test "--days 0 resolves to HEAD (newest commit before now)" {
    run sh "$SCRIPT" --days 0
    [ "$status" -eq 0 ]
    [ "$output" = "$B_SHA" ]
}

@test "--days older than every commit is UNSCOPED" {
    # 10000 days ago (~1999) predates both pinned commits (2020) yet stays inside
    # git approxidate's parseable range (after the Unix epoch), so the window is
    # genuinely empty rather than silently unfiltered.
    run sh "$SCRIPT" --days 10000
    [ "$status" -eq 0 ]
    [ "$output" = "UNSCOPED" ]
}

@test "--days reaching before the Unix epoch is UNSCOPED, not HEAD" {
    # ~82 years: the window starts before 1970, where git approxidate silently
    # drops the filter and would otherwise return HEAD (an inverted full-repo
    # scope). The epoch guard must resolve it fail-secure to UNSCOPED.
    run sh "$SCRIPT" --days 30000
    [ "$status" -eq 0 ]
    [ "$output" = "UNSCOPED" ]
}

@test "--days with a non-integer is a usage error (exit 2)" {
    run sh "$SCRIPT" --days abc
    [ "$status" -eq 2 ]
}

@test "--all-open is UNSCOPED" {
    run sh "$SCRIPT" --all-open
    [ "$status" -eq 0 ]
    [ "$output" = "UNSCOPED" ]
}

@test "--last-run with a report resolves to the commit before its mtime" {
    mkdir -p .clawpatch/reports
    : > .clawpatch/reports/report.md
    # mtime 2020-03-01 — between commit A (Jan) and commit B (Jun) → before = A
    touch -t 202003010000 .clawpatch/reports/report.md
    run sh "$SCRIPT" --last-run
    [ "$status" -eq 0 ]
    [ "$output" = "$A_SHA" ]
}

@test "--last-run with no reports is UNSCOPED" {
    run sh "$SCRIPT" --last-run
    [ "$status" -eq 0 ]
    [ "$output" = "UNSCOPED" ]
}

@test "no selector defaults to --last-run (UNSCOPED with no reports)" {
    run sh "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$output" = "UNSCOPED" ]
}

@test "precedence: --since wins over --days" {
    run sh "$SCRIPT" --since "$B_SHA" --days 5
    [ "$status" -eq 0 ]
    [ "$output" = "$B_SHA" ]
}

@test "unrelated knobs are ignored" {
    run sh "$SCRIPT" --since "$A_SHA" --jobs 3 --include-dirty
    [ "$status" -eq 0 ]
    [ "$output" = "$A_SHA" ]
}
