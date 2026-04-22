load "test_helper"

@test "outputs nothing when no AGENTS.md exists" {
  local project_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  mkdir "$project_dir/.git"
  run env CLAUDE_PROJECT_DIR="$project_dir" bash "$HOOKS_DIR/inject-agents-md.sh"
  assert_success
  refute_output --partial "AGENTS.md"
  rm -rf "$project_dir"
}

@test "outputs AGENTS.md content when present" {
  local project_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  mkdir "$project_dir/.git"
  echo "# Test Agents" > "$project_dir/AGENTS.md"
  run env CLAUDE_PROJECT_DIR="$project_dir" bash "$HOOKS_DIR/inject-agents-md.sh"
  assert_success
  assert_output --partial "# Project AGENTS.md"
  assert_output --partial "# Test Agents"
  rm -rf "$project_dir"
}

@test "includes source comment" {
  local project_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  mkdir "$project_dir/.git"
  echo "# Agents" > "$project_dir/AGENTS.md"
  run env CLAUDE_PROJECT_DIR="$project_dir" bash "$HOOKS_DIR/inject-agents-md.sh"
  assert_success
  assert_output --partial "<!-- source:"
  rm -rf "$project_dir"
}

@test "bails with {} under Cursor" {
  local project_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  mkdir "$project_dir/.git"
  echo "# Should not appear" > "$project_dir/AGENTS.md"
  run_hook_env "inject-agents-md.sh" "" CLAUDE_PROJECT_DIR="$project_dir" SPINE_PROVIDER_IS_CURSOR=1
  assert_success
  assert_output "{}"
  refute_output --partial "Should not appear"
  rm -rf "$project_dir"
}

@test "stdin cwd takes precedence over CLAUDE_PROJECT_DIR" {
  local project_dir other_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  other_dir=$(mktemp -d /tmp/spine-test-other-XXXXXX)
  mkdir "$project_dir/.git" "$other_dir/.git"
  echo "# From stdin cwd" > "$project_dir/AGENTS.md"
  echo "# From env fallback" > "$other_dir/AGENTS.md"
  run_hook_env "inject-agents-md.sh" "{\"cwd\":\"$project_dir\"}" CLAUDE_PROJECT_DIR="$other_dir"
  assert_success
  assert_output --partial "# From stdin cwd"
  refute_output --partial "# From env fallback"
  rm -rf "$project_dir" "$other_dir"
}

@test "monorepo subdir does not leak sibling AGENTS.md" {
  local root subdir
  root=$(mktemp -d /tmp/spine-test-mono-XXXXXX)
  mkdir "$root/.git"
  mkdir -p "$root/packages/a" "$root/packages/b"
  echo "# Root rules" > "$root/AGENTS.md"
  echo "# Sibling package a (should NOT leak)" > "$root/packages/a/AGENTS.md"
  # anchor at packages/b (no AGENTS.md there, no sibling pollution expected)
  subdir="$root/packages/b"
  run_hook "inject-agents-md.sh" "{\"cwd\":\"$subdir\"}"
  assert_success
  assert_output --partial "# Root rules"
  refute_output --partial "should NOT leak"
  rm -rf "$root"
}

@test "emits three-level ancestor chain in root-first order" {
  local root pkg sub
  root=$(mktemp -d /tmp/spine-test-chain-XXXXXX)
  mkdir "$root/.git"
  pkg="$root/pkg"
  sub="$pkg/sub"
  mkdir -p "$sub"
  echo "# Level-root" > "$root/AGENTS.md"
  echo "# Level-pkg"  > "$pkg/AGENTS.md"
  echo "# Level-sub"  > "$sub/AGENTS.md"
  run_hook "inject-agents-md.sh" "{\"cwd\":\"$sub\"}"
  assert_success
  assert_output --partial "# Level-root"
  assert_output --partial "# Level-pkg"
  assert_output --partial "# Level-sub"
  # Order check: root before pkg before sub in emitted output
  [[ "$output" == *"Level-root"*"Level-pkg"*"Level-sub"* ]]
  rm -rf "$root"
}
