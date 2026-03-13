# TODO

- compacting instructions adjusted for what we need to capture
	```
	When compacting, always preserve:
	
	- Current file paths being edited
	- Test failure messages
	- Architecture decisions made this session
	```
- run insights on planning sessions: goal reduce planning time while preserving quality
	- how often did planner complement each other or found real different stratgeties/tactics/solutions
	- same for other planning phases
- run insights on execution sessions:
	- inspector
- additional core tools:
	- agent-browser: https://github.com/vercel-labs/agent-browser
		- `/plugin marketplace add vercel-labs/agent-browser`
		- `/plugin install agent-browser@agent-browser`
- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description?
- https://github.com/SocketDev/sfw-free
- merge/resolve merge conflict
- https://github.com/cocoindex-io/cocoindex-code

## Second Opinion for reviewing code

```text
You are acting as a reviewer for a proposed code change made by another engineer.
Focus on issues that impact correctness, performance, security, maintainability, or developer experience.
Flag only actionable issues introduced by the pull request.
When you flag an issue, provide a short, direct explanation and cite the affected file and line range.
Prioritize severe issues and avoid nit-level comments unless they block understanding of the diff.
After listing findings, produce an overall correctness verdict ("patch is correct" or "patch is incorrect") with a concise justification and a confidence score between 0 and 1.
Ensure that file citations and line numbers are exactly correct using the tools available; if they are incorrect your comments will be rejected.
```

## Provide Shared System Setup for MacOS dotfiles

- zsh setup
- recommended cli: jq, fd, rg, sd, ni, mole, bun, topgrade, pbcopy, nvm, ....
- auto-cleanup: https://github.com/tw93/Mole
	- scripts and launcher/cron
- auto-upgrade using topgrade: https://github.com/topgrade-rs/topgrade
	- scripts and launcher/cron
- nvm default-packages
- ni: https://github.com/antfu-collective/ni
- taze: https://github.com/antfu-collective/taze
- Portless: https://github.com/vercel-labs/portless
- zed editor settings
- claude code, codex, cursor settings
- brew install --cask steipete/tap/codexbar
