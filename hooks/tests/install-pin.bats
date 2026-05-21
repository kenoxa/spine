#!/usr/bin/env bats
# Regression tests for pin_modern_web_guidance() in install.sh.
# Covers: rewrite, idempotency, file-mode preservation (FU-2), and missing-file no-op.

load "test_helper"

INSTALL_SH="$BATS_TEST_DIRNAME/../../install.sh"

setup() {
  # Source install.sh without running main (source-guard required).
  # shellcheck source=../../install.sh
  source "$INSTALL_SH"

  # Create a temp directory for fixture files.
  FIXTURE_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# --- helpers ---

make_skill_file() {
  local path="$FIXTURE_DIR/SKILL.md"
  cat > "$path" <<'EOF'
---
name: modern-web-guidance
description: Use when modern web.
---
run: npx -y modern-web-guidance@latest
also: npx -y modern-web-guidance@latest check
extra: npx -y modern-web-guidance@latest audit
EOF
  printf '%s' "$path"
}

# --- tests ---

@test "rewrites every modern-web-guidance@latest occurrence to pinned version" {
  local skill_file
  skill_file=$(make_skill_file)

  run pin_modern_web_guidance "$skill_file" "1.2.3"
  assert_success

  run grep 'modern-web-guidance@latest' "$skill_file"
  assert_failure  # no @latest should remain

  run grep -c 'modern-web-guidance@1.2.3' "$skill_file"
  assert_success
  assert_output "3"  # all three occurrences replaced
}

@test "idempotent: second call leaves content byte-identical and does not bump mtime" {
  local skill_file
  skill_file=$(make_skill_file)

  pin_modern_web_guidance "$skill_file" "1.2.3"

  # Snapshot file content (newline-safe: cmp compares raw bytes, not command-substitution output).
  local snapshot
  snapshot="$FIXTURE_DIR/snapshot.md"
  cp "$skill_file" "$snapshot"

  # Set a known-old mtime so we can detect any re-write.
  touch -t 200001010000 "$skill_file"
  local mtime_before
  mtime_before=$(stat -f '%m' "$skill_file")

  run pin_modern_web_guidance "$skill_file" "1.2.3"
  assert_success

  # Byte-identical content — cmp -s avoids trailing-newline stripping from $().
  cmp -s "$snapshot" "$skill_file"

  # Fast-path skipped the rewrite: mtime must be unchanged.
  local mtime_after
  mtime_after=$(stat -f '%m' "$skill_file")
  [ "$mtime_before" = "$mtime_after" ]
}

@test "preserves file mode and inode after pinning (FU-2 regression: mv reset to 0600)" {
  local skill_file
  skill_file=$(make_skill_file)
  chmod 0644 "$skill_file"

  local inode_before
  inode_before=$(stat -f '%i' "$skill_file")

  run pin_modern_web_guidance "$skill_file" "1.2.3"
  assert_success

  local mode
  mode=$(stat -f '%OLp' "$skill_file")
  [ "$mode" = "644" ]

  # Inode unchanged proves cat > reused the existing inode (not mv/cp to a new file).
  local inode_after
  inode_after=$(stat -f '%i' "$skill_file")
  [ "$inode_before" = "$inode_after" ]
}

@test "missing file is a safe no-op, returns 0" {
  run pin_modern_web_guidance "$FIXTURE_DIR/nonexistent-SKILL.md" "1.2.3"
  assert_success
}

@test "malformed version is rejected and file is not modified" {
  local skill_file
  skill_file=$(make_skill_file)

  # Version containing a sed metacharacter must be rejected.
  run pin_modern_web_guidance "$skill_file" "1.2.3/x"
  assert_failure
  run grep 'modern-web-guidance@latest' "$skill_file"
  assert_success  # original @latest still present — file untouched

  # Empty version must also be rejected.
  run pin_modern_web_guidance "$skill_file" ""
  assert_failure
  run grep 'modern-web-guidance@latest' "$skill_file"
  assert_success  # original @latest still present — file untouched
}
