#!/bin/sh
# Check cursor-agent CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
_binary=""
if command -v cursor-agent >/dev/null 2>&1; then
    _binary=cursor-agent
elif command -v agent >/dev/null 2>&1; then
    _binary=agent
else
    error "cursor-agent CLI not found on PATH"
    error "Install: https://docs.cursor.com/agent"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 "$_binary" --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "$_binary CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth — check stored authentication via cursor-agent status
# Codex sandbox (Seatbelt) blocks macOS Keychain access needed for browser-based auth.
# Detect sandbox and give actionable guidance before attempting auth check.
if [ "${CODEX_SANDBOX:-}" = "seatbelt" ]; then
    error "cursor-agent auth requires macOS Keychain access, blocked by Codex Seatbelt sandbox"
    error ""
    error "Fix: set sandbox_mode = \"danger-full-access\" in ~/.codex/config.toml"
    error "  or restart Codex with: codex -s danger-full-access"
    error ""
    error "See: https://github.com/kenoxa/spine#codex-cross-provider-setup"
    exit 3
fi

_status=$(timeout 10 "$_binary" status 2>/dev/null) || true
if [ -z "$_status" ]; then
    error "$_binary CLI not authenticated"
    error "Run: cursor-agent login (or authenticate via Cursor app)"
    exit 3
fi

# Success
printf '%s\n' "$_version"
