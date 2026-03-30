#!/bin/sh
# Check MiniMax (via OpenCode CLI) availability for cross-provider invocation.
# Exit: 0=available, 1=not installed, 2=unresponsive, 3=not authenticated
# Stdout: version string on success. All errors to stderr.

set -eu

_script_dir=$(cd "$(dirname "$0")" && pwd)

# Phases 1-2: delegate to check-opencode.sh (binary + responsive)
_version=$(sh "$_script_dir/check-opencode.sh" 2>/dev/null) || exit $?

# Phase 3: verify MiniMax models are available (opencode-go/ or opencode/)
_models=$(timeout 10 opencode models 2>/dev/null) || true
if ! printf '%s' "$_models" | grep -q 'minimax'; then
    printf 'Error: no MiniMax models available (need OpenCode Go subscription or Zen)\n' >&2
    exit 3
fi

printf '%s\n' "$_version"
