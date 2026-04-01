load "test_helper"

@test "allows non-recursive rm" {
  run_hook guard-rm.sh '{"tool_input":{"command":"rm file.txt"}}'
  assert_success
}

@test "allows rm -f (no recursive flag)" {
  run_hook guard-rm.sh '{"tool_input":{"command":"rm -f file.txt"}}'
  assert_success
}

@test "blocks rm -r" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rm -r dir/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "trash"
}

@test "blocks rm -rf" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rm -rf dist/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "blocks rm -fr" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rm -fr node_modules/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "blocks rm --recursive" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rm --recursive build/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "blocks rm -R" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rm -R dir/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "blocks rtk rm -rf" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"rtk rm -rf dist/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "blocks chained rm -rf after &&" {
  run bash -c 'echo "{\"tool_input\":{\"command\":\"echo hi && rm -rf dist/\"}}" | bash "$HOOKS_DIR/guard-rm.sh"'
  assert_failure 2
}

@test "allows empty command" {
  run_hook guard-rm.sh '{"tool_input":{"command":""}}'
  assert_success
}

@test "allows missing command field" {
  run_hook guard-rm.sh '{"tool_input":{}}'
  assert_success
}

@test "allows empty input" {
  run_hook guard-rm.sh '{}'
  assert_success
}
