load "test_helper"

@test "returns {} for non-existent file" {
  run_hook check-on-edit.sh '{"tool_input":{"file_path":"/nonexistent/file.ts"}}'
  assert_success
  assert_output "{}"
}

@test "returns {} for empty input" {
  run_hook check-on-edit.sh '{}'
  assert_success
  assert_output "{}"
}

@test "returns {} for file outside any project" {
  local tmp
  tmp=$(mktemp /tmp/spine-test-XXXXXX.txt)
  echo "hello" > "$tmp"
  run_hook check-on-edit.sh "{\"tool_input\":{\"file_path\":\"$tmp\"}}"
  assert_success
  assert_output "{}"
  rm -f "$tmp"
}

@test "returns {} for non-JS file in a project" {
  # markdown file — no checker should match
  local project_dir
  project_dir=$(mktemp -d /tmp/spine-test-project-XXXXXX)
  echo '{}' > "$project_dir/package.json"
  echo "# readme" > "$project_dir/README.md"
  run_hook check-on-edit.sh "{\"tool_input\":{\"file_path\":\"$project_dir/README.md\"}}"
  assert_success
  assert_output "{}"
  rm -rf "$project_dir"
}

@test "always exits 0 even with bad JSON" {
  run_hook check-on-edit.sh 'not json'
  assert_success
}
