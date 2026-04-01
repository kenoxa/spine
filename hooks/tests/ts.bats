#!/usr/bin/env bats
# Tests for _ts.sh — TypeScript runtime resolver.

load test_helper

TS_SH="$HOOKS_DIR/_ts.sh"

@test "_ts.sh: no-args exits 0 (fail open)" {
  run "$TS_SH"
  assert_success
  assert_output --partial "Usage"
}

@test "_ts.sh: executes TS file via bun when available" {
  if ! command -v bun &>/dev/null; then
    skip "bun not installed"
  fi
  local tmp
  tmp=$(mktemp /tmp/spine-test-XXXXXX.ts)
  echo 'console.log("ts-hook-test")' > "$tmp"
  run "$TS_SH" "$tmp"
  assert_success
  assert_output "ts-hook-test"
  rm -f "$tmp"
}

@test "_ts.sh: exits 0 with message when no runtime found" {
  # SPINE_ENV_LOADED=1 skips _env.sh PATH restoration, so runtimes stay missing
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" SPINE_ENV_LOADED=1 sh "$TS_SH" /dev/null
  assert_success
  assert_output --partial "no TS runtime found"
}
