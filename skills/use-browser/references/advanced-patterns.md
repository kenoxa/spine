# Advanced Patterns

Capabilities available in dev-browser but not documented in `--help`.

## Browser Console Capture

Capture `console.log()` calls from the web page (distinct from script's own `console.log`):

```javascript
const messages = [];
page.on("console", (msg) => {
  messages.push({ type: msg.type(), text: msg.text() });
});
await page.goto("https://example.com");
await page.waitForTimeout(200);
console.log(JSON.stringify({ consoleMessages: messages }));
```

## Network Observation

Monitor HTTP requests and responses:

```javascript
const requests = [];
page.on("request", (req) => {
  requests.push({ url: req.url(), method: req.method() });
});
page.on("response", (res) => {
  requests.find(r => r.url === res.url()).status = res.status();
});
await page.goto("https://example.com");
await page.waitForTimeout(200);
console.log(JSON.stringify({ network: requests }));
```

## Cookies

Full CRUD via `page.context()`:

```javascript
const ctx = page.context();

// Read
const cookies = await ctx.cookies("https://example.com");

// Add
await ctx.addCookies([{
  name: "session", value: "abc123",
  domain: ".example.com", path: "/"
}]);

// Clear specific
await ctx.clearCookies({ name: "session" });
```

## Auth State (storageState)

Export cookies + localStorage origins as JSON for inspection or logging:

```javascript
const state = await page.context().storageState();
console.log(JSON.stringify(state));
// { cookies: [...], origins: [{ origin, localStorage: [...] }] }
```

Note: `storageState({ path })` throws in the sandbox — capture the return value and log it instead.

## Network Interception

Intercept and modify requests. Use specific URL patterns only:

```javascript
await page.route("**/api/data", async (route) => {
  const response = await route.fetch();
  const body = await response.json();
  body.injected = true;
  await route.fulfill({ json: body });
});
```

**Never use `page.route("**/*")`** — catches Playwright internal traffic and causes timeouts.
