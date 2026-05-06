---
name: use-shell
description: >-
  Shell and CLI conventions. Use when: 'writing scripts', 'structural search', 'semantic search'.
argument-hint: "[shell task or command]"
---

Prefer native tools (Grep, Glob, Read, Edit/StrReplace) over shell equivalents. Shell is the fallback. Use `trash`, never `rm`.

## Tool Preferences

| Instead of | Use |
|------------|-----|
| `grep` | `rg` |
| `find` | `fd` |
| grepping JSON | `jq` |
| grepping YAML | `yq` |
| `perl`/`sed` | `sd` |
| regex for code | `ast-grep` (`sg`) |
| `rg` for concept/ranked search | `probe` (`probe search`, `probe extract`) |

Lint shell scripts with `shellcheck`; format with `shfmt`. Include a short description (4–7 words) on every shell command.

## ast-grep (sg)

`sg -r` supersedes `rg + sd` for structural code replacements; `sd` stays for text/config. Use `--debug-query ast` when patterns don't match as expected. For pattern syntax, flags, and examples → `references/ast-grep.md`.

## probe CLI

Semantic code search with BM25 ranking and tree-sitter AST extraction. `probe search` for ranked results; `probe extract file#symbol` for complete function bodies; `probe query` for structural patterns (read-only complement to `sg`). For flags, JSON parsing, and gotchas → `references/probe.md`.

## Quoting

Always quote glob and regex arguments to prevent shell expansion:
- `rg 'pattern'`, not `rg pattern`
- `fd '*.ts'`, not `fd *.ts`
- `sg -p '$EXPR'`, not `sg -p "$EXPR"` (metavar `$` expansion)

## Output Persistence

When running expensive commands (test suites, benchmarks, coverage, builds, lints, migrations) whose output is piped through a display filter (head, tail, grep, rg, etc.), save full output before filtering:

```bash
set -o pipefail
cmd 2>&1 | tee .scratch/<session>/<slug>.log | <filter>
```

- `set -o pipefail` prevents exit-code masking — tee returns 0 even when the command fails (E3)
- Capture stderr with `2>&1` — diagnostics and failures live on stderr
- Use a descriptive filename slug (e.g., `bench-auth.log`, `test-unit.log`)
- Place in `.scratch/<session>/` for session-scoped lifecycle (SPINE.md §Sessions)

When filtered or truncated display lacks needed context, Read the saved file — do not re-run the command.

## Anti-Patterns

- Using `rm` or `rm -rf` instead of `trash`
- Unquoted globs or regex in shell commands
- Skipping `shellcheck` on committed shell scripts
- Hardcoding `npm`/`pnpm`/`yarn`/`bun` — use `ni`
- Using `sd` for structural code changes when `sg -r` handles the pattern
- Using `sg` for text/config files — `sd` is simpler and correct
- Double-quoting `sg` patterns containing `$` metavars
- Running `sg -r ... -U` without a search-only dry run first
- Piping expensive command output through filters (head/grep/tail) without saving to a file (re-run waste)
