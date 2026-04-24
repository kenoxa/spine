# Shared BATS helpers for Envoy provider script tests.
# Load bats-support and bats-assert from Homebrew.

BATS_LIB="${TEST_BREW_PREFIX:-$(brew --prefix 2>/dev/null)}/lib"
[[ -d "$BATS_LIB/bats-support" ]] || { echo "BATS: bats-support not found — brew install bats-support bats-assert" >&2; exit 1; }

load "$BATS_LIB/bats-support/load.bash"
load "$BATS_LIB/bats-assert/load.bash"

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")"/scripts && pwd)"
# _script_dir must be set before sourcing _common.sh because _common.sh sources
# _rate_limit.sh via ". $_script_dir/_rate_limit.sh". Unit tests that source
# _common.sh directly inherit this var from the bats shell.
export _script_dir="$SCRIPTS_DIR"

# --- Stub CLI helpers ---

# Set up a fresh stubs directory on PATH.
# Call in setup() or at the start of a test.
setup_stubs() {
    STUBS_DIR="$BATS_TMPDIR/stubs-$$"
    mkdir -p "$STUBS_DIR"
    export PATH="$STUBS_DIR:$PATH"
}

# Remove the stubs directory.
# Call in teardown() or at the end of a test.
teardown_stubs() {
    [ -d "${STUBS_DIR:-}" ] && rm -rf "$STUBS_DIR"
}

# Create a stub CLI script in $STUBS_DIR.
# Usage: create_stub <name> <exit_code> [stderr_content]
# The stub logs its invocation arguments to $STUBS_DIR/<name>.args (one arg per line)
# and writes stderr_content to stderr before exiting.
create_stub() {
    local name="$1" exit_code="$2" stderr_content="${3:-}"
    local stub_path="$STUBS_DIR/$name"
    cat > "$stub_path" <<STUBEOF
#!/bin/sh
# Stub for $name — logs args, writes stderr, exits $exit_code
printf '%s\n' "\$@" > "$STUBS_DIR/${name}.args"
STUBEOF
    if [ -n "$stderr_content" ]; then
        cat >> "$stub_path" <<STUBEOF
printf '%s\n' '$stderr_content' >&2
STUBEOF
    fi
    cat >> "$stub_path" <<STUBEOF
exit $exit_code
STUBEOF
    chmod +x "$stub_path"
}

# Create a stub shell script (not on PATH — placed at an arbitrary path).
# Usage: create_script_stub <path> <exit_code> [stderr_content]
create_script_stub() {
    local script_path="$1" exit_code="$2" stderr_content="${3:-}"
    cat > "$script_path" <<STUBEOF
#!/bin/sh
printf '%s\n' "\$@" > "${script_path}.args"
STUBEOF
    if [ -n "$stderr_content" ]; then
        cat >> "$script_path" <<STUBEOF
printf '%s\n' '$stderr_content' >&2
STUBEOF
    fi
    cat >> "$script_path" <<STUBEOF
exit $exit_code
STUBEOF
    chmod +x "$script_path"
}

# Build a temporary scripts directory for fallback.sh integration tests.
# Copies _common.sh and fallback.sh from the real scripts dir, and creates
# stubs for check-cursor.sh and invoke-cursor.sh.
# Sets FALLBACK_SCRIPTS_DIR to the temp path.
# Usage: setup_fallback_scripts [check_cursor_exit] [invoke_cursor_exit]
setup_fallback_scripts() {
    local check_exit="${1:-0}" invoke_exit="${2:-0}"
    FALLBACK_SCRIPTS_DIR="$BATS_TMPDIR/fallback-scripts-$$"
    mkdir -p "$FALLBACK_SCRIPTS_DIR"
    cp "$SCRIPTS_DIR/_common.sh" "$FALLBACK_SCRIPTS_DIR/"
    cp "$SCRIPTS_DIR/_rate_limit.sh" "$FALLBACK_SCRIPTS_DIR/"
    cp "$SCRIPTS_DIR/fallback.sh" "$FALLBACK_SCRIPTS_DIR/"

    # Stub check-cursor.sh
    create_script_stub "$FALLBACK_SCRIPTS_DIR/check-cursor.sh" "$check_exit"

    # Stub invoke-cursor.sh — logs args and succeeds (or fails per invoke_exit)
    create_script_stub "$FALLBACK_SCRIPTS_DIR/invoke-cursor.sh" "$invoke_exit"
}

teardown_fallback_scripts() {
    [ -d "${FALLBACK_SCRIPTS_DIR:-}" ] && rm -rf "$FALLBACK_SCRIPTS_DIR"
}
