#!/usr/bin/env bats
load "test_helper"

# Regression tests for linked git worktrees, where .git is a file (a gitdir:
# pointer) rather than a directory. _project.sh and inject-agents-md.sh used to
# test only [ -d .git ], so root resolution walked past the worktree root into
# the parent checkout. The fix adds an [ -f .git ] check to both.

# make_repo <dir> — create a minimal committed git repo in <dir>.
make_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@spine-test.local"
  git -C "$dir" config user.name "Spine Test"
  touch "$dir/.keep"
  git -C "$dir" add .keep
  git -C "$dir" commit -q -m "init"
}

@test "_project.sh resolves worktree root when .git is a file" {
  local repo wt file
  repo=$(mktemp -d /tmp/spine-test-wt-XXXXXX)
  make_repo "$repo"

  # Create a linked worktree inside the repo dir.
  # A buggy walk would climb past repo/wt and resolve to repo itself.
  git -C "$repo" worktree add -q "$repo/wt" 2>/dev/null

  # .git inside the worktree must be a file (the gitdir: pointer)
  [ -f "$repo/wt/.git" ] || skip "git worktree add did not create a .git file"

  # Create a file inside the worktree to give _project.sh a concrete path
  touch "$repo/wt/test-file.txt"

  run bash "$HOOKS_DIR/_project.sh" "$repo/wt/test-file.txt"
  assert_success
  # Output must be the worktree root, not the parent checkout
  assert_output "$repo/wt"
  refute_output "$repo"

  rm -rf "$repo"
}

@test "_project.sh still resolves a normal repo root when .git is a directory" {
  local repo
  repo=$(mktemp -d /tmp/spine-test-normalrepo-XXXXXX)
  make_repo "$repo"

  # .git must be a directory in a non-worktree checkout
  [ -d "$repo/.git" ] || skip ".git is not a directory — unexpected environment"

  touch "$repo/test-file.txt"

  run bash "$HOOKS_DIR/_project.sh" "$repo/test-file.txt"
  assert_success
  assert_output "$repo"

  rm -rf "$repo"
}

@test "inject-agents-md.sh stops at worktree root and does not leak parent AGENTS.md" {
  local repo wt
  repo=$(mktemp -d /tmp/spine-test-wt-leak-XXXXXX)
  make_repo "$repo"

  # AGENTS.md in the parent (main checkout) — must NOT appear in output
  printf '# Parent AGENTS — should NOT leak\n' > "$repo/AGENTS.md"

  # Create linked worktree inside repo
  git -C "$repo" worktree add -q "$repo/wt" 2>/dev/null

  # .git inside the worktree must be a file for the regression to apply
  [ -f "$repo/wt/.git" ] || skip "git worktree add did not create a .git file"

  # AGENTS.md in the worktree root — must appear in output
  printf '# Worktree AGENTS — should appear\n' > "$repo/wt/AGENTS.md"

  run_hook "inject-agents-md.sh" "{\"cwd\":\"$repo/wt\"}"
  assert_success
  assert_output --partial "# Worktree AGENTS — should appear"
  refute_output --partial "should NOT leak"

  rm -rf "$repo"
}
