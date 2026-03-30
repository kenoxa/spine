# TODO

- gemini envoy:
	- `brew install gemini-cli`
	- `gemini -p "Explain the architecture of this codebase"`
- verify cross-skill references work, or move to ~/.agents/skills/run-explore/references/explore-scout.md
- run-skill-eval: on rewritten skills, reference files, and agents
	- run-insight is suspicous
- document handoff/clear/catchup after planning
- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description?
- https://github.com/SocketDev/sfw-free
- merge/resolve merge conflict
- RTK Copilot: add global hook support once Copilot CLI supports `~/.copilot/hooks` ([copilot-cli#1157](https://github.com/github/copilot-cli/issues/1157), [copilot-cli#2013](https://github.com/github/copilot-cli/issues/2013)); VS Code already supports it since v1.112.0 — RTK needs to automate install to `~/.copilot/hooks/` ([rtk#728](https://github.com/rtk-ai/rtk/pull/728))
- RTK Codex hooks: switch from instruction-only to PreToolUse hook once RTK adds native support ([rtk#921](https://github.com/rtk-ai/rtk/issues/921)); Codex hooks shipped in v0.117.0 but require `codex_hooks = true` feature flag

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
