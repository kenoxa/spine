---
name: use-browser
description: >
  Browser automation for testing, verifying, and interacting with web applications.
  Use when you need to test a site, verify a deployment, check UI behavior, fill and
  submit forms, click elements, capture screenshots, log into a site, scrape page
  content, or debug browser-side issues.
  Triggers: "test this page", "check the site", "verify the deploy", "go to [url]",
  "fill the form", "click on", "take a screenshot", "log into", "scrape", "debug the UI",
  "automate the browser", "login flow", "check this URL".
  Do NOT use as a replacement for WebFetch or web search.
argument-hint: "[URL or browser task description]"
---

Run Playwright JavaScript via dev-browser stdin heredoc. QuickJS WASM sandbox — no Node.js APIs (`require()`, `import()`, `process`, `fs`, `fetch` unavailable). API reference and error recovery in [references/api-and-patterns.md](references/api-and-patterns.md). Advanced patterns (console capture, network interception, cookies, auth state): [references/advanced-patterns.md](references/advanced-patterns.md). Run `dev-browser --help` when refs don't cover your case.

## Core Directives

**Invocation** — one script per call, pipe via stdin heredoc:

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
- Keep page names stable across scripts for failure recovery
- Use `page.snapshotForAI()` for AI-optimized accessibility tree before interacting with unknown pages
- End every script with `console.log(JSON.stringify(...))`
- On failure: reconnect via `browser.getPage(name)`, `saveScreenshot()` to capture state

## Anti-Patterns

- Never use catch-all `page.route("**/*")` — blocks Playwright internals; use specific URL patterns.
- Never use `require()` or `import()` — not available in the sandbox.
- Never pass `{ path }` to `page.screenshot()` or `storageState()` — use `saveScreenshot(buf, name)` / capture return value.
- Never run multiple `dev-browser` calls when a single multi-step script suffices.
- Never use `<FILE>` argument for scripts — always pipe via stdin heredoc.
