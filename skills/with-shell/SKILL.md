---
name: with-shell
description: >
  Shell and CLI conventions for safe, consistent terminal usage.
  Use when writing shell scripts, running terminal commands, using bash/zsh,
  CLI tools, or any task involving shell execution.
  Do NOT use for JavaScript/TypeScript package management — see with-js.
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
| regex for code | `ast-grep` | structural patterns, not string matching |

## Quoting

Always quote glob and regex arguments to prevent shell expansion:
- `rg 'pattern'`, not `rg pattern`
- `fd '*.ts'`, not `fd *.ts`

## Quality

- Lint shell scripts with `shellcheck`; format with `shfmt`.
- Include a short description (4–7 words) on every shell command.

## JS/Node Crossover

Use `ni` for JS/Node package management — never detect or hardcode package manager. See `with-js` skill for command reference.

## Anti-Patterns

- Using `rm` or `rm -rf` instead of `trash`
- Unquoted globs or regex in shell commands
- Skipping `shellcheck` on committed shell scripts
- Hardcoding `npm`/`pnpm`/`yarn`/`bun` — use `ni`
