---
updated: 2026-04-01
---

# Code Intelligence Stack

Tool composition for AI agent code queries. Each tool owns a capability layer — no overlap by design.

## Stack

| Tool | Layer | What it does | Key trait |
|------|-------|-------------|-----------|
| **ripgrep (rg)** | Text search | Exact text/regex, PCRE2, multiline, .gitignore-aware | Stateless, SIMD-optimized, universal file-type support |
| **ast-grep (sg)** | Structural search + rewrite | Tree-sitter AST pattern matching, codemod, YAML lint rules | 25+ languages, rewrite engine — only tool that transforms code |
| **fd** | File discovery | Name/pattern/type filtering, parallel exec, depth control | Unix-composable (`fd -e ts \| xargs rg`) |
| **probe** | Ranked code extraction | BM25/TF-IDF ranked complete function bodies, `--max-tokens` budget | Purpose-built for LLM context windows; optional BERT reranking |
| **LSP servers** | Type intelligence | Diagnostics, go-to-definition, rename, call hierarchy | Embeds actual compiler frontends (tsserver, pyright, rust-analyzer) |
| **inject-types hook** | Auto symbol context | PostToolUse on JS/TS/Svelte, Python, and Java reads — tiered symbols, 1-hop import resolution | Stateless tree-sitter extraction, 1500-token budget, Svelte `<script>` support |

## Design Rationale

**Stateless over indexed.** The hook and probe re-extract on every invocation. Zero stale-state risk — critical during rapid agent edit-read cycles. Index-based tools (like CodeDB) introduce 2-second polling staleness and memory overhead that don't justify the sub-millisecond latency gains for typical agent workloads.

**Budget-capped structured output.** The hook (1500-token XML) and probe (`--max-tokens`) solve the token-efficiency problem at the tool boundary. Raw search output (rg full-line matches) is only used for targeted queries, not bulk context. This eliminates the "32K tokens from grep" failure mode without requiring a persistent index.

**Composition > monolith.** Each tool is best-in-class for its layer. No single tool covers AST rewrite (sg) + semantic ranking (probe) + type inference (LSP) + auto context enrichment (hook). Attempts to consolidate into one tool (evaluated: CodeDB, April 2026) sacrifice depth for breadth.

## Routing (see SPINE.md for canonical table)

- Identifier location → `rg -w` (or probe for ranked results)
- Structural pattern / codemod → `sg`
- File discovery → `fd`
- "Best code blocks for this query" → `probe` with token budget
- Type-aware navigation → LSP
- File reads auto-enriched → hook (no explicit invocation needed)

## Probe Clarification

probe (probelabs/probe) uses **BM25/TF-IDF ranking** with AST-aware complete-function extraction — not embedding/vector search. Optional BERT reranking available but not the default. Boolean query syntax: `+required -excluded "exact phrase" ext:rs`.
