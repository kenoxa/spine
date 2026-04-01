#!/bin/sh
# check-on-edit.sh
# PostToolUse hook: run project-appropriate checkers after file edits.
# Triggered by Edit|Write|MultiEdit tools via hooks.json matcher.
# Returns JSON on stdout with optional systemMessage.
# ALWAYS exits 0 — errors and missing-tooling notices are reported via systemMessage, never by exit code.

# Guarantee valid JSON output on any unexpected failure
trap 'echo "{}"; exit 0' HUP INT TERM

# --- Read hook input from stdin ---
input=$(cat)

# jq is required for JSON parsing; skip gracefully if unavailable
if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

# Extract file path from tool_input (Edit/Write use file_path, MultiEdit uses edits[0].file_path)
file_path=$(echo "$input" | jq -r '
  .tool_input.file_path //
  .tool_input.edits[0].file_path //
  empty' 2>/dev/null)

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  echo '{}'
  exit 0
fi

# --- Resolve project root ---
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
project_dir=$("$HOOKS_DIR/_project.sh" "$file_path") || { echo '{}'; exit 0; }

# Skip non-JS projects (no package.json → no checkers would match)
if [ ! -f "$project_dir/package.json" ]; then
  echo '{}'
  exit 0
fi

# Package exec resolver — _nlx.sh handles nlx/bunx/bun x/npx fallback
pm_exec="$HOOKS_DIR/_nlx.sh"

# --- File extension helper (POSIX — no bash regex) ---
file_ext="${file_path##*.}"

match_ext() {
  # Usage: match_ext ts tsx mts cts
  for _ext in "$@"; do
    [ "$file_ext" = "$_ext" ] && return 0
  done
  return 1
}

# --- Checker registry ---
# Each checker: detect_<name> returns 0 if applicable, run_<name> outputs errors.
# To add a new checker, define detect_/run_ and append to the loop below.

detect_typescript() {
  # Skip standalone tsc when svelte-check will run (it includes TS checking)
  [ ! -f "$project_dir/svelte.config.js" ] && [ ! -f "$project_dir/svelte.config.ts" ] &&
    [ -f "$project_dir/tsconfig.json" ] && match_ext ts tsx mts cts
}

run_typescript() {
  NO_COLOR=1 timeout 25 "$pm_exec" tsc --noEmit --pretty false 2>&1 | head -20
}

detect_svelte() {
  { [ -f "$project_dir/svelte.config.js" ] || [ -f "$project_dir/svelte.config.ts" ]; } &&
    match_ext svelte ts js
}

run_svelte() {
  NO_COLOR=1 timeout 25 "$pm_exec" svelte-check --workspace "$project_dir" 2>&1 | head -20
}

detect_biome() {
  { [ -f "$project_dir/biome.json" ] || [ -f "$project_dir/biome.jsonc" ]; } &&
    match_ext ts tsx js jsx mts cts mjs cjs json jsonc css
}

run_biome() {
  NO_COLOR=1 "$pm_exec" biome check "$file_path" 2>&1 | head -20
}

# --- Run applicable checkers ---
errors=""
for checker in typescript svelte biome; do
  if "detect_$checker" 2>/dev/null; then
    output=$("run_$checker" 2>&1) || true
    # Filter out tool-internal noise (missing commands, runtime crashes in the checker itself)
    if [ -n "$output" ] && ! echo "$output" | grep -qE "command not found|TypeError:|ReferenceError:|Cannot find module"; then
      errors="${errors}### ${checker}
${output}

"
    fi
  fi
done

# --- Output ---
if [ -n "$errors" ]; then
  jq -n --arg msg "Post-edit check found issues:

$errors" '{ "systemMessage": $msg }'
else
  echo '{}'
fi

exit 0
