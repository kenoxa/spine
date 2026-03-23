#!/bin/sh
# Check Qwen Code CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
if ! command -v qwen >/dev/null 2>&1; then
    error "qwen CLI not found on PATH"
    error "Install: brew install qwen-code"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 qwen --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "qwen CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth — check stored OAuth credentials.
# Unlike claude/codex which have `auth status` subcommands, qwen-code
# stores OAuth credentials as a file. File presence is the best available check.
if [ ! -f "$HOME/.qwen/oauth_creds.json" ]; then
    error "qwen CLI not authenticated (no OAuth credentials found)"
    error "Run: qwen (interactive) to authenticate via OAuth"
    exit 3
fi

# Success
printf '%s\n' "$_version"
