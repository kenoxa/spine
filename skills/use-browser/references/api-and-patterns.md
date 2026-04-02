# API Reference & Patterns

From dev-browser's LLM guide. Pages are full Playwright Page objects.

## Playwright Page Methods

```
page.goto(url)                         Navigate to a URL
page.title()                           Get the current page title
page.url()                             Get the current URL
page.snapshotForAI(options)            AI-optimized snapshot → { full, incremental? }
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

## Error Recovery

If a script fails, the page stays where it stopped. Reconnect and inspect:

```sh
dev-browser --headless <<'EOF'
const page = await browser.getPage("checkout");
const path = await saveScreenshot(await page.screenshot(), "debug.png");
console.log(JSON.stringify({
  screenshot: path,
  url: page.url(),
  title: await page.title(),
}));
EOF
```

## Waiting

```javascript
await page.waitForSelector(".results");
await page.waitForURL("**/success");
await page.waitForTimeout(500); // ms, use sparingly
```

## Tips

- `console.log(JSON.stringify(...))` for structured output
- `snapshotForAI()` for structure; screenshots when visual layout matters
- Keep page names stable across scripts for failure recovery
- `--timeout 10` for fast-fail instead of 30s default hang
- `page.evaluate(fn)` runs in browser context — plain JS only, no TypeScript
