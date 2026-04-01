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
