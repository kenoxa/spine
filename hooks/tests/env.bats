#!/usr/bin/env bats
# Tests for _env.sh — environment bootstrap for Spine hooks.
# Verifies PATH restoration under restricted environments (simulating hook runners).

load test_helper

ENV_SH="$HOOKS_DIR/_env.sh"

# --- Idempotency ---

@test "_env.sh: idempotency guard prevents double execution" {
  run sh -c 'SPINE_ENV_LOADED=1 . "$1" && echo "sourced"' -- "$ENV_SH"
  assert_success
  # Should return immediately without re-running PATH logic
}

@test "_env.sh: wrapper mode with idempotency guard execs command" {
  run sh -c 'SPINE_ENV_LOADED=1 "$1" echo hello' -- "$ENV_SH"
  assert_success
  assert_output "hello"
}

# --- PATH restoration under restricted PATH ---

@test "_env.sh: restores bun access under restricted PATH" {
  # Simulate hook runner environment: only system paths
  if [ ! -d "$HOME/.bun/bin" ]; then
    skip "bun not installed at ~/.bun/bin"
  fi
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" sh -c '. "$1" && command -v bun' -- "$ENV_SH"
  assert_success
  assert_output --partial "bun"
}

@test "_env.sh: restores probe access under restricted PATH" {
  if [ ! -f "$HOME/.local/bin/probe" ]; then
    skip "probe not installed at ~/.local/bin"
  fi
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" sh -c '. "$1" && command -v probe' -- "$ENV_SH"
  assert_success
  assert_output --partial "probe"
}

@test "_env.sh: restores brew tools under restricted PATH" {
  local brew_bin=""
  if [ -d "/opt/homebrew/bin" ]; then
    brew_bin="/opt/homebrew/bin"
  elif [ -d "/usr/local/bin" ]; then
    brew_bin="/usr/local/bin"
  else
    skip "no Homebrew bin directory found"
  fi
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" sh -c '. "$1" && echo "$PATH"' -- "$ENV_SH"
  assert_success
  assert_output --partial "$brew_bin"
}

# --- Wrapper mode ---

@test "_env.sh: wrapper mode execs given command" {
  run "$ENV_SH" echo "wrapper-test"
  assert_success
  assert_output "wrapper-test"
}

@test "_env.sh: wrapper mode preserves exit code" {
  run "$ENV_SH" sh -c "exit 42"
  assert_failure 42
}

# --- SPINE_HOOKS_DIR export ---

@test "_env.sh: exports SPINE_HOOKS_DIR" {
  run sh -c '. "$1" && echo "$SPINE_HOOKS_DIR"' -- "$ENV_SH"
  assert_success
  assert_output --partial ".config/spine/hooks"
}

# --- Diagnostic mode ---

@test "_env.sh: SPINE_ENV_VERIFY=1 prints tool paths" {
  run env SPINE_ENV_VERIFY=1 sh -c '. "$1"' -- "$ENV_SH"
  assert_success
  assert_output --partial "spine-env:"
}

# --- No duplicate PATH entries ---

@test "_env.sh: does not duplicate existing PATH entries" {
  local test_path="/opt/homebrew/bin:/usr/bin:/bin"
  run env -i HOME="$HOME" PATH="$test_path" sh -c '. "$1" && echo "$PATH"' -- "$ENV_SH"
  assert_success
  # Count occurrences of /opt/homebrew/bin — should be exactly 1
  local count
  count=$(echo "$output" | tr ':' '\n' | grep -c '^/opt/homebrew/bin$' || true)
  [ "$count" -le 1 ]
}
