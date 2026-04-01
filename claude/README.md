# Spine — Claude Code Plugin

Claude Code-specific extensions that don't apply to Cursor or Codex.

## Install

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

The [`install.sh`](../install.sh) script attempts this automatically for Claude Code users.

## Contents

### SessionStart hook

Injects project-level `AGENTS.md` files into Claude Code context. Claude Code natively loads `CLAUDE.md` but not `AGENTS.md` — this hook bridges the gap so projects using `AGENTS.md` (shared with Cursor and Codex) are visible in Claude Code sessions.

Configured in [`hooks/hooks.json`](hooks/hooks.json). Script: [`hooks/inject-agents-md.sh`](hooks/inject-agents-md.sh).

### PostToolUse hook (inject-types-on-read)

Injects TypeScript type signatures into Claude's conversation context when reading `.ts`, `.tsx`, `.mts`, `.cts`, or `.svelte` files. The AI sees plain text on file reads — this hook adds the type graph so it understands function signatures, interfaces, and type relationships without chasing imports manually.

Uses `probe symbols` (tree-sitter) for extraction — fast (~40ms), no LSP daemon, no `node_modules` dependencies. Inspired by [type-inject](https://github.com/nick-vi/type-inject).

**Key behaviors:**

| Behavior | Detail |
|----------|--------|
| Priority | 5-tier: exported functions → types in signatures → transitive deps → other exports → non-exported |
| Token budget | ~1500 tokens, per-symbol accounting, never cuts mid-symbol |
| Import resolution | 1-hop relative imports, capped at 10 files / 200ms |
| Full-file reads | Injects imported types only (local signatures already visible) |
| Partial reads | Injects both local (outside visible range) and imported types |
| Svelte | Uses project's `svelte/compiler` when available, regex fallback otherwise |
| Scope | Project-root-gated; skips plugin directory and non-project files |

Always exits 0 — type context is best-effort, never blocks the workflow.

Configured in [`hooks/hooks.json`](hooks/hooks.json) (30s timeout). Script: [`hooks/inject-types-on-read.ts`](hooks/inject-types-on-read.ts) (runs via Bun).

### PostToolUse hook (check-on-edit)

Runs project-appropriate checkers after file edits (Edit, Write, MultiEdit). Uses a registry-based pattern with `detect_*/run_*` function pairs for easy extensibility.

**Supported checkers:**

| Checker | Detects via | Runs |
|---------|------------|------|
| TypeScript | `tsconfig.json` + `.ts/.tsx/.mts/.cts` file | `tsc --noEmit` |
| Svelte | `svelte.config.*` + `.svelte/.ts/.js` file | `svelte-check` |
| Biome | `biome.json` or `biome.jsonc` | `biome check <file>` |

Uses `nlx` (from ni) to execute project checkers — no lockfile detection needed. Always exits 0 — errors and missing-tooling notices are reported via `systemMessage`, never by exit code. Output is truncated to 20 lines per checker.

To add a new checker, define `detect_<name>` and `run_<name>` functions and append to the `CHECKERS` array.

Configured in [`hooks/hooks.json`](hooks/hooks.json) (30s timeout). Script: [`hooks/check-on-edit.sh`](hooks/check-on-edit.sh).

### `run-skill-eval` skill

Optimizes and evaluates changed skill/agent/instruction files in any repo:

| Phase | What happens |
|-------|-------------|
| Detect | Auto-discover changed evaluatable files via `git diff` + `git status` |
| Optimize | Generate 1-3 improved variations per file using use-skill-craft criteria + model intelligence |
| Evaluate | Run all variants (HEAD baseline, working copy, optimizations) through `claude -p` CLI |
| Report | Present comparison via `@visualizer` as interactive HTML |
| Iterate | Refine variations based on user feedback until optimal |

Works in any repo, not spine-specific. Requires the `skill-creator` plugin for grading and benchmarking.

## Structure

```
claude/
├── .claude-plugin/
│   └── plugin.json               Plugin metadata
├── hooks/
│   ├── hooks.json                Hook definitions (SessionStart, PreToolUse, PostToolUse)
│   ├── inject-types-on-read.ts   PostToolUse Read — type context injection (Bun)
│   ├── check-on-edit.sh          PostToolUse Edit/Write — project checkers
│   ├── guard-rm.sh               PreToolUse Bash — block recursive rm
│   ├── inject-agents-md.sh       SessionStart — inject AGENTS.md
│   └── tests/                    Hook test suite (BATS + Bun)
│       └── test.sh               Unified test runner
└── skills/
    └── run-skill-eval/
        └── SKILL.md              Skill optimization + evaluation loop
```
