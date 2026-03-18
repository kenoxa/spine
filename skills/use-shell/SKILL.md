---
name: use-shell
description: >
  Shell and CLI conventions for safe, consistent terminal usage.
  Use when writing shell scripts, running terminal commands, using bash/zsh,
  CLI tools, code pattern matching, renaming symbols across files,
  replacing function calls with ast-grep/sg, structural code search,
  or any task involving shell execution.
  Do NOT use for JavaScript/TypeScript package management — see use-js.
argument-hint: "[shell task or command]"
---

Prefer native tools (Grep, Glob, Read, Edit) over shell equivalents. Shell is the fallback.

## Safe Deletion

Use `trash`, never `rm`, for file deletion.

## Tool Preferences

| Instead of | Use | Why |
|------------|-----|-----|
| `grep` | `rg` | faster, respects .gitignore |
| `find` | `fd` | simpler syntax, respects .gitignore |
| grepping JSON | `jq` | structured parsing |
| `perl`/`sed` | `sd` | simpler in-place replacement |
| regex for code | `ast-grep` (`sg`) | AST-aware search and rewrite |

## ast-grep (sg)

`sg -r` supersedes `rg + sd` for structural code replacements; `sd` stays for text/config. For pattern syntax, flags, and examples → `references/ast-grep.md`.

## Quoting

Always quote glob and regex arguments to prevent shell expansion:
- `rg 'pattern'`, not `rg pattern`
- `fd '*.ts'`, not `fd *.ts`
- `sg -p '$EXPR'`, not `sg -p "$EXPR"` (metavar `$` expansion)

## Quality

- Lint shell scripts with `shellcheck`; format with `shfmt`.
- Include a short description (4–7 words) on every shell command.

## JS/Node Crossover

Use `ni` for JS/Node package management — never detect or hardcode package manager. See `use-js` skill for command reference.

## Anti-Patterns

- Using `rm` or `rm -rf` instead of `trash`
- Unquoted globs or regex in shell commands
- Skipping `shellcheck` on committed shell scripts
- Hardcoding `npm`/`pnpm`/`yarn`/`bun` — use `ni`
- Using `sd` for structural code changes when `sg -r` handles the pattern
- Using `sg` for text/config files — `sd` is simpler and correct
- Double-quoting `sg` patterns containing `$` metavars
- Running `sg -r ... -U` without a search-only dry run first
