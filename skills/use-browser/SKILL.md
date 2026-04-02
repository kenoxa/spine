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
  Do NOT use as a replacement for WebFetch or web search — this is for interactive
  browser automation, not data retrieval.
argument-hint: "[URL or browser task description]"
---

Powered by dev-browser — Playwright scripts in a QuickJS WASM sandbox. API methods, error recovery, and operational patterns in [references/api-and-patterns.md](references/api-and-patterns.md). Run `dev-browser --help` for the full LLM usage guide when references don't cover your case.

## Invocation

Pass Playwright JavaScript via stdin heredoc. One script per invocation. Top-level `await` is available.

```sh
dev-browser --headless <<'EOF'
const page = await browser.getPage("main");
await page.goto("https://example.com");
console.log(await page.title());
EOF
```

Key flags:
- `--headless` — no visible window (default for automation)
- `--browser <NAME>` — named browser instance; state persists across invocations
- `--connect [URL]` — attach to running Chrome via CDP (auto-discovers if no URL)
- `--timeout <SECONDS>` — script timeout (default 30; use `--timeout 10` for fast-fail)

## Script Model

Scripts run in a **QuickJS WASM sandbox** (not Node.js). No `require()`, `import()`, `process`, `fs`, `fetch`.

Available globals:
- `browser` — pre-connected handle: `getPage(name)`, `newPage()`, `listPages()`, `closePage(name)`
- `console.log/warn/error/info` — routed to CLI stdout/stderr
- `saveScreenshot(buf, name)`, `writeFile(name, data)`, `readFile(name)` — sandboxed I/O to `~/.dev-browser/tmp/`

Pages from `browser.getPage(name)` are full Playwright Page objects. Named pages persist across script runs.

## Workflow

1. **Discover** — use `page.snapshotForAI()` for an AI-optimized accessibility tree
2. **Interact** — use Playwright locators: `page.getByRole()`, `page.click()`, `page.fill()`
3. **Verify** — re-snapshot or screenshot after actions

For known pages/selectors, skip the snapshot and use direct Playwright selectors.

End every script with `console.log(JSON.stringify(...))` for structured output.

## Anti-Patterns

- **Never use `page.route("**/*")`** — catch-all patterns block Playwright internals and cause timeouts. Use specific URL patterns: `page.route("**/api/**", handler)`.
- Never use `require()` or `import()` — not available in the sandbox.
- Never pass `{ path }` to `page.screenshot()` — use `saveScreenshot(buf, name)` instead.
- Never run multiple `dev-browser` calls when a single multi-step script suffices.
- Never use `<FILE>` argument for scripts — always pipe via stdin heredoc.

## Advanced Capabilities

Console capture, network observation, cookies, and auth state management are supported but not in the standard API reference. See [references/advanced-patterns.md](references/advanced-patterns.md).
