---
updated: 2026-04-02
---

# Browser Automation Tool Selection

dev-browser (SawyerHood/dev-browser) chosen as Spine's browser automation tool, replacing agent-browser (vercel-labs).

## Why dev-browser

- **Script-first model**: Playwright JS via stdin heredoc — one invocation per multi-step workflow, not command-per-action
- **WASM sandbox**: QuickJS sandbox isolates scripts from host (no fs/network/process access)
- **749-token skill** vs agent-browser's 29KB SKILL.md + 7 reference files — ~97% context reduction
- **Standalone binary**: no npm/bun runtime needed at invocation time
- **E3-verified** on macOS ARM64: navigation, snapshotForAI, console capture, network observation, cookies CRUD, storageState, named page persistence, screenshots

## Benchmarks (vendor-reported, E1)

Source: SawyerHood/dev-browser-eval (Do Browser / dobrowser.io). Not independently verified.

| Method | Time | Cost | Turns | Success |
|---|---|---|---|---|
| Dev Browser | 3m 53s | $0.88 | 29 | 100% |
| Playwright MCP | 4m 31s | $1.45 | 51 | 100% |
| Playwright Skill | 8m 07s | $1.45 | 38 | 67% |
| Chrome Extension | 12m 54s | $2.81 | 80 | 100% |

## Rejected Alternatives

| Tool | Rejection reason |
|---|---|
| agent-browser (vercel-labs) | Daemon reliability failures on macOS ARM64, 29KB skill bloat, open bugs #297/#677/#721 |
| playwright-cli (@playwright/cli) | Same client-daemon architecture as agent-browser; v0.1.1 maturity risk |
| Playwright MCP | Ephemeral sessions hurt stateful workflows; MCP config not a skill |
| browser-use | Python-only, 869MB memory |
| stagehand | Cloud-coupled to Browserbase |

## Installation

Binary from GitHub releases → `~/.local/bin/dev-browser`. Version in `~/.config/spine/tool-versions`. Same pattern as probe CLI. npm/bun global install broken (bun skips postinstall, npm is nvm-dependent).

## Known Limitations

- `page.route("**/*")` catch-all causes 30s timeout (blocks Playwright internals)
- Pre-1.0 (v0.2.6 as of selection) — API may change
- `storageState({ path })` throws in sandbox — capture return value instead
- HAR recording and tracing are stubbed in the Playwright fork
