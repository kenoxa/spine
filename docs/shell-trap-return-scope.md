---
updated: 2026-05-20
paths:
  - install.sh
---

# Shell `trap … RETURN` Scope Gotcha

## The Trap Is Global, Not Function-Scoped

`trap 'cmd' RETURN` set INSIDE a function is NOT removed when that function
returns. It persists as global shell state and fires again on the CALLER's
RETURN — and on every enclosing function return after that.

`functrace` / `set -T` controls whether a RETURN trap is *inherited* into
nested calls. It does NOT control *removal when the setting function returns*.
No bash option scopes a RETURN trap to the function that set it.

Fatal interaction with `set -u`: when the trapped command references a
function `local` (`rm -f "$tmp"`), that variable is out of scope when the
caller's RETURN fires → `unbound variable` → fatal exit. The failure surfaces
far from the trap site, inside a function that never set a trap.

### Verification (E3, 2026-05-20)

```sh
set -u
demo() {
  local tmp; tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN   # BUG: RETURN trap is global, not function-scoped
  rm -f "$tmp"
}
caller() { demo; return 0; }   # leaked trap fires HERE — $tmp out of scope
caller
# → "tmp: unbound variable", exit 1
```

Drop the `trap` line and the script exits 0. This exact bug in
`pin_modern_web_guidance()` (`install.sh`) crashed `install-pin.bats`
tests 1-3 under `set -u` — the `mktemp`+trap path; tests 4-5, returning
before `mktemp`, passed.

## Universal Idiom in install.sh

`install.sh` sets exactly ONE `trap` — `trap '_ui_cleanup' EXIT` at script
top level (`:223`). Its 24 `mktemp` call-sites all clean up with explicit
`rm -f` on every exit path — never `trap … RETURN` inside a function.
`git grep 'trap .*RETURN'` returns zero hits repo-wide.

Pattern — explicit cleanup, exit status preserved:

```sh
tmp=$(mktemp)
if build "$tmp" && commit "$tmp"; then rc=0; else rc=1; fi
rm -f "$tmp"
return "$rc"
```

The `if` wrapper suspends `set -e` for the condition; `rm -f` runs once;
`$tmp` stays in scope throughout. No trap needed.

[E2: `install.sh:223` — the sole trap; 24 `mktemp` sites, all explicit `rm -f`.]

## Anti-Patterns

- `trap 'rm -f "$tmp"' RETURN` inside a function — NOT function-scoped; fires
  again on the caller's RETURN; fatal under `set -u` when `$tmp` is a `local`.
- Assuming `set -T` / `functrace` scopes the RETURN trap — it gates
  *inheritance into nested calls*, not *cleanup when the setter returns*.
- Reaching for `trap … RETURN` as a DRY shortcut over explicit `rm -f` — the
  shortcut is semantically wrong in function scope. A reviewer or polish step
  proposing it should be rejected.

## Scope

Any bash/sh script that creates a `mktemp` temp file inside a function under
`set -eu`. The explicit-`rm -f` idiom is mandatory there; `trap … RETURN`
cannot substitute.
