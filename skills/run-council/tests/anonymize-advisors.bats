#!/usr/bin/env bats
# Test suite for anonymize-advisors.sh
# Requires: bats 1.13+, bats-assert 2.x, bats-support 0.3+

load '/opt/homebrew/lib/bats-support/load.bash'
load '/opt/homebrew/lib/bats-assert/load.bash'

SCRIPT=''
TEST_DIR=''

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/anonymize-advisors.sh"
  TEST_DIR="$(mktemp -d)"
  _create_fixtures "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# _create_fixtures <dir> — writes 5 council-advisor-*.md files into <dir>
_create_fixtures() {
  local dir="$1"

  cat > "$dir/council-advisor-contrarian.md" <<'EOF'
---
model: claude-sonnet-4-6
effort: high
---

# Council Advisor: Contrarian

## 1. Lens summary

The Contrarian lens is optimized to detect fatal flaws. This perspective searches for what could fail catastrophically.

## 2. Assessment

The recommendation in the advise-synthesis is overly optimistic. Reading council-lens-contrarian.md confirms this stance.

## 5. Confidence

E2 — code-level evidence found. council-lens-contrarian.md verified the lens definition.
EOF

  cat > "$dir/council-advisor-first-principles.md" <<'EOF'
# Council Advisor: First Principles

## 1. Lens summary

The First Principles lens decomposes assumptions to their foundational elements.

## 2. Assessment

Approaching this from First Principles reveals hidden assumptions. See council-lens-first-principles.md for the full breakdown.

## 5. Confidence

E1 — doc reference. council-lens-first-principles.md cited.
EOF

  cat > "$dir/council-advisor-expansionist.md" <<'EOF'
# Council Advisor: Expansionist

## 1. Lens summary

The Expansionist lens broadens scope to surface adjacent opportunities.

## 2. Assessment

The Expansionist perspective finds three untapped areas. See council-lens-expansionist.md.

## 5. Confidence

E2 — code reference. council-lens-expansionist.md reviewed.
EOF

  cat > "$dir/council-advisor-outsider.md" <<'EOF'
# Council Advisor: Outsider

## 1. Lens summary

The Outsider lens applies domain-agnostic pattern matching.

## 2. Assessment

An Outsider reading surfaces unconventional solutions. council-lens-outsider.md was consulted.

## 5. Confidence

E1 — doc reference. council-lens-outsider.md cited.
EOF

  cat > "$dir/council-advisor-executor.md" <<'EOF'
# Council Advisor: Executor

## 1. Lens summary

The Executor lens focuses on practical delivery and implementation sequencing.

## 2. Assessment

The Executor perspective recommends a phased rollout. council-lens-executor.md was consulted.

## 5. Confidence

E2 — code reference. council-lens-executor.md reviewed.
EOF
}

# ---------------------------------------------------------------------------
# Test 1: produces 5 anonymized output files A through E
# ---------------------------------------------------------------------------
@test "produces 5 anonymized output files A through E" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for letter in A B C D E; do
    run test -f "$TEST_DIR/council-advisor-anon-${letter}.md"
    assert_success
  done
}

# ---------------------------------------------------------------------------
# Test 2: produces council-anon-map.json
# ---------------------------------------------------------------------------
@test "produces council-anon-map.json" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  run test -f "$TEST_DIR/council-anon-map.json"
  assert_success
}

# ---------------------------------------------------------------------------
# Test 3: map contains all 5 slugs
# ---------------------------------------------------------------------------
@test "map contains all 5 slugs" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for slug in contrarian first-principles expansionist outsider executor; do
    run grep -q "\"${slug}\"" "$TEST_DIR/council-anon-map.json"
    assert_success
  done
}

# ---------------------------------------------------------------------------
# Test 4: map contains all 5 letters as keys
# ---------------------------------------------------------------------------
@test "map contains all 5 letters as keys" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for letter in A B C D E; do
    run grep -q "\"${letter}\":" "$TEST_DIR/council-anon-map.json"
    assert_success
  done
}

# ---------------------------------------------------------------------------
# Test 5: each anonymized file starts with # Advisor {LETTER} header
# ---------------------------------------------------------------------------
@test "each anonymized file starts with # Advisor LETTER header" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for letter in A B C D E; do
    first_line="$(head -1 "$TEST_DIR/council-advisor-anon-${letter}.md")"
    [ "$first_line" = "# Advisor ${letter}" ]
  done
}

# ---------------------------------------------------------------------------
# Test 6: no lens slug file references remain in anonymized outputs
# ---------------------------------------------------------------------------
@test "no lens slug file references remain in anonymized outputs" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for slug in contrarian first-principles expansionist outsider executor; do
    run grep -rq "council-lens-${slug}\.md" "$TEST_DIR/council-advisor-anon-"*.md
    assert_failure
  done
}

# ---------------------------------------------------------------------------
# Test 7: no lens names remain in anonymized outputs
# ---------------------------------------------------------------------------
@test "no lens names remain in anonymized outputs" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  for term in Contrarian 'First Principles' Expansionist Outsider Executor; do
    run grep -rq "$term" "$TEST_DIR/council-advisor-anon-"*.md
    assert_failure
  done
}

# ---------------------------------------------------------------------------
# Test 8: YAML frontmatter is stripped — no model: line in output
# ---------------------------------------------------------------------------
@test "YAML frontmatter is stripped — no model: line in output" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  # Find the letter assigned to contrarian from the map (format: "A": "contrarian")
  letter="$(sed -n 's/.*"\([A-E]\)": *"contrarian".*/\1/p' "$TEST_DIR/council-anon-map.json")"
  [ -n "$letter" ]

  run grep -q '^model:' "$TEST_DIR/council-advisor-anon-${letter}.md"
  assert_failure
}

# ---------------------------------------------------------------------------
# Test 9: [LENS] placeholder appears in anonymized outputs
# ---------------------------------------------------------------------------
@test "[LENS] placeholder appears in anonymized outputs" {
  run "$SCRIPT" "$TEST_DIR"
  assert_success

  run grep -rql '\[LENS\]' "$TEST_DIR/council-advisor-anon-"*.md
  assert_success
}

# ---------------------------------------------------------------------------
# Test 10: fails with exit 1 when a batch output is missing
# ---------------------------------------------------------------------------
@test "fails with exit 1 when a batch output is missing" {
  rm "$TEST_DIR/council-advisor-outsider.md"

  run "$SCRIPT" "$TEST_DIR"
  assert_failure
}

# ---------------------------------------------------------------------------
# Test 11: fails with exit 1 when session dir does not exist
# ---------------------------------------------------------------------------
@test "fails with exit 1 when session dir does not exist" {
  run "$SCRIPT" "/nonexistent/path/$(openssl rand -hex 4)"
  assert_failure
}

# ---------------------------------------------------------------------------
# Test 12: randomizes assignment — re-running produces a different mapping
# ---------------------------------------------------------------------------
@test "randomizes assignment — re-running produces a different mapping at least once in 5 runs" {
  first_letter=''
  all_same=true

  for _ in 1 2 3 4 5; do
    iter_dir="$(mktemp -d)"
    _create_fixtures "$iter_dir"

    run "$SCRIPT" "$iter_dir"
    assert_success

    # Extract letter key for contrarian: map format is "X": "contrarian"
    letter="$(grep '"contrarian"' "$iter_dir/council-anon-map.json" | grep -oE '"[A-E]":' | tr -d '":')"

    if [ -z "$first_letter" ]; then
      first_letter="$letter"
    elif [ "$letter" != "$first_letter" ]; then
      all_same=false
    fi

    rm -rf "$iter_dir"
  done

  # If all 5 runs assigned contrarian the same letter, the shuffle is broken.
  # Probability of false failure: (1/5)^4 ≈ 0.16%
  [ "$all_same" = false ]
}

# ---------------------------------------------------------------------------
# Test 13: **Lens**: metadata line description is fully redacted
# ---------------------------------------------------------------------------
@test "Lens metadata line description is redacted not just the name" {
  # Inject a realistic **Lens**: line into the contrarian fixture
  # (mirrors what real advisors write — name replaced but stance leaks without this fix)
  printf '\n**Lens**: Contrarian — search for fatal flaws; assume something critical was missed.\n' \
    >> "$TEST_DIR/council-advisor-contrarian.md"

  run "$SCRIPT" "$TEST_DIR"
  assert_success

  # Find which letter contrarian was assigned
  letter="$(sed -n 's/.*"\([A-E]\)": *"contrarian".*/\1/p' "$TEST_DIR/council-anon-map.json")"

  # The full description after **Lens**: must be gone — only [REDACTED] remains
  run grep '\*\*Lens\*\*:' "$TEST_DIR/council-advisor-anon-${letter}.md"
  assert_output --partial '[REDACTED]'

  # The stance phrase must not appear verbatim
  run grep -q 'search for fatal flaws' "$TEST_DIR/council-advisor-anon-${letter}.md"
  assert_failure
}
