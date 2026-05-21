---
updated: 2026-05-21
paths:
  - skills/use-worktree/tests/worktree.bats
  - hooks/tests/guard-shell.bats
  - hooks/tests/install-pin.bats
  - hooks/tests/worktree-root.bats
---

# Shell — Git Config Test Isolation

## Global `~/.gitconfig` Leaks Into Bats Test Repos

Bats suites that exercise `git rebase` or `git merge` are NOT isolated from
the developer's global `~/.gitconfig` (or `$XDG_CONFIG_HOME/git/config`) by
default. A test repo created with `git init` inherits the running user's
global AND system config unchanged.

**Observed failure:** `worktree.bats` test 14b asserts `sync` exits 1 when the
worktree has uncommitted changes. With `rebase.autostash = true` in the user's
global config, `git rebase` autostashes the dirty changes and *completes*
instead of *refusing* — test exits 0, not 1. Non-deterministic across
developers; invisible in CI if CI has no user config (passes there, fails
locally).

Repo-local config overrides global config and is inherited by ALL linked
worktrees of that repo — so a single pin in the `make_repo` setup helper
isolates the entire suite:

```sh
make_repo() {
  local dir="$1"
  git init "$dir"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config rebase.autostash false   # pin: global leak guard
  # ... initial commit etc.
}
```

## Full-Isolation Alternative

For suites that may grow to test merge conflict markers, `conflictStyle`,
or `rebase.backend` behavior, full-isolation avoids per-key enumeration:

```sh
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
```

Set in the `setup_file()` hook or prefix each `git` invocation. Null BOTH:
`GIT_CONFIG_GLOBAL` alone still loads system config (`$(prefix)/etc/gitconfig`).
Repo-local config still applies. Requires Git **2.32+** — on older clients use
`GIT_CONFIG_NOSYSTEM=1` plus an isolated `HOME`/`XDG_CONFIG_HOME`.

## Partial-Coverage Caveat

The `make_repo` pin idiom guards only the keys explicitly listed.
`rebase.autostash false` is the confirmed failure (E3, spec 2621 Slice 3
iteration 2). Other config that can invert test outcomes:

| Config key | Risk |
|---|---|
| `rebase.autostash` | dirty-tree rebase completes instead of refusing (confirmed) |
| `init.defaultBranch` | initial branch name; breaks `master`/`main` assertions |
| `commit.gpgsign` | signing prompt/failure in headless test env |
| `core.hooksPath` | redirects hooks outside the test repo; runs unexpected code |
| `merge.conflictStyle` | diff3/zdiff3/merge; breaks conflict-marker assertions |
| `rebase.backend` | apply vs merge engine; affects conflict presentation |
| `pull.rebase` | changes `git pull` behavior in pull-exercising tests |
| `core.autocrlf` | line endings in diff/status assertions |

Extend the pin set when adding assertions that depend on these. Prefer the
`GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM=/dev/null` alternative when the pin
list would exceed 3 keys — it also blocks `[includeIf]` in global/system
config from injecting values for keys the helper never anticipated.

## Anti-Patterns

- `git init` a test repo without any config pin — inherits the user's full
  global + system config; outcomes differ per developer and per CI agent.
- Pinning only `user.email`/`user.name` — those are identity, not behavior;
  rebase/merge/hook keys are the actual leak vector.
- Nulling only `GIT_CONFIG_GLOBAL` — system config still loads; null both.
- Assuming CI passes → suite is isolated — CI often has no user
  `~/.gitconfig`; the suite may still fail locally where users do.

## Scope

Any bats (or shell-based) test suite that creates test git repos and drives
`git rebase`, `git merge`, `git pull`, or `git sync`-style wrappers.
Confirmed affected: `skills/use-worktree/tests/worktree.bats`.
Latent risk: `hooks/tests/guard-shell.bats`, `hooks/tests/worktree-root.bats`.
