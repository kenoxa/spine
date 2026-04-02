# Spine — Claude Code Plugin

Claude Code-specific extensions delivered via the plugin marketplace. Hooks are shared with other providers (see the [main README](../README.md#hooks-installed) for the full compatibility matrix).

## Install

```sh
claude plugin marketplace add kenoxa/spine
claude plugin install spine@kenoxa
```

The [`install.sh`](../install.sh) script attempts this automatically. If plugin installation fails, it falls back to generating hooks in `~/.claude/settings.json`.

> **Note:** The plugin's hooks depend on shared hook scripts installed to `~/.config/spine/hooks/` by `install.sh`. Running `claude plugin marketplace add` alone registers the hooks, but they will fail open until `install.sh` copies the hook scripts.

## Contents

### Hooks

The plugin registers hooks via [`hooks/hooks.json`](hooks/hooks.json). All hook scripts live in the shared [`hooks/`](../hooks/) directory and are installed to `~/.config/spine/hooks/` with shebang rewriting.

| Hook | Event | Script | Detail |
|------|-------|--------|--------|
| `inject-agents-md` | SessionStart | [`inject-agents-md.sh`](../hooks/inject-agents-md.sh) | Injects project `AGENTS.md` — Claude Code loads `CLAUDE.md` natively but not `AGENTS.md`. |
| `inject-compact-essentials` | SessionStart (compact) | [`inject-compact-essentials.sh`](../hooks/inject-compact-essentials.sh) | Reinjects essential context on compaction events. |
| `guard-shell` | PreToolUse (Bash) | [`guard-shell.sh`](../hooks/guard-shell.sh) | Security deny-list: recursive rm, docker container escapes (run + exec), file uploads. RTK-rewrite agnostic. |
| `guard-read-large` | PreToolUse (Read) | [`guard-read-large.sh`](../hooks/guard-read-large.sh) | Warns on files >2000 lines without `limit` parameter. |
| `inject-types-on-read` | PostToolUse (Read) | [`inject-types-on-read.ts`](../hooks/inject-types-on-read.ts) | Injects JS/TS/Svelte, Python, and Java symbol signatures via `probe symbols` (tree-sitter, ~40ms). Runtime-agnostic: Bun, Node.js, or Deno. |
| `check-on-edit` | PostToolUse (Edit/Write/MultiEdit) | [`check-on-edit.sh`](../hooks/check-on-edit.sh) | Runs `tsc`, `svelte-check`, `biome` after edits. Registry-based. |
| `pre-compact` | PreCompact | [`pre-compact.prompt`](../hooks/pre-compact.prompt) | Prompts handoff artifact before context compaction. |

Claude Code gets all 7 hooks. See the [main README](../README.md#hooks-installed) for per-provider differences.

#### inject-types-on-read detail

| Behavior | Detail |
|----------|--------|
| Priority | 5-tier: exported functions → types in signatures → transitive deps → other exports → non-exported |
| Token budget | ~1500 tokens, per-symbol accounting, never cuts mid-symbol |
| Import resolution | 1-hop relative imports, capped at 10 files / 200ms |
| Full-file reads | Injects imported types only (local signatures already visible) |
| Partial reads | Injects both local (outside visible range) and imported types |
| Svelte | Extracts every `<script>` block, infers JS vs TS temp probing, uses project's `svelte/compiler` when available with regex fallback |
| Scope | Project-root-gated; skips plugin directory and non-project files |

#### check-on-edit checkers

| Checker | Detects via | Runs |
|---------|------------|------|
| TypeScript | `tsconfig.json` + `.ts/.tsx/.mts/.cts` file | `tsc --noEmit` |
| Svelte | `svelte.config.*` + `.svelte/.ts/.js` file | `svelte-check` |
| Biome | `biome.json` or `biome.jsonc` | `biome check <file>` |

To add a checker, define `detect_<name>` and `run_<name>` functions in `check-on-edit.sh`.

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
│   └── hooks.json                Hook definitions (plugin paths → shared hooks/)
└── skills/
    └── run-skill-eval/
        └── SKILL.md              Skill optimization + evaluation loop

hooks/                            Shared hooks (all providers)
├── _env.sh                       POSIX env bootstrap (PATH fix, shebang wrapper)
├── _ts.sh                        TS runtime resolver (sources _env.sh, resolves bun)
├── _nlx.sh                       Package exec resolver (nlx/bunx/npx fallback)
├── _project.sh                   Project root resolver
├── guard-shell.sh                PreToolUse Bash — security deny-list
├── guard-read-large.sh           PreToolUse Read — large file warning
├── inject-agents-md.sh           SessionStart — inject AGENTS.md
├── inject-compact-essentials.sh  SessionStart — reinject on compaction
├── inject-types-on-read.ts       PostToolUse Read — symbol/signature injection (runtime-agnostic)
├── inject-types/                 TS modules imported by inject-types-on-read (copied by install.sh)
├── check-on-edit.sh              PostToolUse Edit/Write/MultiEdit — project checkers
├── pre-compact.prompt            PreCompact — handoff prompt text
└── tests/
    ├── test.sh                   Unified test runner (BATS + Bun)
    ├── *.bats                    Shell hook tests (guard-shell, env, ts, inject-agents-md, check-on-edit)
    ├── *.test.ts                 TypeScript hook tests (inject-types-on-read)
    └── test_helper.bash          Shared BATS helpers
```
