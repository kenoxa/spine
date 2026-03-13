#!/bin/sh
# Check Codex CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
if ! command -v codex >/dev/null 2>&1; then
    error "codex CLI not found on PATH"
    error "Install: brew install codex && codex login"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 codex --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "codex CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth — check stored login status
_login=$(timeout 10 codex login status 2>&1) || true
if ! printf '%s' "$_login" | grep -qi 'logged in'; then
    error "codex CLI not authenticated"
    error "Run: codex login"
    exit 3
fi

# Success
printf '%s\n' "$_version"
