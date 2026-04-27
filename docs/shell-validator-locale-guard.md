---
updated: 2026-04-27
paths:
  - skills/run-queue/scripts/queue-lint.sh
---

# Shell Validator Locale Guard

## Two Bypass Shapes With Opposite Locale Polarity

POSIX `case` patterns interact with the system locale in TWO different
ways that pull in OPPOSITE directions. A single locale setting cannot
fix both — pair `LC_ALL=C` (for negated-charset gates) with an
explicit allowlist (which catches what positive-class checks miss
under C).

### Shape A — Negated charset (`*[!A-Za-z0-9...]*`)

Used as: "reject any byte not in the allowed set."

| Locale | Behaviour with input `modèle` |
|--------|-------------------------------|
| `en_US.UTF-8` (default macOS) | UTF-8 alpha (`è`) classifies as alphabetic → falls inside `[A-Za-z]` → **ACCEPTED (bypass)** |
| `LC_ALL=C` | Only ASCII A-Za-z0-9 are alphanumeric → `è` outside set → **REJECTED (correct)** |

Negated charsets need `LC_ALL=C` to behave as byte-level rejection.
**Bash 3.2's character-class engine consults LC_CTYPE collation even
for explicit ranges like `[A-Za-z]`** — explicit byte ranges are NOT
locale-independent at the shell level. `LC_ALL=C` is required.

### Shape B — Positive class (`*[[:space:]]*`, `*[[:alpha:]]*`)

Used as: "reject any byte the locale classifies as <class>."

| Locale | Behaviour with input `bad\xC2\xA0id` (NO-BREAK SPACE) |
|--------|---|
| `en_US.UTF-8` (default macOS) | NBSP byte 0xA0 classifies as space → **REJECTED (correct)** |
| `LC_ALL=C` | Only ASCII whitespace counts → 0xA0 not space → **ACCEPTED (bypass)** |

Positive classes BREAK under `LC_ALL=C` for non-ASCII input.

### Verification (E3, 2026-04-27)

```sh
bash -c 'LANG=en_US.UTF-8; case "modèle" in *[!A-Za-z0-9._-]*) echo R ;; *) echo A ;; esac'
# → A (BYPASS — bash 3.2 uses locale collation for [A-Za-z])
bash -c 'LANG=en_US.UTF-8 LC_ALL=C; case "modèle" in *[!A-Za-z0-9._-]*) echo R ;; *) echo A ;; esac'
# → R (correct under C)

nbsp=$(printf 'bad\xC2\xA0id')
bash -c 'LANG=en_US.UTF-8; case "'"$nbsp"'" in *[[:space:]]*) echo R ;; *) echo A ;; esac'
# → R (correct under default)
bash -c 'LANG=en_US.UTF-8 LC_ALL=C; case "'"$nbsp"'" in *[[:space:]]*) echo R ;; *) echo A ;; esac'
# → A (BYPASS — NBSP not in C's whitespace set)
```

## Recommended Pattern — Layered Defense

A pure validator script has no locale-aware code, so set `LC_ALL=C`
script-wide and pair every input field with an **explicit allowlist
gate** as the primary defense. The allowlist catches everything
outside ASCII alphanumerics — including NBSP, UTF-8 letters, emoji,
shell metacharacters — regardless of what `[[:space:]]` would have
caught.

```sh
#!/bin/sh
set -eu
LC_ALL=C   # script-wide; every validator below is byte-level

# Per-validator: pair allowlist (primary) with positive-class checks
# (defense-in-depth + diagnostic specificity).
case "$_input" in
    *[[:space:]]*) _record "$_id: contains whitespace" ;;          # ASCII whitespace under C
    *[!A-Za-z0-9._-]*) _record "$_id: chars outside [A-Za-z0-9._-]" ;;  # NBSP, UTF-8, everything else
esac
```

`case` arms evaluate top-to-bottom and the first match wins, so ASCII
whitespace gets the specific "contains whitespace" message; non-ASCII
inputs fall through to the broader "chars outside" message.

## Anti-Patterns

- `LC_ALL=C sh -c "..."` — subshell drops side effects (counter
  increments, variable assignments).
- Script-wide `LC_ALL=C` WITHOUT a paired allowlist gate — Shape B
  positive-class checks like `[[:space:]]` no longer catch UTF-8
  whitespace, leaving the validator open. Verified regression: Slice
  G first attempt set `LC_ALL=C` script-wide without adding the
  `_run_id` allowlist; NBSP run_id slipped through.
- Relying solely on `[[:space:]]` for whitespace rejection — works
  under `en_US.UTF-8` but is silently broken if anyone sets
  `LC_ALL=C` elsewhere in the script. Pair with explicit allowlist.
- Assuming "explicit byte ranges like `[A-Za-z]` are locale-
  independent" — they aren't in bash 3.2 (macOS default). The
  character-class engine collates per locale even for ranges. Set
  `LC_ALL=C` to make ranges deterministic.
- Assuming `set -e` catches the bypass — it doesn't; the `case` arm
  simply takes the wrong branch.

## Resolved Sites — `queue-lint.sh`

Script-wide `LC_ALL=C` at `:9` makes negated-charset checks
locale-deterministic. Each validator pairs with an explicit allowlist.

| Validator | Location | Defense |
|-----------|----------|---------|
| `_run_id` | `:51-59` | Allowlist `[A-Za-z0-9._-]` (Slice G) + `[[:space:]]` for ASCII whitespace diagnostic + git-refname structural rules |
| `_tc` shell-metachars | `:152-155` | Literal-ASCII metachar set; locale-independent by construction (positive-pattern match on literal bytes) |
| `_mo` | `:181-198` | Allowlist `[A-Za-z0-9._:/\[\]_-]` (Slice F) + `[[:space:]]` for ASCII whitespace diagnostic + length cap |

[E2: `queue-lint.sh:9, :51-59, :152-155, :181-198` — Slice G, 2026-04-27]

## Scope

Pattern applies to any POSIX sh/bash input validator that uses
character-class ranges in `case` expressions or `[[ =~ ]]` tests on
systems with non-C locales (macOS, Linux with UTF-8 default).
Relevant wherever byte-level rejection is required and validator
output feeds security or correctness decisions.
