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

@test "returns systemMessage when tsc finds errors" {
  # Skip if no JS package runner available (hook uses _nlx.sh: nlx/bunx/bun x/npx)
  command -v nlx >/dev/null 2>&1 || command -v bunx >/dev/null 2>&1 || command -v npx >/dev/null 2>&1 || skip "no package runner (nlx/bunx/npx)"

  # Create minimal project with type error
  local tmpdir
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir"
  printf '{"compilerOptions":{"strict":true,"noEmit":true},"include":["*.ts"]}\n' > "$tmpdir/tsconfig.json"
  printf '{"name":"test","private":true}\n' > "$tmpdir/package.json"
  printf 'const x: number = "not a number";\n' > "$tmpdir/bad.ts"

  local input
  input=$(printf '{"tool_input":{"file_path":"%s/bad.ts"}}' "$tmpdir")

  run_hook check-on-edit.sh "$input"
  assert_success  # always exits 0

  # Should contain systemMessage with checker output
  assert_output --partial "systemMessage"
  assert_output --partial "typescript"

  rm -rf "$tmpdir"
}
