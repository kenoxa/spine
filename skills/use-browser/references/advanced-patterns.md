# Advanced Patterns

## Browser Console Capture

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

## Auth State

```javascript
const state = await page.context().storageState();
console.log(JSON.stringify(state));
// { cookies: [...], origins: [{ origin, localStorage: [...] }] }
```

## Network Interception

Use specific URL patterns only:

```javascript
await page.route("**/api/data", async (route) => {
  const response = await route.fetch();
  const body = await response.json();
  body.injected = true;
  await route.fulfill({ json: body });
});
```
