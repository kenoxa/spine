---
name: with-js
description: >
  JavaScript/TypeScript tooling conventions using ni (universal package manager wrapper).
  Use when managing JS/TS dependencies, running scripts, testing with vitest/jest,
  working with package.json, or using npm/pnpm/yarn/bun/Node.js/Deno tooling.
  Do NOT use for non-JavaScript languages.
argument-hint: "[package operation or JS/TS task]"
---

Use `ni` for all package operations — never hardcode npm, pnpm, yarn, or bun commands.

Exception: public `skills` install docs intentionally use `npx skills add/remove ...` to match [`skills.sh`](https://skills.sh/), and Spine's installer bootstrap may fall back to other launchers when invoking the same CLI. This exception is only for `skills` bootstrap/install flows; normal JS/TS project tooling still uses `ni`/`nlx`.

## Package Management (`ni`)

`ni` auto-detects the package manager from lockfile. One command set for all JS projects.

| Task | Command | Example |
|------|---------|---------|
| Install deps | `ni` | `ni` |
| Frozen install (CI) | `ni --frozen` | `ni --frozen` |
| Add dependency | `ni <pkg>` | `ni vite` |
| Add dev dependency | `ni <pkg> -D` | `ni @types/node -D` |
| Clean install | `nci` | `nci` |
| Run script | `nr <script>` | `nr dev --port=3000` |
| Execute binary | `nlx <cmd>` | `nlx vitest` |
| PM passthrough | `na <cmd>` | `na audit` |
| Upgrade deps | `nup` | `nup` |
| Uninstall | `nun <pkg>` | `nun lodash` |

### Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `?` | Print resolved command (debug) | `ni vite ?` |
| `-C <dir>` | Change directory first | `nr -C packages/foo dev` |
| `-D` | Dev dependency | `ni vitest -D` |
| `-g` | Global install | `ni -g @antfu/ni` |
| `--frozen` | Fail if lockfile changes needed | `ni --frozen` |

### Configuration

`ni` auto-detects from lockfile. Override for CI/automation:

- `~/.nirc`: `defaultAgent=npm` (fallback when no lockfile)
- Env: `NI_DEFAULT_AGENT=npm` (higher priority than file)

## Testing

Run tests via `ni` commands — never hardcode the test runner binary.

- Run all tests: `nr test`
- Run vitest directly: `nlx vitest`
- Run vitest with options: `nlx vitest run --reporter=verbose`
- Watch mode: `nr test -- --watch` or `nlx vitest --watch`
- Coverage: `nlx vitest run --coverage`

## Anti-Patterns

- Hardcoding `npm install`, `pnpm add`, `yarn add`, `bun add` — use `ni <pkg>`
- Using `npx` or `bunx` directly for normal JS/TS tooling — use `nlx <cmd>`
- Running `npm audit` or `pnpm audit` — use `na audit`
- Detecting package manager from lockfile in code — `ni` handles it
- Specifying package manager in AGENTS.md — omit it, `ni` is universal
