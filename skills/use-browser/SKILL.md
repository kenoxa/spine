---
name: use-browser
description: >-
  Use when: 'test this page', 'go to URL', 'fill the form', 'screenshot'.
argument-hint: "[URL or browser task description]"
---

Use the `dev-browser` CLI. `dev-browser --help` is the current source of truth and includes the full LLM usage guide. QuickJS WASM sandbox — no Node.js APIs (`require()`, `import()`, `process`, `fs`, `fetch` unavailable). API reference and error recovery in [references/api-and-patterns.md](references/api-and-patterns.md). Advanced patterns (console capture, network interception, cookies, auth state): [references/advanced-patterns.md](references/advanced-patterns.md).

## Core Directives

**Invocation** — pipe scripts via stdin heredoc:

```sh
dev-browser --headless <<'EOF'
const page = await browser.getPage("main");
await page.goto("https://example.com", { waitUntil: "domcontentloaded" });
console.log(await page.title());
EOF
```

Flags: `--headless` (omit for visible browser), `--browser <NAME>` (named persistent instance), `--connect [URL]` (attach to running Chrome/CDP), `--timeout <SEC>` (default 30; use `--timeout 10` for fast-fail).

**Sandbox globals:**
- `browser` — `getPage(name)`, `newPage()`, `listPages()`, `closePage(name)`
- `console.log/warn/error/info` — routed to stdout/stderr
- `saveScreenshot(buf, name)`, `writeFile(name, data)`, `readFile(name)` — sandboxed I/O to `~/.dev-browser/tmp/`

**Key directives:**
- Named pages (`--browser <NAME>`) persist across `dev-browser` calls — reuse for multi-step flows
- Use small, focused scripts while exploring: navigate, inspect, click, fill, or check; consolidate only after a flow is proven
- Keep page names stable across scripts for failure recovery
- Use `page.snapshotForAI()` for AI-optimized accessibility tree before interacting with unknown pages
- End every script with `console.log(JSON.stringify(...))`
- On failure: reconnect via `browser.getPage(name)`, `saveScreenshot()` to capture state

## Anti-Patterns

- Never use catch-all `page.route("**/*")` — blocks Playwright internals; use specific URL patterns.
- Never use `require()` or `import()` — not available in the sandbox.
- Never pass `{ path }` to `page.screenshot()` or `storageState()` — use `saveScreenshot(buf, name)` / capture return value.
- Never write one large speculative script for an unknown page; inspect first, then act from observed state.
- Never use `<FILE>` argument for scripts — always pipe via stdin heredoc.
