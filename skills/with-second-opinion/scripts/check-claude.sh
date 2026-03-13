#!/bin/sh
# Check Claude Code CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
if ! command -v claude >/dev/null 2>&1; then
    error "claude CLI not found on PATH"
    error "Install: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 claude --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "claude CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth — check stored authentication via claude auth status
# Codex sandbox (Seatbelt) blocks macOS Keychain access needed for OAuth auth.
# Detect sandbox and give actionable guidance before attempting auth check.
if [ "${CODEX_SANDBOX:-}" = "seatbelt" ]; then
    error "claude auth requires macOS Keychain access, blocked by Codex Seatbelt sandbox"
    error ""
    error "Fix: set sandbox_mode = \"danger-full-access\" in ~/.codex/config.toml"
    error "  or restart Codex with: codex -s danger-full-access"
    error ""
    error "See: https://github.com/kenoxa/spine#codex-cross-provider-setup"
    exit 3
fi

_auth=$(timeout 10 claude auth status 2>/dev/null) || true
if ! printf '%s' "$_auth" | grep -q '"loggedIn".*true'; then
    error "claude CLI not authenticated"
    error "Run: claude login"
    exit 3
fi

# Success
printf '%s\n' "$_version"
