#!/bin/sh
# Check OpenCode CLI availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

# Phase 1: Binary
if ! command -v opencode >/dev/null 2>&1; then
    error "opencode CLI not found on PATH"
    error "Install: brew install anomalyco/tap/opencode"
    exit 1
fi

# Phase 2: Responsive (10s timeout via coreutils)
_version=$(timeout 10 opencode --version 2>/dev/null) || true
if [ -z "$_version" ]; then
    error "opencode CLI unresponsive (--version timed out after 10s)"
    exit 2
fi

# Phase 3: Auth + tier detection.
# Check Go subscription first (opencode-go models), then fall back to free-tier.
_go_models=$(timeout 10 opencode models opencode-go 2>/dev/null) || true
if [ -n "$_go_models" ]; then
    printf '%s\nopencode-tier:go\n' "$_version"
    exit 0
fi

# No Go subscription — check for free-tier models
_free_models=$(timeout 10 opencode models opencode 2>/dev/null | grep '\-free') || true
if [ -n "$_free_models" ]; then
    printf '%s\nopencode-tier:free\n' "$_version"
    exit 0
fi

# Neither Go nor free models available
error "opencode has no Go subscription and no free models available"
error "Run: opencode providers login"
exit 3
