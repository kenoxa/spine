#!/bin/bash
# Unified test runner for Spine hooks.
# Runs both BATS tests (shell hooks) and Bun tests (TypeScript hooks).
# Usage: bash hooks/tests/test.sh [bats|bun|all]
# Default: all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")"
export HOOKS_DIR

MODE="${1:-all}"
FAILURES=0

# --- BATS tests (shell hooks) ---

run_bats() {
  if ! command -v bats &>/dev/null; then
    echo "✘ bats not found — install: brew install bats-core bats-support bats-assert" >&2
    return 1
  fi

  echo "── Shell hooks (BATS) ──"
  local bats_files=("$SCRIPT_DIR"/*.bats)
  if [ ${#bats_files[@]} -eq 0 ]; then
    echo "  No .bats files found"
    return 0
  fi

  if ! bats "${bats_files[@]}"; then
    FAILURES=$((FAILURES + 1))
  fi
  echo ""
}

# --- Bun tests (TypeScript hooks) ---

run_bun() {
  if ! command -v bun &>/dev/null; then
    echo "✘ bun not found — install: https://bun.sh" >&2
    return 1
  fi

  local test_files=("$SCRIPT_DIR"/*.test.ts)
  if [ ${#test_files[@]} -eq 0 ]; then
    echo "  No .test.ts files found"
    return 0
  fi

  echo "── TypeScript hooks (Bun) ──"
  if ! bun test "${test_files[@]}"; then
    FAILURES=$((FAILURES + 1))
  fi
  echo ""
}

# --- Run ---

case "$MODE" in
  bats)  run_bats || FAILURES=$((FAILURES + 1)) ;;
  bun)   run_bun || FAILURES=$((FAILURES + 1)) ;;
  all)   run_bats || FAILURES=$((FAILURES + 1)); run_bun || FAILURES=$((FAILURES + 1)) ;;
  *)
    echo "Usage: $0 [bats|bun|all]"
    exit 1
    ;;
esac

if [ "$FAILURES" -gt 0 ]; then
  echo "✘ $FAILURES test suite(s) failed"
  exit 1
fi

echo "✓ All hook tests passed"
