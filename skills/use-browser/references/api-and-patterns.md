# API Reference & Patterns

Pages are full Playwright Page objects.

## Playwright Page Methods

```
page.goto(url, { waitUntil: "domcontentloaded" })
                                       Navigate to a URL; prefer domcontentloaded on dev servers
page.title()                           Get the current page title
page.url()                             Get the current URL
page.snapshotForAI(options)            AI-optimized snapshot -> { full, incremental? }
                                       Options: { track?, depth?, timeout? }
page.getByRole(role, { name })         Target elements from snapshot
page.textContent(selector)             Get text content
page.innerHTML(selector)               Get inner HTML
page.fill(selector, value)             Fill an input field
page.click(selector)                   Click an element
page.type(selector, text)              Type character by character
page.press(selector, key)              Press a key (Enter, Tab, etc.)
page.waitForSelector(selector)         Wait for element to appear
page.waitForURL(url)                   Wait for navigation
page.screenshot()                      Capture buffer; save with saveScreenshot()
page.$$eval(selector, fn)              Run fn on all matching elements
page.$eval(selector, fn)               Run fn on first matching element
page.evaluate(fn)                      Run JS in page context (plain JS only)
page.locator(selector)                 Create locator for chained actions
page.context()                         Get BrowserContext (cookies, storage)
```

## Quick Inspection

```sh
dev-browser --connect <<'EOF'
const tabs = await browser.listPages();
console.log(JSON.stringify(tabs, null, 2));
EOF
```

## Tips

- Keep page names stable across scripts for failure recovery
- `--timeout 10` for fast-fail instead of 30s default hang
- For local dev servers (Next.js, Vite, etc.), use `{ waitUntil: "domcontentloaded" }` — the default `"load"` wait can hang on HMR/streaming connections
