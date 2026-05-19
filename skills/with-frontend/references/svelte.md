# Svelte / SvelteKit

Cross-provider wrapper for Svelte work. The upstream `sveltejs/ai-tools` plugin provides the MCP server, native skills, and `svelte-file-editor` subagent on Claude Code, Cursor, and OpenCode. This reference covers the workflow agents must follow regardless of provider, plus team conventions that go beyond upstream.

## Delegation

When the upstream plugin is active (Claude Code, Cursor, OpenCode), route `.svelte`, `.svelte.ts`, and `.svelte.js` file work to the `@svelte-file-editor` subagent — it preloads the MCP tools and is tuned for Svelte 5 idioms.

On Codex, the plugin's subagent is unavailable — edit Svelte files directly and apply the MCP workflow below. Spine's installer registers the Svelte MCP server in `~/.codex/config.toml`, so the four tools are callable.

## MCP Workflow

The Svelte MCP server (`https://mcp.svelte.dev/mcp`) exposes four tools. Use them in order:

1. **`list-sections`** — call first on any Svelte / SvelteKit task. Returns documentation titles, `use_cases`, and paths.
2. **`get-documentation`** — after reading `use_cases` from step 1, fetch *all* sections relevant to the task in a single call (multiple sections accepted).
3. **`svelte-autofixer`** — run on every block of Svelte code before showing it to the user. Loop until no issues or suggestions remain.
4. **`playground-link`** — only after the user asks, and never for code that was already written to project files.

When the MCP server is unavailable, fall back to Context7 (`svelte`, `sveltejs/kit`).

## Team Conventions

**Runes-only.** New code uses Svelte 5 runes: `$state`, `$derived`, `$effect`, `$props`, `$bindable`. No `$:` reactive statements, no `let`-as-reactive, no `writable`/`readable` stores for component-local state. Migrate legacy patterns opportunistically when editing adjacent code.

**Autofixer before commit.** `svelte-autofixer` must return clean for every changed `.svelte` / `.svelte.ts` file. Hard gate, not a suggestion — if the fixer flags issues, address them before the change ships.

**Form actions preferred for mutations.** SvelteKit form actions (`+page.server.ts`) are the default for form submissions and server-side mutations. `+server.ts` API routes are reserved for genuine JSON APIs and cross-origin consumers.

## Anti-Patterns

- Writing Svelte code without running `svelte-autofixer` first
- Mixing runes with legacy `$:` reactivity in the same component
- Reaching for `+server.ts` when a form action covers the mutation
- Skipping `list-sections` and calling `get-documentation` with guessed paths
- Generating playground links for code that was already written to disk
