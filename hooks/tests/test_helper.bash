# Shared BATS helpers for Claude Code hook tests.
# Load bats-support and bats-assert from Homebrew.

BATS_LIB="${TEST_BREW_PREFIX:-$(brew --prefix 2>/dev/null)}/lib"
[[ -d "$BATS_LIB/bats-support" ]] || { echo "BATS: bats-support not found — brew install bats-support bats-assert" >&2; exit 1; }

load "$BATS_LIB/bats-support/load.bash"
load "$BATS_LIB/bats-assert/load.bash"

HOOKS_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

# Run a hook script with JSON input on stdin.
# Usage: run_hook <script_name> <json_string> [env_vars...]
run_hook() {
  local script="$HOOKS_DIR/$1"
  shift
  local input="$1"
  shift
  run bash -c 'printf "%s" "$1" | bash "$2"' -- "$input" "$script"
}

# Run a hook script with env vars.
# Usage: run_hook_env <script_name> <json_string> <env_key=val>...
run_hook_env() {
  local script="$HOOKS_DIR/$1"
  shift
  local input="$1"
  shift
  run env "$@" bash -c 'printf "%s" "$1" | bash "$2"' -- "$input" "$script"
}
