# TODO

- install/setup zed agent
- run-skill-eval on use-browser
- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description?
- https://github.com/SocketDev/sfw-free
- merge/resolve merge conflict
- RTK Codex hooks: switch from instruction-only (`RTK.md`) to PreToolUse hook rewriting once Codex supports `updatedInput` + `permissionDecision:allow` — both are parsed but explicitly rejected as "unsupported" in `codex-rs/hooks/src/engine/output_parser.rs` (verified 2026-04-07). Blocked on Codex, not RTK. ([rtk#921](https://github.com/rtk-ai/rtk/issues/921), [codex#14754](https://github.com/openai/codex/issues/14754))
- Codex hooks: enable `inject-types-on-read` and `check-on-edit` once Codex PostToolUse supports non-Bash tools (Read, Edit/Write); currently Bash-only ([codex#14754](https://github.com/openai/codex/issues/14754)); hooks are ready — just expand capability matrix in install.sh
- doc co-evolution Phase 2: if lightweight guardrails (SPINE.md norm + Scope heuristic + finalize learnings) prove insufficient, add `docs_impact` to frame_artifact and `docs_plan` to design_artifact schema fields

## Provide Shared System Setup for MacOS dotfiles

- zsh setup
- recommended cli: jq, fd, rg, sd, ni, mole, bun, topgrade, pbcopy, nvm, ....
- auto-cleanup: https://github.com/tw93/Mole
	- scripts and launcher/cron
- auto-upgrade using topgrade: https://github.com/topgrade-rs/topgrade
	- scripts and launcher/cron
- nvm default-packages
- lsp server: typescript-language-server (.nvm/default-packages), jdtls (brew and ~/.zshenv)
- ni: https://github.com/antfu-collective/ni
- taze: https://github.com/antfu-collective/taze
- Portless: https://github.com/vercel-labs/portless
- zed editor settings
- claude code, codex, cursor settings
- brew install --cask steipete/tap/codexbar
- Time Machine exclusions for dev directories
	- `chpwd` hook in `.zshrc`: reads `.gitignore`, excludes matching directories (skips secrets/IDE config via safelist)
	- fixed-path exclusions for stable caches: Gradle, npm, pnpm store, Xcode DerivedData, JetBrains caches
	- sticky exclusions for IDE app caches: VS Code, Cursor, Claude Desktop, Zed (regenerable bundles/indexes)
	- OrbStack/Docker disk images (when disposable)
	- Postgres data dirs only when DB state is fully seedable
	- leave backed up: Homebrew Cellar, VS Code/Cursor `Backups/` + `User/`, `.env*`, IDE settings
	- consider: Cursor `state.vscdb` can bloat to 40+ GB — periodic `sqlite3 VACUUM` helps
