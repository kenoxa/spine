---
updated: 2026-04-26
paths:
  - skills/run-queue/scripts/queue-lint.sh
---

# Shell Validator Locale Guard

## The Vulnerability

POSIX `case` character classes (`[!A-Za-z0-9._:/\[\]_-]`) are NOT
locale-independent. Under `LC_CTYPE=en_US.UTF-8`, multi-byte sequences
(e.g. `è`, `ñ`, emoji) are classified as `[:alpha:]` by the C library
and silently pass a negated allowlist. A validator intended to reject
anything outside `[A-Za-z0-9._:/[]_-]` accepts them as letters.

**Assumption corrected:** "Negated POSIX character class is locale-
independent" — false. LC_CTYPE semantics apply at runtime.

## Verification

```sh
# Should reject — returns A (accepted, BYPASS) under en_US.UTF-8:
case "modèle" in *[!A-Za-z0-9._:/\[\]_-]*) echo R ;; *) echo A ;; esac

# Returns R (rejected) under C locale:
LC_ALL=C
case "modèle" in *[!A-Za-z0-9._:/\[\]_-]*) echo R ;; *) echo A ;; esac
```

[E3: reproducible one-liner — Slice F verifier probe, 2026-04-26]

## Fix Pattern

Set `LC_ALL=C` in the same shell, immediately before the validator
block. Do NOT use a subshell (`LC_ALL=C sh -c "case ..."`) — if the
validator increments an error counter in the parent shell, the counter
update is lost when the subshell exits.

```sh
# CORRECT — bare assignment in parent shell
LC_ALL=C
if [ -n "$_input" ]; then
    case "$_input" in
        *[!A-Za-z0-9._:/\[\]_-]*)
            _record "$_id: contains characters outside allowed set" ;;
    esac
fi
```

Canonical reference: `_mo` validator at `queue-lint.sh:181-201`.
[E2: `skills/run-queue/scripts/queue-lint.sh:183`]

## Known Unresolved Sites (follow-up)

Two sibling validators in `queue-lint.sh` still lack `LC_ALL=C`:

| Validator | Location | Exposed patterns |
|-----------|----------|-----------------|
| `_run_id` charset | `:51-58` | `[[:space:]]` — space check; `LC_CTYPE` affects `[[:space:]]` too |
| `_tc` shell-metachars | `:152-155` | backtick/`$`/`\|`/`;`/`&`/`>`/`<`/`\` — literal-char matching, minimal LC risk but guard is hygiene |

Apply `LC_ALL=C` before each block per the fix pattern above.

## Scope

Pattern applies to any POSIX sh/bash input validator that uses
character-class ranges in `case` expressions or `[[ =~ ]]` tests and
runs on systems with non-C locales (macOS, Linux with UTF-8 default).
Relevant wherever: byte-level rejection is required, arbitrary user or
file-derived strings are validated, validator output feeds security or
correctness decisions.

## Anti-Patterns

- `LC_ALL=C sh -c "..."` — subshell drops side effects (counter increments, variable assignments).
- `export LC_ALL=C` at script top — valid but widens scope; inline assignment is more surgical.
- Assuming `set -e` catches the bypass — it doesn't; the case arm simply takes the wrong branch.
