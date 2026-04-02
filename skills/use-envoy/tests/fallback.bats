#!/usr/bin/env bats
# Tests for the envoy fallback system: to_cursor_model mapping, is_fast_failure
# pattern matching, and fallback.sh integration flow.

load test_helper

# =============================================================================
# 1. Unit tests: to_cursor_model mapping
# =============================================================================
# Source _common.sh (for resolve_tier) and the function definitions from
# invoke-cursor.sh. The function sets $_cursor_model (shell variable, not stdout).

# Helper: source just the prefix constant and to_cursor_model function.
_load_cursor_model_fn() {
    . "$SCRIPTS_DIR/_common.sh"
    # Extract _CLAUDE_CURSOR_PREFIX and to_cursor_model from invoke-cursor.sh
    eval "$(sed -n '/^_CLAUDE_CURSOR_PREFIX=/p' "$SCRIPTS_DIR/invoke-cursor.sh")"
    eval "$(sed -n '/^to_cursor_model()/,/^}/p' "$SCRIPTS_DIR/invoke-cursor.sh")"
}

@test "to_cursor_model: opus + high → claude-4.6-opus-high-thinking" {
    _load_cursor_model_fn
    to_cursor_model opus high
    assert_equal "$_cursor_model" "claude-4.6-opus-high-thinking"
}

@test "to_cursor_model: sonnet + high → claude-4.6-sonnet-medium-thinking" {
    _load_cursor_model_fn
    to_cursor_model sonnet high
    assert_equal "$_cursor_model" "claude-4.6-sonnet-medium-thinking"
}

@test "to_cursor_model: haiku + high → auto" {
    _load_cursor_model_fn
    to_cursor_model haiku high
    assert_equal "$_cursor_model" "auto"
}

@test "to_cursor_model: gpt-5.4 + high → gpt-5.4-high" {
    _load_cursor_model_fn
    to_cursor_model gpt-5.4 high
    assert_equal "$_cursor_model" "gpt-5.4-high"
}

@test "to_cursor_model: gpt-5.4 + medium → gpt-5.4-medium" {
    _load_cursor_model_fn
    to_cursor_model gpt-5.4 medium
    assert_equal "$_cursor_model" "gpt-5.4-medium"
}

@test "to_cursor_model: gpt-5.4-mini + high → gpt-5.4-mini-high" {
    _load_cursor_model_fn
    to_cursor_model gpt-5.4-mini high
    assert_equal "$_cursor_model" "gpt-5.4-mini-high"
}

@test "to_cursor_model: gpt-5.4-nano + high → gpt-5.4-nano-high" {
    _load_cursor_model_fn
    to_cursor_model gpt-5.4-nano high
    assert_equal "$_cursor_model" "gpt-5.4-nano-high"
}

@test "to_cursor_model: gpt-5.3-codex + high → gpt-5.3-codex-high (passthrough)" {
    _load_cursor_model_fn
    to_cursor_model gpt-5.3-codex high
    assert_equal "$_cursor_model" "gpt-5.3-codex-high"
}

@test "to_cursor_model: unknown model returns 1" {
    _load_cursor_model_fn
    run to_cursor_model unknown-model high
    assert_failure
}

# =============================================================================
# 2. Unit tests: is_fast_failure pattern matching
# =============================================================================

# --- Patterns that SHOULD match (fast-failure) ---

@test "is_fast_failure: rate limit detected" {
    echo "Error: rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: rate-limit with hyphen detected" {
    echo "Error: rate-limit reached for this model" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: rate_limited with underscore detected" {
    echo "rate_limited: please wait" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: hit a rate limit detected" {
    echo "You hit a rate limit, slow down" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: out of usage detected" {
    echo "Error: out of usage for this billing period" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: credits exhausted detected" {
    echo "Your credits are exhausted" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: not authenticated detected" {
    echo "Error: not authenticated" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: not logged in detected" {
    echo "not logged in, please authenticate" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: authorization error detected" {
    echo "authorization error: invalid token" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: cannot use this model detected" {
    echo 'Cannot use this model: "gpt-5.3-codex-high". Available models: ...' > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: too many requests detected" {
    echo "429 Too Many Requests" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: overloaded detected" {
    echo "Service is overloaded, try again later" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: quota exceeded detected" {
    echo "Error: quota exceeded for this model" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: usage limit detected" {
    echo "Error: usage limit reached" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: credit balance detected" {
    echo "Insufficient credit balance" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: payment past due detected" {
    echo "Error: payment is past due" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: account disabled detected" {
    echo "Your account has been disabled" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

@test "is_fast_failure: increase limit detected" {
    echo "Please increase your limit to continue" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    is_fast_failure "$BATS_TMPDIR/stderr.log"
}

# --- Patterns that should NOT match ---

@test "is_fast_failure: connection refused not detected" {
    echo "Error: connection refused" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/stderr.log"
    assert_failure
}

@test "is_fast_failure: timeout not detected" {
    echo "Error: connection timed out" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/stderr.log"
    assert_failure
}

@test "is_fast_failure: internal server error not detected" {
    echo "500 Internal Server Error" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/stderr.log"
    assert_failure
}

@test "is_fast_failure: generic failure not detected" {
    echo "Error: something went wrong" > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/stderr.log"
    assert_failure
}

@test "is_fast_failure: missing file returns 1" {
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/nonexistent-file.log"
    assert_failure
}

@test "is_fast_failure: empty file returns 1" {
    : > "$BATS_TMPDIR/stderr.log"
    . "$SCRIPTS_DIR/_common.sh"
    run is_fast_failure "$BATS_TMPDIR/stderr.log"
    assert_failure
}

# =============================================================================
# 3. Integration tests: fallback.sh flow
# =============================================================================
# Uses a temp scripts directory with real _common.sh + fallback.sh, and stubs
# for check-cursor.sh and invoke-cursor.sh. This isolates the fallback logic
# from real CLI dependencies.

@test "fallback.sh: fast-failure triggers cursor-agent fallback" {
    setup_fallback_scripts 0 0
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier standard --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success

    # Verify invoke-cursor.sh was called with expected arguments
    assert [ -f "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args" ]
    run cat "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args"
    assert_output --partial "--prompt-file"
    assert_output --partial "--tier"
    assert_output --partial "standard"
    assert_output --partial "--fallback-for"
    assert_output --partial "claude"

    teardown_fallback_scripts
}

@test "fallback.sh: non-fast-failure propagates original exit code" {
    setup_fallback_scripts 0 0
    echo "Error: connection refused" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier standard --exit-code 42 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_failure 42

    # Verify invoke-cursor.sh was NOT called
    assert [ ! -f "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args" ]

    teardown_fallback_scripts
}

@test "fallback.sh: cursor unavailable propagates original exit code" {
    setup_fallback_scripts 1 0  # check-cursor.sh fails
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider codex --tier frontier --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_failure 1

    # Verify invoke-cursor.sh was NOT called (cursor unavailable)
    assert [ ! -f "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args" ]

    teardown_fallback_scripts
}

@test "fallback.sh: passes correct tier through to invoke-cursor.sh" {
    setup_fallback_scripts 0 0
    echo "out of usage" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider codex --tier frontier --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success

    # Verify frontier tier passed through
    run cat "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args"
    assert_output --partial "--tier"
    assert_output --partial "frontier"
    assert_output --partial "--fallback-for"
    assert_output --partial "codex"

    teardown_fallback_scripts
}

@test "fallback.sh: passes model and effort through to invoke-cursor.sh" {
    setup_fallback_scripts 0 0
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier frontier --exit-code 1 \
        --model opus --effort high \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success

    # Verify model and effort passed through
    run cat "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args"
    assert_output --partial "--model"
    assert_output --partial "opus"
    assert_output --partial "--effort"
    assert_output --partial "high"
    assert_output --partial "--fallback-for"
    assert_output --partial "claude"

    teardown_fallback_scripts
}

@test "fallback.sh: works without model/effort (backward compat)" {
    setup_fallback_scripts 0 0
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    # No --model or --effort
    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider codex --tier standard --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success

    # invoke-cursor.sh still called (will derive model from resolve_tier)
    assert [ -f "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args" ]
    run cat "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args"
    # --model should NOT appear when not provided
    refute_output --partial "--model"

    teardown_fallback_scripts
}

@test "fallback.sh: missing required args fails with error" {
    setup_fallback_scripts 0 0

    # Missing --provider
    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --tier standard --exit-code 1 \
        --prompt-file /dev/null --output-file /dev/null \
        --stderr-log /dev/null
    assert_failure
    assert_output --partial "Missing --provider"

    teardown_fallback_scripts
}

@test "fallback.sh: unknown arg fails with error" {
    setup_fallback_scripts 0 0

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" --bogus-arg value
    assert_failure
    assert_output --partial "Unknown fallback.sh argument"

    teardown_fallback_scripts
}

@test "fallback.sh: auth error triggers cursor-agent fallback" {
    setup_fallback_scripts 0 0
    echo "not authenticated" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier fast --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success

    assert [ -f "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args" ]
    run cat "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh.args"
    assert_output --partial "--tier"
    assert_output --partial "fast"

    teardown_fallback_scripts
}

@test "fallback.sh: invoke-cursor.sh failure propagates its exit code" {
    setup_fallback_scripts 0 3  # invoke-cursor.sh exits 3
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier standard --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"

    # fallback.sh exec's into invoke-cursor.sh, so its exit code propagates
    assert_failure 3

    teardown_fallback_scripts
}

@test "fallback.sh: debug mode emits diagnostic messages" {
    setup_fallback_scripts 0 0
    echo "rate limit exceeded" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    SPINE_ENVOY_DEBUG=1 run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider claude --tier standard --exit-code 1 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_success
    assert_output --partial "fast-failure detected"
}

@test "fallback.sh: debug mode on non-fast-failure shows propagation message" {
    setup_fallback_scripts 0 0
    echo "Error: something generic" > "$BATS_TMPDIR/stderr.log"
    printf 'test prompt' > "$BATS_TMPDIR/prompt.txt"

    SPINE_ENVOY_DEBUG=1 run sh "$FALLBACK_SCRIPTS_DIR/fallback.sh" \
        --provider codex --tier standard --exit-code 5 \
        --prompt-file "$BATS_TMPDIR/prompt.txt" \
        --output-file "$BATS_TMPDIR/output.txt" \
        --stderr-log "$BATS_TMPDIR/stderr.log"
    assert_failure 5
    assert_output --partial "no fast-failure pattern"
    assert_output --partial "propagating exit 5"
}
