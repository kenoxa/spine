# ast-grep (sg) — Structural Code Search and Rewrite

Use `sg` for code patterns — when you know the shape of code, not just a string.

## When to use what

| Task | Tool | Example |
|------|------|---------|
| Text find-replace across files | `sd` | `sd 'old' 'new' file1 file2` |
| Structural code search | `sg -p` | `sg -p 'console.log($$$A)' -l ts` |
| Structural code replacement | `sg -r -U` | `sg -p 'console.log($$$A)' -r 'logger.log($$$A)' -l ts -U` |
| Search before rewriting (dry run) | `sg -p` | `sg -p 'PATTERN' -l lang` then add `-r 'REPL' -U` |
| Structured output for piping | `sg --json` | `sg -p 'PATTERN' -l ts --json=stream \| jq '.[].text'` |
| Debug a non-matching pattern | `sg --debug-query` | `sg -p 'PATTERN' --debug-query ast -l ts` |

**Workflow**: `sg -p 'PATTERN' -l lang` to search → verify matches → `sg -p 'PATTERN' -r 'REPLACEMENT' -l lang -U` to apply. Always search before rewriting.

## Metavar syntax

| Syntax | Matches | Example |
|--------|---------|---------|
| `$NAME` | Exactly one named AST node | `$FN($$$ARGS)` — any function call |
| `$$$ARGS` | Zero or more nodes (variadic) | `console.log($$$)` — any arity |
| `$$OP` | One node including unnamed (operators, punctuation) | `$A $$OP $B` — any binary expression |
| `$_` | One node, non-capturing (wildcard) | Discard binding |

Same metavar name used twice enforces equality: `$A == $A` matches `x == x` but not `x == y`.

## Common patterns

```bash
# Find all calls to a function
sg -p 'fetchData($$$)' -l ts

# Replace console.log with logger
sg -p 'console.log($$$A)' -r 'logger.log($$$A)' -l ts -U

# Optional chaining refactor
sg -p '$A && $A()' -r '$A?.()' -l ts -U

# Remove all console.log calls
sg -p 'console.log($$$)' -r '' -l ts -U

# Find default imports
sg -p 'import $NAME from "$SRC"' -l ts

# Find named imports
sg -p 'import { $$$NAMES } from "$SRC"' -l ts

```

## Key flags

| Flag | Purpose |
|------|---------|
| `-p 'PATTERN'` | AST pattern to match |
| `-r 'REPLACEMENT'` | Rewrite template (metavars substituted) |
| `-l LANG` | Language — always pass; TS ≠ TSX |
| `-U` | Apply all rewrites (without this, `-r` only prints diff) |
| `--json=stream` | Structured output for piping to `jq` |
| `--debug-query ast` | Dump parsed AST to verify pattern |
| `--stdin` | Read code from stdin (requires `-l`) |

Plain output for human review; add `--json` when output feeds another step.

## Gotchas

- TS and TSX are distinct languages — `-l ts` won't match `.tsx` files. Omit `-l` to infer from extension.
- Patterns must be valid parseable code — metavars are identifiers, can't replace operators/keywords. Use `$$OP` for operators.
- Always single-quote patterns: `sg -p '$EXPR'`, not `sg -p "$EXPR"` (shell expands `$`)
- `-r` without `-U` only prints diff — does NOT modify files
- For non-trivial patterns, use `--debug-query ast` to verify what the pattern actually matches
- For deep reference: `https://ast-grep.github.io/llms-full.txt` (~30k tokens, Context7-indexed)
