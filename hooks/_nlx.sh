#!/bin/sh
# _nlx.sh — package exec resolver for Spine hooks.
# Resolves nlx (ni), bunx, bun x, or npx and execs the given command.
# Sources _env.sh for PATH setup in restricted hook runner environments.
#
# Usage: _nlx.sh <package-command> [args...]
#
# spine:managed — do not edit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_env.sh"

if [ $# -eq 0 ]; then
  echo "Usage: _nlx.sh <package-command> [args...]" >&2
  exit 0  # fail open
fi

if command -v nlx >/dev/null 2>&1; then
  exec nlx "$@"
elif command -v bunx >/dev/null 2>&1; then
  exec bunx "$@"
elif command -v bun >/dev/null 2>&1; then
  exec bun x "$@"
elif command -v npx >/dev/null 2>&1; then
  exec npx --yes "$@"
fi

echo "spine: no JS package runner found (nlx, bunx, npx). Install: brew install ni" >&2
exit 0
