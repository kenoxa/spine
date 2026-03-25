# probe CLI — Semantic Code Search

Ranked search and AST extraction — when relevance ranking or complete function bodies needed.

## When to use what

| Task | Tool |
|------|------|
| Exact regex | `rg` |
| Ranked/concept search | `probe search` |
| Structural pattern (read-only) | `probe query` |
| Structural rewrite | `sg -r` |
| Full function by symbol | `probe extract` |

## Commands

```bash
probe search 'query' ./path --max-tokens N --format json
probe query 'pattern' ./path --language L
probe extract file.ts#symbolName --format json
probe symbols file.ts --format json
```

## JSON Parsing

`probe search` contaminates stdout with preamble lines before JSON object. Workaround:

```bash
probe search ... --format json 2>/dev/null | sed -n '/^{/,$p' | jq
```

`extract`/`query`/`symbols` emit clean JSON. Results at `.results[0].file`. **Expiry**: if `head -1` starts with `{`, drop sed.

Exit always 0 — check results array length, not exit code.

Pre-1.0 (v0.6.0-rc) — stable fields: `file`, `code`, `lines`, `node_type`. Ranking scores may change.
