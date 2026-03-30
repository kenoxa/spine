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

# Phase 3: Auth — check that at least one provider is authenticated.
# `opencode models` only lists models for authenticated providers.
# If no models appear, no providers are configured.
_models=$(timeout 10 opencode models 2>/dev/null) || true
if [ -z "$_models" ]; then
    error "opencode has no authenticated providers (no models available)"
    error "Run: opencode providers login"
    exit 3
fi

# Success
printf '%s\n' "$_version"
