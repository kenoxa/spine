#!/bin/sh
# _ts.sh — TypeScript runtime resolver for Spine hooks.
# Sources _env.sh for PATH setup, then execs the TS file with the best available runtime.
#
# Usage: _ts.sh <hook-name.ts> [args...]   (bare name → resolved in hooks dir)
#        _ts.sh /full/path.ts [args...]    (absolute → used as-is)
#
# Priority: bun (fastest startup) → node ≥22 (native TS via --experimental-strip-types) → deno
#
# spine:managed — do not edit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_env.sh"

if [ $# -eq 0 ]; then
  echo "Usage: _ts.sh <hook-name.ts> [args...]" >&2
  exit 0  # fail open
fi

# Resolve bare hook names relative to hooks directory
case "$1" in
  /*|./*) _ts_script="$1" ;;
  *) _ts_script="$SPINE_HOOKS_DIR/$1" ;;
esac
shift

# 1. Bun — fastest startup, native TS
BUN_PATH=$(command -v bun 2>/dev/null)
if [ -n "$BUN_PATH" ]; then
  exec "$BUN_PATH" "$_ts_script" "$@"
fi

# 2. Node ≥22 — native TS via --experimental-strip-types
NODE_PATH=$(command -v node 2>/dev/null)
if [ -n "$NODE_PATH" ]; then
  NODE_MAJOR=$("$NODE_PATH" -e 'process.stdout.write(String(process.versions.node.split(".")[0]))' 2>/dev/null)
  if [ "${NODE_MAJOR:-0}" -ge 22 ]; then
    exec "$NODE_PATH" --experimental-strip-types "$_ts_script" "$@"
  fi
fi

# 3. Deno — native TS, Node compat layer
DENO_PATH=$(command -v deno 2>/dev/null)
if [ -n "$DENO_PATH" ]; then
  exec "$DENO_PATH" run --allow-read --allow-env --allow-run "$_ts_script" "$@"
fi

# Fail open — don't block the tool call
echo "spine: no TS runtime found (bun, node ≥22, deno). Install one: brew install bun" >&2
exit 0
