#!/bin/sh
# Check Gemini availability via Copilot CLI.
# Gemini is a pseudo-provider: uses Copilot CLI to access Google Gemini models.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated/model unavailable

set -eu

error() { printf 'Error: %s\n' "$*" >&2; }

_script_dir=$(cd "$(dirname "$0")" && pwd)

# Phase 1-3: Copilot must be available and authenticated
if ! sh "$_script_dir/check-copilot.sh" >/dev/null 2>&1; then
    error "Copilot CLI not available (required for Gemini pseudo-provider)"
    exit 1
fi

# Phase 4: Verify Gemini model is accessible in user's Copilot plan.
# This is a local check (CLI validates model name before any API call).
_probe_out=$(timeout 10 copilot --model gemini-3.1-pro --silent --no-ask-user -p "." 2>&1) || true
if printf '%s' "$_probe_out" | grep -qi "not available"; then
    error "Gemini models not available in current Copilot plan"
    error "Gemini 3.1 Pro requires Copilot Pro+ or Business/Enterprise"
    exit 3
fi

# Success — Copilot is available and accepts Gemini model
printf 'gemini via copilot\n'
