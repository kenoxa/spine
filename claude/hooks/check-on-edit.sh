#!/bin/bash
# check-on-edit.sh
# Claude Code PostToolUse hook: run project-appropriate checkers after file edits.
# Triggered by Edit|Write|MultiEdit tools via hooks.json matcher.
# Returns JSON on stdout with optional systemMessage.
# ALWAYS exits 0 — errors and missing-tooling notices are reported via systemMessage, never by exit code.

# Guarantee valid JSON output on any unexpected failure
trap 'echo "{}"; exit 0' ERR

# --- Read hook input from stdin ---
input=$(cat)

# jq is required for JSON parsing; skip gracefully if unavailable
if ! command -v jq &>/dev/null; then
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

# --- Resolve project root (walk up from file to find package.json or .git) ---
project_dir=$(dirname "$file_path")
while [ "$project_dir" != "/" ]; do
  [ -f "$project_dir/package.json" ] || [ -d "$project_dir/.git" ] && break
  project_dir=$(dirname "$project_dir")
done

if [ "$project_dir" = "/" ]; then
  echo '{}'
  exit 0
fi

# --- Detect package manager exec command ---
# Use nlx (ni's execute command). Fallback: bun x.
# Skip entirely for non-JS projects (no package.json → no checkers would match).
if [ ! -f "$project_dir/package.json" ]; then
  echo '{}'
  exit 0
fi

if command -v nlx &>/dev/null; then
  pm_exec="nlx"
elif command -v bun &>/dev/null; then
  pm_exec="bun x"
else
  jq -n --arg msg "Post-edit checkers require \`ni\` (universal pm wrapper). Install: brew install ni" \
    '{ "systemMessage": $msg }' || true
  exit 0
fi

# --- Checker registry ---
# Each checker: detect_<name> returns 0 if applicable, run_<name> outputs errors.
# To add a new checker (eslint, prettier, etc.), define detect_/run_ and append to CHECKERS.

CHECKERS=(typescript svelte biome)

detect_typescript() {
  # Skip standalone tsc when svelte-check will run (it includes TS checking)
  { [ ! -f "$project_dir/svelte.config.js" ] && [ ! -f "$project_dir/svelte.config.ts" ]; } &&
    [ -f "$project_dir/tsconfig.json" ] && [[ "$file_path" =~ \.(ts|tsx|mts|cts)$ ]]
}

run_typescript() {
  NO_COLOR=1 timeout 25 $pm_exec tsc --noEmit --pretty false 2>&1 | head -20
}

detect_svelte() {
  { [ -f "$project_dir/svelte.config.js" ] || [ -f "$project_dir/svelte.config.ts" ]; } &&
    [[ "$file_path" =~ \.(svelte|ts|js)$ ]]
}

run_svelte() {
  NO_COLOR=1 timeout 25 $pm_exec svelte-check --workspace "$project_dir" 2>&1 | head -20
}

detect_biome() {
  { [ -f "$project_dir/biome.json" ] || [ -f "$project_dir/biome.jsonc" ]; } &&
    [[ "$file_path" =~ \.(ts|tsx|js|jsx|mts|cts|mjs|cjs|json|jsonc|css)$ ]]
}

run_biome() {
  NO_COLOR=1 $pm_exec biome check "$file_path" 2>&1 | head -20
}

# --- Run applicable checkers ---
errors=""
for checker in "${CHECKERS[@]}"; do
  if "detect_$checker" 2>/dev/null; then
    output=$("run_$checker" 2>&1) || true
    # Filter out "command not found" noise
    if [ -n "$output" ] && ! echo "$output" | grep -q "command not found"; then
      errors+="### $checker"$'\n'"$output"$'\n\n'
    fi
  fi
done

# --- Output ---
if [ -n "$errors" ]; then
  jq -n --arg msg "Post-edit check found issues:"$'\n\n'"$errors" '{ "systemMessage": $msg }'
else
  echo '{}'
fi

exit 0
