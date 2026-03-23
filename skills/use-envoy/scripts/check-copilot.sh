#!/bin/sh
# Check Copilot CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
if ! command -v copilot >/dev/null 2>&1; then
    error "copilot CLI not found on PATH"
    error "Install: brew install copilot-cli && copilot login"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 copilot --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "copilot CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth — check logged_in_users in copilot config.
# This validates OAuth login, not Copilot Pro+ entitlement.
# Free-tier users pass this check but fail at invocation — acceptable,
# since fallback.sh handles invocation failures.
_config="$HOME/.copilot/config.json"
if [ -f "$_config" ] && command -v jq >/dev/null 2>&1; then
    _users=$(jq -r '.logged_in_users | length // 0' "$_config" 2>/dev/null) || true
    if [ "${_users:-0}" -eq 0 ]; then
        error "copilot CLI not authenticated (no logged_in_users)"
        error "Run: copilot login"
        exit 3
    fi
elif [ ! -f "$_config" ]; then
    error "copilot CLI not configured (~/.copilot/config.json missing)"
    error "Run: copilot login"
    exit 3
fi

# Success
printf '%s\n' "$_version"
